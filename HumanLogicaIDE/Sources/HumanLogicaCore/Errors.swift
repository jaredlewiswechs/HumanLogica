// Errors.swift — What Goes Wrong and Why
// Every error maps to a violation. Every violation cites an axiom.

import Foundation

/// Base error for the Logica language.
public enum LogicaError: Error, CustomStringConvertible {
    case lexError(message: String, line: Int?, col: Int?)
    case parseError(message: String, line: Int?, col: Int?)
    case axiomViolation(axiom: Int, name: String, message: String, line: Int?)
    case runtimeError(message: String, speaker: String?)

    public var description: String {
        switch self {
        case .lexError(let message, let line, let col):
            let loc = line != nil ? " at line \(line!), col \(col ?? 0)" : ""
            return "Lex error\(loc): \(message)"
        case .parseError(let message, let line, let col):
            let loc = line != nil ? " at line \(line!), col \(col ?? 0)" : ""
            return "Parse error\(loc): \(message)"
        case .axiomViolation(let axiom, let name, let message, let line):
            let loc = line != nil ? " (line \(line!))" : ""
            return "Axiom \(axiom) violation\(loc) — \(name): \(message)"
        case .runtimeError(let message, let speaker):
            let who = speaker != nil ? " [\(speaker!)]" : ""
            return "Broken\(who): \(message)"
        }
    }
}
