# iOS LLM Chat App — Design Document

## Overview

A native SwiftUI iOS 26 app for chatting with LLMs. Supports OpenAI, Anthropic, and OpenRouter with user-provided API keys. Multi-conversation, streaming responses, markdown rendering, system prompts, and model selection — all with a clean iOS 26 liquid glass aesthetic.

## Providers

- **OpenAI** — GPT-4o, o1, etc. via OpenAI Chat Completions API
- **Anthropic** — Claude models via Messages API (different request/response format)
- **OpenRouter** — OpenAI-compatible API shape, custom base URL, broad model catalog

## Architecture

SwiftUI + MVVM + Swift Concurrency. Zero third-party dependencies.

```
LLMChat/
├── App/
│   └── LLMChatApp.swift
├── Models/
│   ├── Conversation.swift         — SwiftData model
│   ├── Message.swift              — SwiftData model
│   └── Provider.swift             — Enum + config
├── Services/
│   ├── LLMService.swift           — Protocol
│   ├── OpenAIService.swift        — OpenAI + OpenRouter
│   ├── AnthropicService.swift     — Claude Messages API
│   └── KeychainManager.swift      — Secure key storage
├── ViewModels/
│   ├── ConversationListViewModel.swift
│   └── ChatViewModel.swift
├── Views/
│   ├── ConversationListView.swift
│   ├── ChatView.swift
│   ├── MessageBubbleView.swift
│   ├── StreamingIndicator.swift
│   ├── SettingsView.swift
│   └── NewChatSheet.swift
└── Utilities/
    ├── MarkdownRenderer.swift
    └── HapticManager.swift
```

## Data Models

### Conversation
- id (UUID), title (String), systemPrompt (String?), provider (Provider), modelId (String), createdAt (Date), updatedAt (Date)
- Has-many relationship to Message

### Message
- id (UUID), role (system/user/assistant), content (String), timestamp (Date), isError (Bool)

### Provider Config
- API keys stored in Keychain
- Base URL configurable (for OpenRouter)
- Hardcoded model lists per provider

## Streaming & Networking

- OpenAI/OpenRouter: SSE via `URLSession.bytes(for:)`, parse `data: {...}` lines
- Anthropic: SSE, parse `event: content_block_delta` events
- All return `AsyncThrowingStream<String, Error>`
- Errors (401, 429, network) shown inline in chat with retry option
- Cancel via Task cancellation

## UI Design

- NavigationSplitView — sidebar on iPad, sheet navigation on iPhone
- Liquid glass toolbar with model name subtitle
- User messages: right-aligned, tinted bubble
- Assistant messages: left-aligned, full-width, no bubble
- Input bar: TextField + send button, glass material, keyboard-aware
- Streaming: character fade-in with blinking cursor
- Empty state: centered suggestion with model name

## Settings

- Tab per provider with secure API key field
- Model picker per provider
- Haptic feedback toggle
