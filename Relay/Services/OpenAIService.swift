import Foundation

final class OpenAIService: LLMService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let extraHeaders: [String: String]

    init(baseURL: URL, extraHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.extraHeaders = extraHeaders
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
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    for (key, value) in extraHeaders {
                        request.setValue(value, forHTTPHeaderField: key)
                    }

                    let mappedMessages: [[String: Any]] = messages.map { msg in
                        // Assistant message with tool calls
                        if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                            var dict: [String: Any] = ["role": msg.role]
                            if !msg.content.isEmpty {
                                dict["content"] = msg.content
                            } else {
                                dict["content"] = NSNull()
                            }
                            dict["tool_calls"] = toolCalls.map { tc in
                                [
                                    "id": tc.id,
                                    "type": "function",
                                    "function": [
                                        "name": tc.name,
                                        "arguments": tc.arguments
                                    ]
                                ] as [String: Any]
                            }
                            return dict
                        }

                        // Tool result message
                        if let toolCallId = msg.toolCallId {
                            return [
                                "role": "tool",
                                "tool_call_id": toolCallId,
                                "content": msg.content
                            ]
                        }

                        // Image message
                        if let base64 = msg.imageBase64 {
                            let content: [[String: Any]] = [
                                ["type": "text", "text": msg.content],
                                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                            ]
                            return ["role": msg.role, "content": content] as [String: Any]
                        }

                        // Standard text message
                        return ["role": msg.role, "content": msg.content]
                    }

                    var body: [String: Any] = [
                        "model": model,
                        "messages": mappedMessages,
                        "stream": true,
                        "stream_options": ["include_usage": true]
                    ]

                    if !tools.isEmpty {
                        body["tools"] = tools.map { tool in
                            [
                                "type": "function",
                                "function": [
                                    "name": tool.name,
                                    "description": tool.description,
                                    "parameters": tool.parameters
                                ] as [String: Any]
                            ] as [String: Any]
                        }

                        if let forceName = forceToolName {
                            body["tool_choice"] = [
                                "type": "function",
                                "function": ["name": forceName]
                            ]
                        }
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

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" { break }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let firstChoice = choices.first else {
                            continue
                        }

                        let delta = firstChoice["delta"] as? [String: Any]

                        // Parse tool calls from delta
                        if let delta, let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for tc in toolCalls {
                                let index = tc["index"] as? Int ?? 0
                                let id = tc["id"] as? String
                                let fn = tc["function"] as? [String: Any]
                                continuation.yield(.toolCall(
                                    index: index,
                                    id: id,
                                    name: fn?["name"] as? String,
                                    arguments: fn?["arguments"] as? String
                                ))
                            }
                        }

                        if let delta {
                            // Reasoning tokens
                            if let reasoning = delta["reasoning"] as? String ?? delta["reasoning_content"] as? String {
                                continuation.yield(.reasoning(reasoning))
                            }
                            // Content tokens
                            if let content = delta["content"] as? String {
                                continuation.yield(.content(content))
                            }
                        }

                        // Finish reason
                        if let finishReason = firstChoice["finish_reason"] as? String {
                            continuation.yield(.finishReason(finishReason))
                        }

                        // Usage (final chunk with stream_options include_usage)
                        if let usage = json["usage"] as? [String: Any],
                           let prompt = usage["prompt_tokens"] as? Int,
                           let completion = usage["completion_tokens"] as? Int {
                            continuation.yield(.usage(promptTokens: prompt, completionTokens: completion))
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
