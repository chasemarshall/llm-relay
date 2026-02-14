import Foundation

final class AnthropicService: LLMService, @unchecked Sendable {
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let session = URLSession.shared

    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let systemMessage = messages.first { $0.role == "system" }
                    let chatMessages = messages.filter { $0.role != "system" }

                    var body: [String: Any] = [
                        "model": model,
                        "messages": chatMessages.map { ["role": $0.role, "content": $0.content] },
                        "max_tokens": 4096,
                        "stream": true
                    ]
                    if let system = systemMessage {
                        body["system"] = system.content
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response")
                    }

                    switch httpResponse.statusCode {
                    case 200: break
                    case 401: throw LLMError.invalidAPIKey
                    case 429: throw LLMError.rateLimited
                    default: throw LLMError.networkError("HTTP \(httpResponse.statusCode)")
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }

                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        } else if type == "message_stop" {
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
