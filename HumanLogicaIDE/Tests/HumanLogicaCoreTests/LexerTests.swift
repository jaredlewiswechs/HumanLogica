// LexerTests.swift — Tests for Logica Lexer

import XCTest
@testable import HumanLogicaCore

final class LexerTests: XCTestCase {

    // MARK: - Basic Tokenization

    func testEmptySource() throws {
        let lexer = Lexer(source: "")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .eof)
    }

    func testSingleKeyword() throws {
        let lexer = Lexer(source: "speaker")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens.count, 2) // speaker + eof
        XCTAssertEqual(tokens[0].type, .speaker)
        XCTAssertEqual(tokens[0].value, "speaker")
    }

    func testAllKeywords() throws {
        let keywords = [
            "speaker", "as", "let", "read", "speak", "when", "otherwise",
            "broken", "fn", "return", "while", "max", "request", "respond",
            "accept", "refuse", "inspect", "history", "ledger", "verify",
            "world", "seal", "and", "or", "not", "active", "inactive",
            "true", "false", "none", "if", "elif", "else", "pass", "fail",
        ]
        for keyword in keywords {
            let lexer = Lexer(source: keyword)
            let tokens = try lexer.tokenize()
            XCTAssertEqual(tokens.count, 2, "keyword '\(keyword)' should produce 2 tokens (keyword + eof)")
            XCTAssertNotEqual(tokens[0].type, .identifier, "'\(keyword)' should be recognized as a keyword, not identifier")
        }
    }

    func testIdentifier() throws {
        let lexer = Lexer(source: "myVar")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "myVar")
    }

    func testIdentifierWithUnderscore() throws {
        let lexer = Lexer(source: "my_var_123")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "my_var_123")
    }

    // MARK: - Number Literals

    func testIntegerLiteral() throws {
        let lexer = Lexer(source: "42")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .integer)
        XCTAssertEqual(tokens[0].value, "42")
    }

    func testFloatLiteral() throws {
        let lexer = Lexer(source: "3.14")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .float)
        XCTAssertEqual(tokens[0].value, "3.14")
    }

    func testIntegerFollowedByDot() throws {
        // "42." where dot is not followed by a digit should be integer + dot
        let lexer = Lexer(source: "42.name")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .integer)
        XCTAssertEqual(tokens[0].value, "42")
        XCTAssertEqual(tokens[1].type, .dot)
    }

    // MARK: - String Literals

    func testStringLiteralDouble() throws {
        let lexer = Lexer(source: "\"hello world\"")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .string)
        XCTAssertEqual(tokens[0].value, "hello world")
    }

    func testStringLiteralSingle() throws {
        let lexer = Lexer(source: "'hello'")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].type, .string)
        XCTAssertEqual(tokens[0].value, "hello")
    }

    func testStringEscapes() throws {
        let lexer = Lexer(source: "\"hello\\nworld\"")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].value, "hello\nworld")
    }

    func testStringEscapeTab() throws {
        let lexer = Lexer(source: "\"col1\\tcol2\"")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].value, "col1\tcol2")
    }

    func testStringEscapeBackslash() throws {
        let lexer = Lexer(source: "\"path\\\\file\"")
        let tokens = try lexer.tokenize()
        XCTAssertEqual(tokens[0].value, "path\\file")
    }

    func testUnterminatedString() {
        let lexer = Lexer(source: "\"hello")
        XCTAssertThrowsError(try lexer.tokenize()) { error in
            guard case LogicaError.lexError = error else {
                XCTFail("Expected lexError, got \(error)")
                return
            }
        }
    }

    func testMultilineStringThrows() {
        let lexer = Lexer(source: "\"hello\nworld\"")
        XCTAssertThrowsError(try lexer.tokenize()) { error in
            guard case LogicaError.lexError = error else {
                XCTFail("Expected lexError, got \(error)")
                return
            }
        }
    }

    // MARK: - Operators

    func testTwoCharOperators() throws {
        let ops: [(String, TokenType)] = [
            ("==", .eq), ("!=", .neq), ("<=", .lte), (">=", .gte), ("->", .arrow),
        ]
        for (op, expectedType) in ops {
            let lexer = Lexer(source: op)
            let tokens = try lexer.tokenize()
            XCTAssertEqual(tokens[0].type, expectedType, "operator '\(op)' should be \(expectedType)")
        }
    }

    func testSingleCharOperators() throws {
        let ops: [(String, TokenType)] = [
            ("+", .plus), ("-", .minus), ("*", .star), ("/", .slash),
            ("%", .percent), ("=", .assign), ("<", .lt), (">", .gt),
            (".", .dot), (",", .comma), (":", .colon),
            ("{", .lbrace), ("}", .rbrace), ("(", .lparen), (")", .rparen),
            ("[", .lbracket), ("]", .rbracket),
        ]
        for (op, expectedType) in ops {
            let lexer = Lexer(source: op)
            let tokens = try lexer.tokenize()
            XCTAssertEqual(tokens[0].type, expectedType, "operator '\(op)' should be \(expectedType)")
        }
    }

    // MARK: - Comments

    func testCommentSkipped() throws {
        let lexer = Lexer(source: "# this is a comment\nspeaker")
        let tokens = try lexer.tokenize()
        // Should have newline, speaker, eof
        let nonNewlineTokens = tokens.filter { $0.type != .newline && $0.type != .eof }
        XCTAssertEqual(nonNewlineTokens.count, 1)
        XCTAssertEqual(nonNewlineTokens[0].type, .speaker)
    }

    // MARK: - Line/Column Tracking

    func testLineTracking() throws {
        let lexer = Lexer(source: "speaker\nJared")
        let tokens = try lexer.tokenize()
        let speakerToken = tokens.first { $0.type == .speaker }!
        let jaredToken = tokens.first { $0.type == .identifier }!
        XCTAssertEqual(speakerToken.line, 1)
        XCTAssertEqual(jaredToken.line, 2)
    }

    func testColumnTracking() throws {
        let lexer = Lexer(source: "  speaker Jared")
        let tokens = try lexer.tokenize()
        let speakerToken = tokens.first { $0.type == .speaker }!
        let jaredToken = tokens.first { $0.type == .identifier }!
        XCTAssertEqual(speakerToken.col, 3)
        XCTAssertEqual(jaredToken.col, 11)
    }

    // MARK: - Unexpected Character

    func testUnexpectedCharacter() {
        let lexer = Lexer(source: "@")
        XCTAssertThrowsError(try lexer.tokenize()) { error in
            guard case LogicaError.lexError = error else {
                XCTFail("Expected lexError, got \(error)")
                return
            }
        }
    }

    // MARK: - Full Program Tokenization

    func testFullProgramTokenization() throws {
        let source = """
        speaker Jared

        as Jared {
            speak "Hello"
        }
        """
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let meaningful = tokens.filter { $0.type != .newline && $0.type != .eof }
        XCTAssertGreaterThan(meaningful.count, 5)

        XCTAssertEqual(meaningful[0].type, .speaker)
        XCTAssertEqual(meaningful[1].type, .identifier)
        XCTAssertEqual(meaningful[1].value, "Jared")
        XCTAssertEqual(meaningful[2].type, .as)
        XCTAssertEqual(meaningful[3].type, .identifier)
        XCTAssertEqual(meaningful[4].type, .lbrace)
        XCTAssertEqual(meaningful[5].type, .speak)
        XCTAssertEqual(meaningful[6].type, .string)
        XCTAssertEqual(meaningful[6].value, "Hello")
        XCTAssertEqual(meaningful[7].type, .rbrace)
    }
}
