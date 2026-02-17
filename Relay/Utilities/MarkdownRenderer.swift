import SwiftUI

enum AppTheme {
    enum Radius {
        static let bubble: CGFloat = 22
        static let card: CGFloat = 20
        static let control: CGFloat = 18
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
    }

    enum Border {
        static let hairline: CGFloat = 0.5
        static let thin: CGFloat = 0.6
    }

    enum Motion {
        static let quick: CGFloat = 0.16
        static let standard: CGFloat = 0.22
        static let smooth: CGFloat = 0.30
    }

    enum Colors {
        static let surface = Color.primary.opacity(0.05)
        static let elevatedSurface = Color.primary.opacity(0.07)
        static let subtleBorder = Color.primary.opacity(0.16)
        static let userBubble = Color.accentColor
        static let assistantBubble = Color.primary.opacity(0.10)
        static let pinnedTint = Color.accentColor.opacity(0.08)
    }
}

enum MarkdownRenderer {
    static func render(_ text: String) -> AttributedString {
        do {
            var result = try AttributedString(markdown: text, options: .init(
                interpretedSyntax: .full
            ))

            // Phase 1: Insert newlines between blocks and bullet prefixes for list items.
            // .full parsing strips literal newlines, replacing them with presentationIntent
            // metadata. We need to re-insert separators so Text renders blocks apart.
            var lastParagraphID: Int? = nil
            var insertions: [(index: AttributedString.Index, text: String)] = []

            for run in result.runs {
                guard let intent = run.presentationIntent else { continue }
                guard let paragraphComponent = intent.components.first else { continue }
                let paragraphID = paragraphComponent.identity
                guard paragraphID != lastParagraphID else { continue }

                var prefix = ""
                if lastParagraphID != nil {
                    prefix += "\n"
                }

                // Add bullet/number prefix for list items
                for component in intent.components {
                    if case .listItem(ordinal: let ordinal) = component.kind {
                        let isOrdered = intent.components.contains {
                            if case .orderedList = $0.kind { return true }
                            return false
                        }
                        prefix += isOrdered ? "\(ordinal). " : "• "
                    }
                }

                if !prefix.isEmpty {
                    insertions.append((run.range.lowerBound, prefix))
                }
                lastParagraphID = paragraphID
            }

            for insertion in insertions.reversed() {
                result.insert(AttributedString(insertion.text), at: insertion.index)
            }

            // Phase 2: Apply block-level and inline styling
            for run in result.runs {
                let range = run.range

                if let intent = run.presentationIntent {
                    for component in intent.components {
                        switch component.kind {
                        case .header(level: 1):
                            result[range].font = .system(.title2, design: .default, weight: .bold)
                        case .header(level: 2):
                            result[range].font = .system(.headline)
                        case .header(level: 3...):
                            result[range].font = .system(.subheadline, design: .default, weight: .bold)
                        case .codeBlock:
                            result[range].font = .system(.body, design: .monospaced)
                            result[range].backgroundColor = AppTheme.Colors.assistantBubble
                        case .blockQuote:
                            result[range].foregroundColor = .secondary
                            if result[range].font == nil {
                                result[range].font = .system(.body).italic()
                            }
                        default:
                            break
                        }
                    }
                }

                // Inline code styling
                if run.inlinePresentationIntent?.contains(.code) == true {
                    result[range].font = .system(.body, design: .monospaced)
                    result[range].backgroundColor = AppTheme.Colors.assistantBubble
                }
            }
            return result
        } catch {
            return AttributedString(text)
        }
    }
}
