import SwiftUI

enum MarkdownRenderer {
    static func render(_ text: String) -> AttributedString {
        do {
            var result = try AttributedString(markdown: text, options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
            for run in result.runs {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    let range = run.range
                    result[range].font = .system(.body, design: .monospaced)
                    result[range].backgroundColor = Color(.systemGray5)
                }
            }
            return result
        } catch {
            return AttributedString(text)
        }
    }
}
