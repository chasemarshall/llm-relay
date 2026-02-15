# Search Feature Research

## Overview

This document covers approaches for adding web search to the LLM chat app, based on analysis of the existing codebase and current API offerings.

The app already has a `searchEnabled` toggle in `ChatView.swift` — it just needs to be wired up to actual search functionality.

---

## Approach Options

### Option 1: OpenRouter Native Web Search (Easiest)

OpenRouter offers native web search via appending `:online` to model slugs or passing `web_search_options` in requests. No additional API key needed.

- **Pros**: Minimal code changes, no extra API key
- **Cons**: Depends on OpenRouter's feature availability and pricing

### Option 2: Tavily API (Best Quality)

Purpose-built for LLM integration. Optimizes results for AI/RAG pipelines with automatic summarization.

- **Pros**: Excellent quality, free tier (~100/month), designed for LLMs
- **Cons**: Additional API key, ~$0.005-0.01 per search

### Option 3: Brave Search API (Privacy-Focused)

Independent, privacy-first search results.

- **Pros**: Fast, transparent results, privacy-focused
- **Cons**: Credit-based pricing ($5/month = ~1000 queries)

### Option 4: Perplexity Answer API (All-in-One)

Provides answers with citations, not just search results.

- **Pros**: High quality, pay-per-use
- **Cons**: More expensive, shifts control away from model selection

---

## API Comparison

| API | Free Tier | Cost/Search | Speed | Quality | Best For |
|-----|-----------|-------------|-------|---------|----------|
| OpenRouter Native | Included | Included | Fast | Good | Simplicity |
| Tavily | ~100/month | $0.005-0.01 | Fast | Excellent | Quality + accuracy |
| Brave | $5 credits/mo | $0.003-0.004 | Very fast | Good | Privacy-first |
| Perplexity | Pay-per-use | $0.005 | Medium | Excellent | Complete replacement |
| SerpAPI | 250/month | $0.015-0.03 | Fast | Good | Traditional SERP |

---

## Architecture

### New Files

1. **`SearchService.swift`** — Protocol + result model:
   ```swift
   protocol SearchService: Sendable {
       func search(query: String, apiKey: String) async throws -> [SearchResult]
   }

   struct SearchResult: Codable {
       let title: String
       let url: String
       let snippet: String
   }
   ```

2. **`TavilySearchService.swift`** — Tavily API implementation
3. **`BraveSearchService.swift`** — Brave Search implementation (optional)

### Files to Modify

1. **`ChatViewModel.swift`** — Add search logic before building the prompt in `streamResponse()`:
   ```swift
   if searchEnabled {
       let results = try await searchService.search(query: lastUserMessage, apiKey: apiKey)
       let formatted = results.map { "[\($0.title)](\($0.url)): \($0.snippet)" }.joined(separator: "\n")
       systemParts.append("""
       SEARCH RESULTS (retrieved today):
       \(formatted)

       Incorporate these results and cite sources using markdown links.
       """)
   }
   ```

2. **`ChatView.swift`** — Pass `searchEnabled` state to the view model
3. **`SettingsView.swift`** — Add search API key configuration
4. **`SettingsManager.swift`** — Store search provider preference and API key
5. **`KeychainManager.swift`** — Store search API key securely

### Data Flow

```
User sends message (searchEnabled = true)
  → ChatViewModel.streamResponse()
    → SearchService.search(query)
    → Inject results into system prompt
    → Stream LLM response with search context
    → Display response with citations
```

---

## Recommendation

Start with **Tavily** as the primary search provider — it's specifically optimized for LLM integration, has a free tier for testing, and produces clean results that work well as context. The integration point is straightforward: fetch results before building the chat messages in `streamResponse()` and inject them into the system prompt.
