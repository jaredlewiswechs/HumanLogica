// Token.swift — Token Types for Logica
// Twenty-five keywords. Three values. One language.

import Foundation

public enum TokenType: String, CaseIterable, Sendable {
    // Literals
    case integer = "INTEGER"
    case float = "FLOAT"
    case string = "STRING"
    case boolean = "BOOLEAN"

    // Identifiers
    case identifier = "IDENTIFIER"

    // Keywords — Identity
    case speaker = "SPEAKER"
    case `as` = "AS"

    // Keywords — Variables
    case `let` = "LET"
    case read = "READ"

    // Keywords — Expressions
    case speak = "SPEAK"
    case when = "WHEN"
    case otherwise = "OTHERWISE"
    case broken = "BROKEN"

    // Keywords — Functions
    case fn = "FN"
    case `return` = "RETURN"

    // Keywords — Loops
    case `while` = "WHILE"
    case max = "MAX"

    // Keywords — Communication
    case request = "REQUEST"
    case respond = "RESPOND"
    case accept = "ACCEPT"
    case refuse = "REFUSE"

    // Keywords — Inspection
    case inspect = "INSPECT"
    case history = "HISTORY"
    case ledger = "LEDGER"
    case verify = "VERIFY"

    // Keywords — Worlds
    case world = "WORLD"
    case seal = "SEAL"

    // Keywords — Logic
    case and = "AND"
    case or = "OR"
    case not = "NOT"

    // Keywords — Values
    case active = "ACTIVE"
    case inactive = "INACTIVE"
    case `true` = "TRUE"
    case `false` = "FALSE"
    case none = "NONE"

    // Keywords — Control
    case `if` = "IF"
    case elif = "ELIF"
    case `else` = "ELSE"
    case pass = "PASS"
    case fail = "FAIL"

    // Operators
    case plus = "PLUS"
    case minus = "MINUS"
    case star = "STAR"
    case slash = "SLASH"
    case percent = "PERCENT"
    case assign = "ASSIGN"
    case eq = "EQ"
    case neq = "NEQ"
    case lt = "LT"
    case gt = "GT"
    case lte = "LTE"
    case gte = "GTE"
    case dot = "DOT"
    case comma = "COMMA"
    case colon = "COLON"
    case arrow = "ARROW"

    // Delimiters
    case lbrace = "LBRACE"
    case rbrace = "RBRACE"
    case lparen = "LPAREN"
    case rparen = "RPAREN"
    case lbracket = "LBRACKET"
    case rbracket = "RBRACKET"

    // Special
    case newline = "NEWLINE"
    case eof = "EOF"
    case comment = "COMMENT"
}

/// Keyword map
public let logicaKeywords: [String: TokenType] = [
    "speaker": .speaker, "as": .as, "let": .let, "read": .read,
    "speak": .speak, "when": .when, "otherwise": .otherwise, "broken": .broken,
    "fn": .fn, "return": .return, "while": .while, "max": .max,
    "request": .request, "respond": .respond, "accept": .accept, "refuse": .refuse,
    "inspect": .inspect, "history": .history, "ledger": .ledger, "verify": .verify,
    "world": .world, "seal": .seal,
    "and": .and, "or": .or, "not": .not,
    "active": .active, "inactive": .inactive, "true": .true, "false": .false, "none": .none,
    "if": .if, "elif": .elif, "else": .else, "pass": .pass, "fail": .fail,
]

/// All keywords for syntax highlighting.
public let allLogicaKeywords: Set<String> = Set(logicaKeywords.keys)

public struct Token: CustomStringConvertible {
    public let type: TokenType
    public let value: String
    public let line: Int
    public let col: Int

    public init(type: TokenType, value: String, line: Int, col: Int) {
        self.type = type
        self.value = value
        self.line = line
        self.col = col
    }

    public var description: String {
        "Token(\(type.rawValue), \"\(value)\", L\(line):\(col))"
    }
}
