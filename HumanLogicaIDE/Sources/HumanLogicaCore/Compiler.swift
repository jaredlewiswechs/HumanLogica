// Compiler.swift — The Proof Checker
// Walks the AST and checks every axiom. If violated, the program is invalid.

import Foundation

/// The operations Mary understands.
public enum OpType: String, CaseIterable {
    case createSpeaker = "CREATE_SPEAKER"
    case setSpeaker = "SET_SPEAKER"
    case writeVar = "WRITE_VAR"
    case readVar = "READ_VAR"
    case speakOutput = "SPEAK_OUTPUT"
    case submitExpr = "SUBMIT_EXPR"
    case fnDefine = "FN_DEFINE"
    case fnCall = "FN_CALL"
    case returnOp = "RETURN"
    case whenEval = "WHEN_EVAL"
    case ifEval = "IF_EVAL"
    case loopStart = "LOOP_START"
    case loopEnd = "LOOP_END"
    case request = "REQUEST"
    case respond = "RESPOND"
    case inspect = "INSPECT"
    case historyOp = "HISTORY"
    case ledgerRead = "LEDGER_READ"
    case ledgerVerify = "LEDGER_VERIFY"
    case seal = "SEAL"
    case fail = "FAIL"
    case pass = "PASS"
    case createWorld = "CREATE_WORLD"
    case evalExpr = "EVAL_EXPR"
}

/// One compiled operation.
public class Operation {
    public let op: OpType
    public let speaker: String?
    public let args: [String: Any]
    public let line: Int

    public init(op: OpType, speaker: String? = nil, args: [String: Any] = [:], line: Int = 0) {
        self.op = op
        self.speaker = speaker
        self.args = args
        self.line = line
    }
}

/// The output of compilation.
public class CompiledProgram {
    public var operations: [Operation] = []
    public var speakers: [String] = []
    public var functions: [String: [String]] = [:]
    public var worlds: [String] = []

    public init() {}
}

/// Walks the AST. Checks axioms. Produces operations.
public class Compiler {
    private var currentSpeaker: String? = nil
    private var declaredSpeakers: Set<String> = []
    private var declaredFunctions: [String: [String]] = [:]
    private var sealedVars: Set<String> = []
    private var operations: [Operation] = []

    public init() {}

    public func compile(_ program: Program) throws -> CompiledProgram {
        // First pass: collect all speaker declarations
        for stmt in program.statements {
            if let decl = stmt as? SpeakerDecl {
                declaredSpeakers.insert(decl.name)
            }
        }

        // Axiom 1 check: code but no speakers
        let hasCode = program.statements.contains { !($0 is SpeakerDecl) && !($0 is WorldDecl) }
        if hasCode && declaredSpeakers.isEmpty {
            throw LogicaError.axiomViolation(
                axiom: 1, name: "Speaker Requirement",
                message: "program has code but no speakers declared. Every operation requires a speaker.",
                line: nil
            )
        }

        // Second pass: compile
        for stmt in program.statements {
            try compileStatement(stmt)
        }

        let compiled = CompiledProgram()
        compiled.operations = operations
        compiled.speakers = Array(declaredSpeakers)
        compiled.functions = declaredFunctions
        return compiled
    }

    // MARK: - Statement Compilation

    private func compileStatement(_ stmt: ASTNode) throws {
        switch stmt {
        case let s as SpeakerDecl:
            compileSpeakerDecl(s)
        case let s as WorldDecl:
            try compileWorldDecl(s)
        case let s as AsBlock:
            try compileAsBlock(s)
        case let s as LetStatement:
            try compileLet(s)
        case let s as SpeakStatement:
            try compileSpeak(s)
        case let s as WhenBlock:
            try compileWhen(s)
        case let s as IfStatement:
            try compileIf(s)
        case let s as WhileLoop:
            try compileWhile(s)
        case let s as FnDecl:
            try compileFn(s)
        case let s as ReturnStatement:
            try compileReturn(s)
        case let s as RequestStatement:
            try compileRequest(s)
        case let s as RespondStatement:
            try compileRespond(s)
        case let s as InspectStatement:
            try compileInspect(s)
        case let s as HistoryStatement:
            try compileHistory(s)
        case let s as LedgerStatement:
            try compileLedgerStmt(s)
        case let s as VerifyStatement:
            try compileVerify(s)
        case let s as SealStatement:
            try compileSeal(s)
        case is PassStatement:
            emit(.pass, line: stmt.line)
        case let s as FailStatement:
            try compileFail(s)
        case let s as ExpressionStatement:
            try compileExprStatement(s)
        default:
            throw LogicaError.parseError(message: "unknown statement type", line: stmt.line, col: stmt.col)
        }
    }

