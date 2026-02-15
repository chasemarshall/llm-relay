import Foundation

final class AnthropicService: LLMService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        tools: [ToolDefinition] = [],
        forceToolName: String? = nil
    ) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    // Separate system message from conversation messages
                    var systemText: String?
                    var conversationMessages: [[String: Any]] = []

                    for msg in messages {
                        if msg.role == "system" {
                            // Anthropic uses system as a top-level parameter
                            if let existing = systemText {
                                systemText = existing + "\n\n" + msg.content
                            } else {
                                systemText = msg.content
                            }
                        } else {
                            if let base64 = msg.imageBase64 {
                                let content: [[String: Any]] = [
                                    ["type": "text", "text": msg.content],
                                    ["type": "image", "source": [
                                        "type": "base64",
                                        "media_type": "image/jpeg",
                                        "data": base64
                                    ]]
                                ]
                                conversationMessages.append([
                                    "role": msg.role,
                                    "content": content
                                ] as [String: Any])
                            } else {
                                conversationMessages.append([
                                    "role": msg.role,
                                    "content": msg.content
                                ])
                            }
                        }
                    }

                    var body: [String: Any] = [
                        "model": model,
                        "messages": conversationMessages,
                        "max_tokens": 8192,
                        "stream": true
                    ]
                    if let systemText {
                        body["system"] = systemText
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response")
                    }

                    if httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }

                        switch httpResponse.statusCode {
                        case 401: throw LLMError.invalidAPIKey
                        case 429: throw LLMError.rateLimited
                        default:
                            if let data = errorBody.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                throw LLMError.networkError(message)
                            }
                            throw LLMError.networkError("HTTP \(httpResponse.statusCode)")
                        }
                    }

                    var promptTokens = 0

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" { break }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }

                        switch type {
                        case "message_start":
                            if let message = json["message"] as? [String: Any],
                               let usage = message["usage"] as? [String: Any],
                               let inputTokens = usage["input_tokens"] as? Int {
                                promptTokens = inputTokens
                            }
                        case "content_block_delta":
                            guard let delta = json["delta"] as? [String: Any],
                                  let deltaType = delta["type"] as? String else { continue }

                            switch deltaType {
                            case "text_delta":
                                if let text = delta["text"] as? String {
                                    continuation.yield(.content(text))
                                }
                            case "thinking_delta":
                                if let thinking = delta["thinking"] as? String {
                                    continuation.yield(.reasoning(thinking))
                                }
                            default:
                                break
                            }
                        case "message_delta":
                            if let usage = json["usage"] as? [String: Any],
                               let outputTokens = usage["output_tokens"] as? Int {
                                continuation.yield(.usage(
                                    promptTokens: promptTokens,
                                    completionTokens: outputTokens
                                ))
                            }
                        case "message_stop":
                            break
                        case "error":
                            if let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                throw LLMError.networkError(message)
                            }
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
