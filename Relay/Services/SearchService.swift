import Foundation

struct SearchResult: Sendable {
    let title: String
    let url: String
    let snippet: String
}

enum SearchService {
    private static let session = URLSession.shared

    static func search(query: String) async throws -> [SearchResult] {
        let provider = SettingsManager.searchProvider
        guard let apiKey = KeychainManager.searchApiKey() else {
            throw SearchError.noApiKey(provider.displayName)
        }
        let resultLimit = max(1, min(SettingsManager.searchResultLimit, 20))
        switch provider {
        case .tavily: return try await tavilySearch(query: query, apiKey: apiKey, limit: resultLimit)
        case .firecrawl: return try await firecrawlSearch(query: query, apiKey: apiKey, limit: resultLimit)
        }
    }

    // MARK: - Tavily

    private static func tavilySearch(query: String, apiKey: String, limit: Int) async throws -> [SearchResult] {
        guard let endpoint = URL(string: "https://api.tavily.com/search") else {
            throw SearchError.networkError("Invalid Tavily endpoint")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "query": query,
            "max_results": limit,
            "include_answer": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SearchError.networkError("Invalid response")
        }
        if http.statusCode == 401 { throw SearchError.invalidApiKey }
        guard http.statusCode == 200 else {
            throw SearchError.networkError("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw SearchError.networkError("Could not parse results")
        }

        return results.compactMap { item in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String,
                  let content = item["content"] as? String else { return nil }
            return SearchResult(title: title, url: url, snippet: content)
        }
    }

    // MARK: - Firecrawl

    private static func firecrawlSearch(query: String, apiKey: String, limit: Int) async throws -> [SearchResult] {
        guard let endpoint = URL(string: "https://api.firecrawl.dev/v1/search") else {
            throw SearchError.networkError("Invalid Firecrawl endpoint")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "query": query,
            "limit": limit
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SearchError.networkError("Invalid response")
        }
        if http.statusCode == 401 { throw SearchError.invalidApiKey }
        guard http.statusCode == 200 else {
            throw SearchError.networkError("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["data"] as? [[String: Any]] else {
            throw SearchError.networkError("Could not parse results")
        }

        return results.compactMap { item in
            let title = item["title"] as? String ?? ""
            let url = item["url"] as? String ?? ""
            let snippet = item["markdown"] as? String ?? item["description"] as? String ?? ""
            guard !url.isEmpty, !snippet.isEmpty else { return nil }
            return SearchResult(title: title, url: url, snippet: String(snippet.prefix(500)))
        }
    }
}

enum SearchError: LocalizedError {
    case noApiKey(String)
    case invalidApiKey
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey(let provider): "No \(provider) API key set. Add one in Settings."
        case .invalidApiKey: "Invalid search API key. Check Settings."
        case .networkError(let msg): "Search failed: \(msg)"
        }
    }
}
