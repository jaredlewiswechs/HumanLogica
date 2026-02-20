// SyntaxHighlighter.swift — Logica Syntax Coloring
// Maps token types to colors for the editor and inspector.

import SwiftUI
import HumanLogicaCore

/// Color theme for Logica syntax highlighting.
public struct LogicaTheme {
    public let keyword: Color
    public let speaker: Color
    public let string: Color
    public let number: Color
    public let statusValue: Color
    public let comment: Color
    public let `operator`: Color
    public let identifier: Color
    public let background: Color
    public let text: Color

    public static let dark = LogicaTheme(
        keyword: Color(red: 0.78, green: 0.46, blue: 0.92),    // purple
        speaker: Color(red: 0.35, green: 0.75, blue: 0.95),    // blue
        string: Color(red: 0.45, green: 0.83, blue: 0.45),     // green
        number: Color(red: 0.52, green: 0.86, blue: 0.95),     // cyan
        statusValue: Color(red: 0.95, green: 0.68, blue: 0.32), // orange
        comment: Color(red: 0.5, green: 0.5, blue: 0.55),      // gray
        operator: Color(red: 0.75, green: 0.75, blue: 0.8),    // light gray
        identifier: Color(red: 0.9, green: 0.9, blue: 0.92),   // near white
        background: Color(red: 0.11, green: 0.11, blue: 0.13),
        text: Color(red: 0.9, green: 0.9, blue: 0.92)
    )

    public static let light = LogicaTheme(
        keyword: Color(red: 0.55, green: 0.2, blue: 0.78),
        speaker: Color(red: 0.15, green: 0.45, blue: 0.75),
        string: Color(red: 0.2, green: 0.6, blue: 0.2),
        number: Color(red: 0.12, green: 0.5, blue: 0.65),
        statusValue: Color(red: 0.85, green: 0.5, blue: 0.1),
        comment: Color(red: 0.45, green: 0.45, blue: 0.5),
        operator: Color(red: 0.35, green: 0.35, blue: 0.4),
        identifier: Color(red: 0.15, green: 0.15, blue: 0.18),
        background: .white,
        text: Color(red: 0.15, green: 0.15, blue: 0.18)
    )

    /// Get the color for a given token type.
    public func color(for tokenType: TokenType) -> Color {
        switch tokenType {
        // Keywords
        case .speaker, .as, .let, .speak, .when, .otherwise, .broken,
             .fn, .return, .while, .max, .request, .respond, .accept,
             .refuse, .inspect, .history, .ledger, .verify, .world, .seal,
             .and, .or, .not, .if, .elif, .else, .pass, .fail, .read:
            return keyword

        // Status/boolean values
        case .active, .inactive, .true, .false, .none:
            return statusValue

        // Literals
        case .string:
            return string
        case .integer, .float:
            return number

        // Identifiers
        case .identifier:
            return identifier

        // Operators
        case .plus, .minus, .star, .slash, .percent, .assign,
             .eq, .neq, .lt, .gt, .lte, .gte, .arrow, .dot,
             .comma, .colon:
            return self.operator

        // Delimiters
        case .lbrace, .rbrace, .lparen, .rparen, .lbracket, .rbracket:
            return self.operator

        // Comments
        case .comment:
            return comment

        // Special
        case .newline, .eof, .boolean:
            return text
        }
    }
}

/// Determines which Logica keywords should be bolded.
public func isLogicaKeyword(_ type: TokenType) -> Bool {
    switch type {
    case .speaker, .as, .let, .speak, .when, .otherwise, .broken,
         .fn, .return, .while, .max, .request, .respond, .accept,
         .refuse, .inspect, .history, .ledger, .verify, .world, .seal,
         .and, .or, .not, .if, .elif, .else, .pass, .fail, .read,
         .active, .inactive, .true, .false, .none:
        return true
    default:
        return false
    }
}
