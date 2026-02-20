// EditorView.swift — The Code Editor
// Syntax-highlighted text editor for .logica files.

import SwiftUI
import HumanLogicaCore

struct EditorView: View {
    @EnvironmentObject var viewModel: IDEViewModel
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                LineNumberGutter(text: viewModel.sourceCode, fontSize: fontSize)
                    .frame(width: 44)

                Divider()
            }

            TextEditor(text: Binding(
                get: { viewModel.sourceCode },
                set: { viewModel.updateSource($0) }
            ))
            .font(.system(size: fontSize, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                // Syntax highlighting overlay
                SyntaxHighlightOverlay(source: viewModel.sourceCode, fontSize: fontSize)
                    .allowsHitTesting(false),
                alignment: .topLeading
            )
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Line Number Gutter

struct LineNumberGutter: View {
    let text: String
    let fontSize: Double

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(1, lineCount), id: \.self) { lineNum in
                    Text("\(lineNum)")
                        .font(.system(size: fontSize - 2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(height: fontSize * 1.45)
                }
            }
            .padding(.top, 7)
            .padding(.horizontal, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var lineCount: Int {
        text.components(separatedBy: "\n").count
    }
}

// MARK: - Syntax Highlight Overlay

struct SyntaxHighlightOverlay: View {
    let source: String
    let fontSize: Double

    var body: some View {
        // The overlay provides visual hints without interfering with editing.
        // In a production app, this would use NSTextView with attributed strings
        // for proper syntax highlighting. For now, the TextEditor handles editing
        // and we rely on the inspector's token view for detailed token info.
        Color.clear
    }
}

// MARK: - Syntax Highlighted Text (for read-only display)

struct SyntaxHighlightedText: View {
    let source: String
    let fontSize: Double

    var body: some View {
        let attributed = highlightSource(source)

        Text(attributed)
            .font(.system(size: fontSize, design: .monospaced))
            .textSelection(.enabled)
    }

    private func highlightSource(_ source: String) -> AttributedString {
        var result = AttributedString()

        let (tokens, _) = tokenizeLogica(source: source)
        var lastPos = source.startIndex

        for token in tokens {
            guard token.type != .eof else { break }

            // Find the token's range in the source
            let tokenStr = token.value.isEmpty && token.type == .newline ? "\n" : token.value
            if let range = source.range(of: tokenStr, range: lastPos..<source.endIndex) {
                // Add any text before this token (whitespace, etc.)
                if lastPos < range.lowerBound {
                    var plain = AttributedString(source[lastPos..<range.lowerBound])
                    plain.foregroundColor = .primary
                    result += plain
                }

                // Add the token with its color
                var tokenAttr = AttributedString(tokenStr)
                tokenAttr.foregroundColor = colorForTokenType(token.type)
                if isKeyword(token.type) {
                    tokenAttr.font = .system(size: fontSize, weight: .semibold, design: .monospaced)
                }
                result += tokenAttr

                lastPos = range.upperBound
            }
        }

        // Add remaining text
        if lastPos < source.endIndex {
            var remaining = AttributedString(source[lastPos...])
            remaining.foregroundColor = .primary
            result += remaining
        }

        return result
    }

    private func colorForTokenType(_ type: TokenType) -> Color {
        switch type {
        // Keywords
        case .speaker, .as, .let, .speak, .when, .otherwise, .broken,
             .fn, .return, .while, .max, .request, .respond, .accept,
             .refuse, .inspect, .history, .ledger, .verify, .world, .seal,
             .if, .elif, .else, .pass, .fail:
            return .purple

        // Logic operators
        case .and, .or, .not:
            return .purple

        // Values
        case .active, .inactive:
            return .orange
        case .true, .false:
            return .orange
        case .none:
            return .gray

        // Literals
        case .string:
            return .green
        case .integer, .float:
            return .cyan
        case .read:
            return .blue

        // Identifiers
        case .identifier:
            return .primary

        // Operators
        case .plus, .minus, .star, .slash, .percent, .assign,
             .eq, .neq, .lt, .gt, .lte, .gte, .arrow:
            return .secondary

        // Comments
        case .comment:
            return .gray

        default:
            return .primary
        }
    }

    private func isKeyword(_ type: TokenType) -> Bool {
        switch type {
        case .speaker, .as, .let, .speak, .when, .otherwise, .broken,
             .fn, .return, .while, .max, .request, .respond, .accept,
             .refuse, .inspect, .history, .ledger, .verify, .world, .seal,
             .and, .or, .not, .if, .elif, .else, .pass, .fail,
             .active, .inactive, .true, .false, .none, .read:
            return true
        default:
            return false
        }
    }
}