    private func compileSpeakerDecl(_ stmt: SpeakerDecl) {
        declaredSpeakers.insert(stmt.name)
        emit(.createSpeaker, args: ["name": stmt.name], line: stmt.line)
    }

    private func compileWorldDecl(_ stmt: WorldDecl) throws {
        try checkSpeakerContext(stmt)
        emit(.createWorld, args: ["name": stmt.name], line: stmt.line)
    }

    private func compileAsBlock(_ stmt: AsBlock) throws {
        guard declaredSpeakers.contains(stmt.speakerName) else {
            throw LogicaError.axiomViolation(
                axiom: 1, name: "Speaker Requirement",
                message: "speaker '\(stmt.speakerName)' not declared. Declare with: speaker \(stmt.speakerName)",
                line: stmt.line
            )
        }

        let prevSpeaker = currentSpeaker
        currentSpeaker = stmt.speakerName
        emit(.setSpeaker, args: ["name": stmt.speakerName], line: stmt.line)

        for bodyStmt in stmt.body {
            try compileStatement(bodyStmt)
        }

        currentSpeaker = prevSpeaker
        if let prev = prevSpeaker {
            emit(.setSpeaker, args: ["name": prev], line: stmt.line)
        }
    }

    private func compileLet(_ stmt: LetStatement) throws {
        try checkSpeakerContext(stmt)

        // Axiom 8: Write Ownership
        let name = stmt.name
        if name.contains(".") {
            let parts = name.split(separator: ".").map(String.init)
            for part in parts {
                if declaredSpeakers.contains(part) && part != currentSpeaker {
                    throw LogicaError.axiomViolation(
                        axiom: 8, name: "Write Ownership",
                        message: "speaker '\(currentSpeaker!)' cannot write to '\(part)' variables. Only '\(part)' can write to '\(part)' variables. This is not a permission. It is math.",
                        line: stmt.line
                    )
                }
            }
        }

        // Check sealed
        let sealedKey = "\(currentSpeaker!).\(name)"
        if sealedVars.contains(sealedKey) {
            throw LogicaError.axiomViolation(
                axiom: 5, name: "Ledger Integrity",
                message: "variable '\(name)' is sealed. Sealed variables cannot be overwritten.",
                line: stmt.line
            )
        }

        emit(.writeVar, args: ["name": name, "value_ast": stmt.value], line: stmt.line)
    }

