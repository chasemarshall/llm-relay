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
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
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

                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response")
                    }

                    if httpResponse.statusCode != 200 {
                        // Read the error body for better error messages
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }

                        switch httpResponse.statusCode {
                        case 401: throw LLMError.invalidAPIKey
                        case 429: throw LLMError.rateLimited
                        default:
                            // Try to parse error message from JSON
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
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        continuation.yield(content)
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
