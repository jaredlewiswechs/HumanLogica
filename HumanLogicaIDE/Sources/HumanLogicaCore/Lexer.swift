// Lexer.swift — Breaking Source Into Tokens
// Supports: # line comments, string literals, integers, floats,
// all operators and delimiters, 25 keywords.

import Foundation

public class Lexer {
    private let source: [Character]
    private var pos: Int = 0
    private var line: Int = 1
    private var col: Int = 1
    public private(set) var tokens: [Token] = []

    public init(source: String) {
        self.source = Array(source)
    }

    /// Tokenize the entire source. Returns list of tokens.
    public func tokenize() throws -> [Token] {
        while pos < source.count {
            skipWhitespace()
            guard pos < source.count else { break }

            let ch = source[pos]

            // Newlines
            if ch == "\n" {
                addToken(.newline, "\n")
                advance()
                continue
            }

            // Comments
            if ch == "#" {
                readComment()
                continue
            }

            // Strings
            if ch == "\"" || ch == "'" {
                try readString(quote: ch)
                continue
            }

            // Numbers
            if ch.isNumber {
                readNumber()
                continue
            }

            // Identifiers and keywords
            if ch.isLetter || ch == "_" {
                readIdentifier()
                continue
            }

            // Two-character operators
            if pos + 1 < source.count {
                let two = String(source[pos...pos+1])
                switch two {
                case "==":
                    addToken(.eq, "=="); advance(2); continue
                case "!=":
                    addToken(.neq, "!="); advance(2); continue
                case "<=":
                    addToken(.lte, "<="); advance(2); continue
                case ">=":
                    addToken(.gte, ">="); advance(2); continue
                case "->":
                    addToken(.arrow, "->"); advance(2); continue
                default:
                    break
                }
            }

            // Single-character operators and delimiters
            let singleMap: [Character: TokenType] = [
                "+": .plus, "-": .minus, "*": .star, "/": .slash,
                "%": .percent, "=": .assign, "<": .lt, ">": .gt,
                ".": .dot, ",": .comma, ":": .colon,
                "{": .lbrace, "}": .rbrace, "(": .lparen, ")": .rparen,
                "[": .lbracket, "]": .rbracket,
            ]

            if let tokenType = singleMap[ch] {
                addToken(tokenType, String(ch))
                advance()
                continue
            }

            throw LogicaError.lexError(message: "unexpected character: '\(ch)'", line: line, col: col)
        }

        addToken(.eof, "")
        return tokens
    }

    // MARK: - Private Helpers

    private func skipWhitespace() {
        while pos < source.count && (source[pos] == " " || source[pos] == "\t" || source[pos] == "\r") {
            advance()
        }
    }

    private func advance(_ n: Int = 1) {
        for _ in 0..<n {
            guard pos < source.count else { return }
            if source[pos] == "\n" {
                line += 1
                col = 1
            } else {
                col += 1
            }
            pos += 1
        }
    }

    private func addToken(_ type: TokenType, _ value: String) {
        tokens.append(Token(type: type, value: value, line: line, col: col))
    }

    private func readComment() {
        advance() // skip #
        while pos < source.count && source[pos] != "\n" {
            advance()
        }
    }

    private func readString(quote: Character) throws {
        let startLine = line
        let startCol = col
        advance() // skip opening quote
        var value = ""

        while pos < source.count {
            let ch = source[pos]
            if ch == "\\" && pos + 1 < source.count {
                let next = source[pos + 1]
                let escapes: [Character: Character] = ["n": "\n", "t": "\t", "\\": "\\", quote: quote]
                if let escaped = escapes[next] {
                    value.append(escaped)
                    advance(2)
                    continue
                }
            }
            if ch == quote {
                advance() // skip closing quote
                tokens.append(Token(type: .string, value: value, line: startLine, col: startCol))
                return
            }
            if ch == "\n" {
                throw LogicaError.lexError(message: "unterminated string", line: startLine, col: startCol)
            }
            value.append(ch)
            advance()
        }
        throw LogicaError.lexError(message: "unterminated string", line: startLine, col: startCol)
    }

    private func readNumber() {
        let startCol = col
        var value = ""
        var isFloat = false

        while pos < source.count && (source[pos].isNumber || source[pos] == ".") {
            if source[pos] == "." {
                if isFloat { break }
                if pos + 1 < source.count && source[pos + 1].isNumber {
                    isFloat = true
                } else {
                    break
                }
            }
            value.append(source[pos])
            advance()
        }

        tokens.append(Token(type: isFloat ? .float : .integer, value: value, line: line, col: startCol))
    }

    private func readIdentifier() {
        let startCol = col
        var value = ""

        while pos < source.count && (source[pos].isLetter || source[pos].isNumber || source[pos] == "_") {
            value.append(source[pos])
            advance()
        }

        let tokenType = logicaKeywords[value] ?? .identifier
        tokens.append(Token(type: tokenType, value: value, line: line, col: startCol))
    }
}