    private func compileSpeak(_ stmt: SpeakStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.speakOutput, args: ["value_ast": stmt.value], line: stmt.line)
    }

    private func compileWhen(_ stmt: WhenBlock) throws {
        try checkSpeakerContext(stmt)
        emit(.whenEval, args: [
            "condition_ast": stmt.condition,
            "body": stmt.body,
            "otherwise_body": stmt.otherwiseBody,
            "broken_body": stmt.brokenBody,
        ], line: stmt.line)

        try checkBlockAxioms(stmt.body)
        try checkBlockAxioms(stmt.otherwiseBody)
        try checkBlockAxioms(stmt.brokenBody)
    }

    private func compileIf(_ stmt: IfStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.ifEval, args: [
            "condition_ast": stmt.condition,
            "body": stmt.body,
            "elif_clauses": stmt.elifClauses,
            "else_body": stmt.elseBody,
        ], line: stmt.line)
    }

    private func compileWhile(_ stmt: WhileLoop) throws {
        try checkSpeakerContext(stmt)

        // Axiom 9: No Infinite Loops
        guard stmt.maxIterations != nil else {
            throw LogicaError.axiomViolation(
                axiom: 9, name: "No Infinite Loops",
                message: "every loop must have a 'max N' bound. Use: while condition, max 1000 { ... }",
                line: stmt.line
            )
        }

        emit(.loopStart, args: [
            "condition_ast": stmt.condition,
            "body": stmt.body,
            "max_ast": stmt.maxIterations as Any,
        ], line: stmt.line)
    }

    private func compileFn(_ stmt: FnDecl) throws {
        try checkSpeakerContext(stmt)
        let fnKey = "\(currentSpeaker!).\(stmt.name)"
        declaredFunctions[fnKey] = stmt.params

        emit(.fnDefine, args: [
            "name": stmt.name,
            "params": stmt.params,
            "body": stmt.body,
        ], line: stmt.line)
    }

    private func compileReturn(_ stmt: ReturnStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.returnOp, args: ["value_ast": stmt.value as Any], line: stmt.line)
    }

    private func compileRequest(_ stmt: RequestStatement) throws {
        try checkSpeakerContext(stmt)

        guard declaredSpeakers.contains(stmt.target) else {
            throw LogicaError.axiomViolation(
                axiom: 1, name: "Speaker Requirement",
                message: "request target '\(stmt.target)' is not a declared speaker.",
                line: stmt.line
            )
        }

        emit(.request, args: [
            "target": stmt.target,
            "action_ast": stmt.action,
            "data_ast": stmt.data as Any,
        ], line: stmt.line)
    }

    private func compileRespond(_ stmt: RespondStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.respond, args: ["accept": stmt.accept], line: stmt.line)
    }

    private func compileInspect(_ stmt: InspectStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.inspect, args: ["target_ast": stmt.target], line: stmt.line)
    }

    private func compileHistory(_ stmt: HistoryStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.historyOp, args: ["target_ast": stmt.target], line: stmt.line)
    }

    private func compileLedgerStmt(_ stmt: LedgerStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.ledgerRead, args: ["count_ast": stmt.count as Any], line: stmt.line)
    }

    private func compileVerify(_ stmt: VerifyStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.ledgerVerify, line: stmt.line)
    }

    private func compileSeal(_ stmt: SealStatement) throws {
        try checkSpeakerContext(stmt)
        let sealedKey = "\(currentSpeaker!).\(stmt.target)"
        sealedVars.insert(sealedKey)
        emit(.seal, args: ["name": stmt.target], line: stmt.line)
    }

    private func compileFail(_ stmt: FailStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.fail, args: ["reason_ast": stmt.reason as Any], line: stmt.line)
    }

    private func compileExprStatement(_ stmt: ExpressionStatement) throws {
        try checkSpeakerContext(stmt)
        emit(.evalExpr, args: ["expr_ast": stmt.expression], line: stmt.line)
    }

    // MARK: - Block Axiom Checking

    private func checkBlockAxioms(_ stmts: [ASTNode]) throws {
        for stmt in stmts {
            if let letStmt = stmt as? LetStatement {
                try checkSpeakerContext(letStmt)
                let name = letStmt.name
                if name.contains(".") {
                    let parts = name.split(separator: ".").map(String.init)
                    for part in parts {
                        if declaredSpeakers.contains(part) && part != currentSpeaker {
                            throw LogicaError.axiomViolation(
                                axiom: 8, name: "Write Ownership",
                                message: "speaker '\(currentSpeaker!)' cannot write to '\(part)' variables.",
                                line: letStmt.line
                            )
                        }
                    }
                }
            } else if let whileStmt = stmt as? WhileLoop, whileStmt.maxIterations == nil {
                throw LogicaError.axiomViolation(
                    axiom: 9, name: "No Infinite Loops",
                    message: "every loop must have a 'max N' bound.",
                    line: whileStmt.line
                )
            } else if let whenStmt = stmt as? WhenBlock {
                try checkBlockAxioms(whenStmt.body)
                try checkBlockAxioms(whenStmt.otherwiseBody)
                try checkBlockAxioms(whenStmt.brokenBody)
            } else if let ifStmt = stmt as? IfStatement {
                try checkBlockAxioms(ifStmt.body)
                for clause in ifStmt.elifClauses {
                    try checkBlockAxioms(clause.body)
                }
                try checkBlockAxioms(ifStmt.elseBody)
            } else if let reqStmt = stmt as? RequestStatement {
                if !declaredSpeakers.contains(reqStmt.target) {
                    throw LogicaError.axiomViolation(
                        axiom: 1, name: "Speaker Requirement",
                        message: "request target '\(reqStmt.target)' is not a declared speaker.",
                        line: reqStmt.line
                    )
                }
            }
        }
    }

    // MARK: - Axiom Enforcement

    private func checkSpeakerContext(_ stmt: ASTNode) throws {
        guard currentSpeaker != nil else {
            throw LogicaError.axiomViolation(
                axiom: 1, name: "Speaker Requirement",
                message: "code requires a speaker context. Wrap code in: as SpeakerName { ... }",
                line: stmt.line
            )
        }
    }

    // MARK: - Helpers

    private func emit(_ opType: OpType, args: [String: Any] = [:], line: Int = 0) {
        operations.append(Operation(op: opType, speaker: currentSpeaker, args: args, line: line))
    }
}
