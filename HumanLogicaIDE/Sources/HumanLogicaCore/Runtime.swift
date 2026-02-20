// Runtime.swift — Where Programs Execute
// The runtime takes compiled operations and executes them through Mary.
// Every variable write goes through Mary. Every operation is logged.

import Foundation

/// Runtime environment for a Logica program.
public class Environment {
    public let mary = Mary()
    public var speakerIds: [String: Int] = [:]
    public var currentSpeaker: String? = nil
    public var currentSpeakerId: Int? = nil
    public var functions: [String: [String: Any]] = [:]
    public var localScopes: [[String: Any]] = []
    public var sealed: Set<String> = []
    public var output: [String] = []
    public var returnValue: Any? = nil
    public var returning = false

    public init() {}
}

/// Executes a compiled Logica program through Mary.
public class Runtime {
    public let env = Environment()
    public var quiet: Bool

    public init(quiet: Bool = false) {
        self.quiet = quiet
    }

    public func execute(_ compiled: CompiledProgram) throws {
        for op in compiled.operations {
            if env.returning { break }
            try executeOp(op)
        }
    }

    // MARK: - Operation Dispatch

    private func executeOp(_ op: Operation) throws {
        switch op.op {
        case .createSpeaker: opCreateSpeaker(op)
        case .setSpeaker: opSetSpeaker(op)
        case .writeVar: try opWriteVar(op)
        case .speakOutput: try opSpeakOutput(op)
        case .whenEval: try opWhenEval(op)
        case .ifEval: try opIfEval(op)
        case .loopStart: try opLoop(op)
        case .fnDefine: opFnDefine(op)
        case .returnOp: try opReturn(op)
        case .request: try opRequest(op)
        case .respond: opRespond(op)
        case .inspect: try opInspect(op)
        case .historyOp: try opHistory(op)
        case .ledgerRead: try opLedgerRead(op)
        case .ledgerVerify: opLedgerVerify(op)
        case .seal: opSeal(op)
        case .fail: try opFail(op)
        case .pass: break
        case .createWorld: opCreateWorld(op)
        case .evalExpr: try opEvalExpr(op)
        default: break
        }
    }

    // MARK: - Operation Handlers

    private func opCreateSpeaker(_ op: Operation) {
        guard let name = op.args["name"] as? String else { return }
        if let speaker = env.mary.createSpeaker(callerId: 0, name: name) {
            env.speakerIds[name] = speaker.id
        }
    }

    private func opSetSpeaker(_ op: Operation) {
        guard let name = op.args["name"] as? String else { return }
        env.currentSpeaker = name
        env.currentSpeakerId = env.speakerIds[name]
    }

    private func opWriteVar(_ op: Operation) throws {
        guard let name = op.args["name"] as? String,
              let valueAst = op.args["value_ast"] as? ASTNode else { return }
        let value = try evalExpr(valueAst)

        guard let sid = env.currentSpeakerId else {
            throw LogicaError.runtimeError(message: "no active speaker", speaker: env.currentSpeaker)
        }

        let sealKey = "\(env.currentSpeaker ?? "").\(name)"
        if env.sealed.contains(sealKey) {
            throw LogicaError.runtimeError(
                message: "variable '\(name)' is sealed and cannot be modified",
                speaker: env.currentSpeaker
            )
        }

        // Handle indexed assignment: let arr[idx] = value
        if let indexAst = op.args["index_ast"] as? ASTNode {
            let idx = try evalExpr(indexAst)
            let existing = resolveIdentifier(name)
            if var arr = existing as? [Any], let i = idx as? Int, i >= 0 && i < arr.count {
                arr[i] = value as Any
                if !env.localScopes.isEmpty {
                    env.localScopes[env.localScopes.count - 1][name] = arr
                    env.mary.write(callerId: sid, varName: "local.\(name)", value: arr as Any)
                } else {
                    env.mary.write(callerId: sid, varName: name, value: arr as Any)
                }
            } else if var dict = existing as? [String: Any], let k = idx as? String {
                dict[k] = value as Any
                if !env.localScopes.isEmpty {
                    env.localScopes[env.localScopes.count - 1][name] = dict
                    env.mary.write(callerId: sid, varName: "local.\(name)", value: dict as Any)
                } else {
                    env.mary.write(callerId: sid, varName: name, value: dict as Any)
                }
            }
            return
        }

        if !env.localScopes.isEmpty {
            env.localScopes[env.localScopes.count - 1][name] = value
            env.mary.write(callerId: sid, varName: "local.\(name)", value: value as Any)
        } else {
            let success = env.mary.write(callerId: sid, varName: name, value: value as Any)
            if !success {
                throw LogicaError.runtimeError(
                    message: "write failed for variable '\(name)'",
                    speaker: env.currentSpeaker
                )
            }
        }
    }

    private func opSpeakOutput(_ op: Operation) throws {
        guard let valueAst = op.args["value_ast"] as? ASTNode else { return }
        let value = try evalExpr(valueAst)

        guard let sid = env.currentSpeakerId else { return }
        let speakerName = env.currentSpeaker ?? "unknown"

        env.mary.submit(
            speakerId: sid,
            conditionLabel: "speak",
            action: "speak:\(String(describing: value))",
            actionFn: { true }
        )

        let output = "  [\(speakerName)] \(String(describing: value))"
        env.output.append(output)
        if !quiet {
            print(output)
        }
    }

    private func opWhenEval(_ op: Operation) throws {
        guard let conditionAst = op.args["condition_ast"] as? ASTNode,
              let body = op.args["body"] as? [ASTNode],
              let otherwiseBody = op.args["otherwise_body"] as? [ASTNode],
              let brokenBody = op.args["broken_body"] as? [ASTNode] else { return }

        guard let sid = env.currentSpeakerId else { return }

        var conditionMet: Bool? = nil
        do {
            let result = try evalExpr(conditionAst)
            conditionMet = isTruthy(result)
        } catch {
            conditionMet = nil // broken
        }

        if conditionMet == true {
            do {
                for stmt in body {
                    try executeStatement(stmt)
                }
                env.mary.submit(speakerId: sid, conditionLabel: "when:active",
                               action: "when_block", actionFn: { true })
            } catch {
                env.mary.submit(speakerId: sid, conditionLabel: "when:broken",
                               action: "when_block", actionFn: { false })
                for stmt in brokenBody {
                    try executeStatement(stmt)
                }
            }
        } else if conditionMet == false {
            env.mary.submit(speakerId: sid, condition: { false },
                           conditionLabel: "when:inactive", action: "when_block")
            for stmt in otherwiseBody {
                try executeStatement(stmt)
            }
        } else {
            env.mary.submit(speakerId: sid, conditionLabel: "when:broken",
                           action: "when_block", actionFn: { false })
            for stmt in brokenBody {
                try executeStatement(stmt)
            }
        }
    }

    private func opIfEval(_ op: Operation) throws {
        guard let conditionAst = op.args["condition_ast"] as? ASTNode,
              let body = op.args["body"] as? [ASTNode] else { return }
        let elifClauses = op.args["elif_clauses"] as? [ElifClause] ?? []
        let elseBody = op.args["else_body"] as? [ASTNode] ?? []

        if isTruthy(try evalExpr(conditionAst)) {
            for stmt in body { try executeStatement(stmt) }
            return
        }

        for clause in elifClauses {
            if isTruthy(try evalExpr(clause.condition)) {
                for stmt in clause.body { try executeStatement(stmt) }
                return
            }
        }

        for stmt in elseBody { try executeStatement(stmt) }
    }

    private func opLoop(_ op: Operation) throws {
        guard let conditionAst = op.args["condition_ast"] as? ASTNode,
              let body = op.args["body"] as? [ASTNode] else { return }

        var maxIter = 10000
        if let maxAst = op.args["max_ast"] as? ASTNode {
            if let maxVal = try evalExpr(maxAst) as? Int {
                maxIter = maxVal
            }
        }

        guard let sid = env.currentSpeakerId else { return }
        var count = 0

        while count < maxIter {
            let condResult = try evalExpr(conditionAst)
            if !isTruthy(condResult) {
                env.mary.submit(speakerId: sid, condition: { false },
                               conditionLabel: "loop:terminated",
                               action: "loop:iterations=\(count)")
                return
            }

            for stmt in body {
                if env.returning { return }
                try executeStatement(stmt)
            }
            count += 1
        }

        env.mary.submit(speakerId: sid, conditionLabel: "loop:bound_exceeded",
                       action: "loop:max=\(maxIter)", actionFn: { false })
        throw LogicaError.runtimeError(
            message: "loop exceeded max \(maxIter) iterations",
            speaker: env.currentSpeaker
        )
    }

    private func opFnDefine(_ op: Operation) {
        guard let name = op.args["name"] as? String,
              let params = op.args["params"] as? [String],
              let body = op.args["body"] as? [ASTNode] else { return }

        let fnKey = "\(env.currentSpeaker ?? "").\(name)"
        env.functions[fnKey] = [
            "params": params,
            "body": body,
            "speaker": env.currentSpeaker as Any,
        ]
    }

    private func opReturn(_ op: Operation) throws {
        if let valueAst = op.args["value_ast"] as? ASTNode {
            env.returnValue = try evalExpr(valueAst)
        } else {
            env.returnValue = nil
        }
        env.returning = true
    }

    private func opRequest(_ op: Operation) throws {
        guard let targetName = op.args["target"] as? String,
              let actionAst = op.args["action_ast"] as? ASTNode else { return }

        let action = String(describing: try evalExpr(actionAst))
        guard let targetId = env.speakerIds[targetName] else {
            throw LogicaError.runtimeError(
                message: "target speaker '\(targetName)' not found",
                speaker: env.currentSpeaker
            )
        }
        guard let sid = env.currentSpeakerId else { return }

        env.mary.request(callerId: sid, targetId: targetId, action: action)

        if !quiet {
            let output = "  [\(env.currentSpeaker ?? "")] request -> \(targetName): \(action)"
            env.output.append(output)
            print(output)
        }
    }

    private func opRespond(_ op: Operation) {
        let accept = op.args["accept"] as? Bool ?? true
        guard let sid = env.currentSpeakerId else { return }

        let pending = env.mary.pendingRequests(callerId: sid)
        if let req = pending.first {
            env.mary.respond(callerId: sid, requestId: req.requestId, accept: accept)
            if !quiet {
                let action = accept ? "accepted" : "refused"
                let output = "  [\(env.currentSpeaker ?? "")] \(action) request #\(req.requestId)"
                env.output.append(output)
                print(output)
            }
        }
    }

    private func opInspect(_ op: Operation) throws {
        guard let targetAst = op.args["target_ast"] as? ASTNode,
              let sid = env.currentSpeakerId else { return }

        let target = evalInspectTarget(targetAst)

        if let name = target as? String, let targetId = env.speakerIds[name] {
            if let info = env.mary.inspectSpeaker(callerId: sid, targetId: targetId), !quiet {
                let speakerInfo = info["speaker"] as? [String: Any] ?? [:]
                let variables = info["variables"] as? [String] ?? []
                let expressions = info["expressions"] as? [[String: Any]] ?? []

                let output = [
                    "  --- inspect \(name) ---",
                    "  speaker: \(speakerInfo["name"] ?? "") (#\(speakerInfo["id"] ?? ""))",
                    "  status:  \(speakerInfo["status"] ?? "")",
                    "  vars:    \(variables)",
                    "  exprs:   \(expressions.count)",
                    "  ---"
                ]
                for line in output {
                    env.output.append(line)
                    print(line)
                }
            }
        } else if let pair = target as? (String, String) {
            let (speakerName, varName) = pair
            let ownerId = env.speakerIds[speakerName] ?? sid
            let value = env.mary.read(callerId: sid, ownerId: ownerId, varName: varName)
            if !quiet {
                let output = [
                    "  --- inspect \(speakerName).\(varName) ---",
                    "  value: \(String(describing: value))",
                    "  ---"
                ]
                for line in output {
                    env.output.append(line)
                    print(line)
                }
            }
        }
    }

    private func opHistory(_ op: Operation) throws {
        guard let targetAst = op.args["target_ast"] as? ASTNode,
              let sid = env.currentSpeakerId else { return }

        let target = evalInspectTarget(targetAst)

        if let pair = target as? (String, String) {
            let (speakerName, varName) = pair
            let ownerId = env.speakerIds[speakerName] ?? sid
            if let result = env.mary.inspectVariable(callerId: sid, ownerId: ownerId, varName: varName), !quiet {
                let history = result["history"] as? [[String: Any]] ?? []
                var lines = ["  --- history \(speakerName).\(varName) ---"]
                lines.append("  current: \(String(describing: result["current_value"]))")
                for h in history {
                    lines.append("    #\(h["entry_id"] ?? ""): \(h["before"] ?? "") -> \(h["after"] ?? "")")
                }
                lines.append("  ---")
                for line in lines {
                    env.output.append(line)
                    print(line)
                }
            }
        }
    }

    private func opLedgerRead(_ op: Operation) throws {
        guard let sid = env.currentSpeakerId else { return }

        let total = env.mary.ledgerCount(callerId: sid)
        var count = total
        if let countAst = op.args["count_ast"] as? ASTNode,
           let countVal = try evalExpr(countAst) as? Int {
            count = min(countVal, total)
        }

        let entries = env.mary.ledgerRead(callerId: sid, fromId: max(0, total - count), toId: total)
        if !quiet {
            var lines = ["  --- ledger (last \(count) of \(total)) ---"]
            for e in entries {
                let status = e.status?.rawValue ?? "-"
                let speakerName = speakerNameById(e.speakerId)
                lines.append("    #\(e.entryId) [\(status)] \(speakerName): \(e.action)")
            }
            lines.append("  ---")
            for line in lines {
                env.output.append(line)
                print(line)
            }
        }
    }

    private func opLedgerVerify(_ op: Operation) {
        let intact = env.mary.ledgerVerify()
        if !quiet {
            let line = intact ? "  ledger integrity: VALID" : "  ledger integrity: BROKEN"
            env.output.append(line)
            print(line)
        }
    }

    private func opSeal(_ op: Operation) {
        guard let name = op.args["name"] as? String,
              let sid = env.currentSpeakerId else { return }

        let sealKey = "\(env.currentSpeaker ?? "").\(name)"
        env.sealed.insert(sealKey)

        env.mary.submit(speakerId: sid, conditionLabel: "seal",
                       action: "seal:\(name)", actionFn: { true })

        if !quiet {
            let line = "  [\(env.currentSpeaker ?? "")] sealed: \(name)"
            env.output.append(line)
            print(line)
        }
    }

    private func opFail(_ op: Operation) throws {
        var reason = "explicit fail"
        if let reasonAst = op.args["reason_ast"] as? ASTNode {
            reason = String(describing: try evalExpr(reasonAst))
        }

        if let sid = env.currentSpeakerId {
            env.mary.submit(speakerId: sid, conditionLabel: "fail",
                           action: "fail:\(reason)", actionFn: { false })
        }
        throw LogicaError.runtimeError(message: reason, speaker: env.currentSpeaker)
    }

    private func opCreateWorld(_ op: Operation) {
        guard let name = op.args["name"] as? String else { return }
        if !quiet {
            let line = "  [\(env.currentSpeaker ?? "")] world created: \(name)"
            env.output.append(line)
            print(line)
        }
    }

    private func opEvalExpr(_ op: Operation) throws {
        guard let exprAst = op.args["expr_ast"] as? ASTNode else { return }
        _ = try evalExpr(exprAst)
    }

    // MARK: - Expression Evaluation

    public func evalExpr(_ node: ASTNode?) throws -> Any? {
        guard let node = node else { return nil }

        switch node {
        case let n as IntegerLiteral: return n.value
        case let n as FloatLiteral: return n.value
        case let n as StringLiteral: return n.value
        case let n as BooleanLiteral: return n.value
        case is NoneLiteral: return nil
        case let n as StatusLiteral: return n.value
        case let n as Identifier: return resolveIdentifier(n.name)
        case let n as MemberAccess: return try evalMemberAccess(n)
        case let n as BinaryOp: return try evalBinary(n)
        case let n as UnaryOp: return try evalUnary(n)
        case let n as FnCall: return try evalFnCall(n)
        case let n as ReadExpr: return try evalExpr(n.target)
        case let n as IndexAccess:
            let obj = try evalExpr(n.object)
            let idx = try evalExpr(n.index)
            if let arr = obj as? [Any], let i = idx as? Int { return arr[i] }
            if let dict = obj as? [String: Any], let k = idx as? String { return dict[k] }
            return nil
        default: return nil
        }
    }

    private func resolveIdentifier(_ name: String) -> Any? {
        for scope in env.localScopes.reversed() {
            if let val = scope[name] { return val }
        }
        if let sid = env.currentSpeakerId {
            if let val = env.mary.read(callerId: sid, ownerId: sid, varName: name) {
                return val
            }
        }
        if env.speakerIds[name] != nil { return name }
        return nil
    }

    private func evalMemberAccess(_ node: MemberAccess) throws -> Any? {
        if let ident = node.object as? Identifier, env.speakerIds[ident.name] != nil {
            let ownerId = env.speakerIds[ident.name]!
            let callerId = env.currentSpeakerId ?? 0
            return env.mary.read(callerId: callerId, ownerId: ownerId, varName: node.member)
        }
        let obj = try evalExpr(node.object)
        if let dict = obj as? [String: Any] { return dict[node.member] }
        return nil
    }

    private func evalBinary(_ node: BinaryOp) throws -> Any? {
        let left = try evalExpr(node.left)
        let right = try evalExpr(node.right)

        switch node.op {
        case "+":
            if let l = left as? Int, let r = right as? Int { return l + r }
            if let l = left as? Double, let r = right as? Double { return l + r }
            if let l = left as? String, let r = right as? String { return l + r }
            if let l = left as? Int, let r = right as? Double { return Double(l) + r }
            if let l = left as? Double, let r = right as? Int { return l + Double(r) }
            if let l = left, let r = right { return "\(l)\(r)" }
            return nil
        case "-":
            if let l = left as? Int, let r = right as? Int { return l - r }
            if let l = left as? Double, let r = right as? Double { return l - r }
            if let l = left as? Int, let r = right as? Double { return Double(l) - r }
            if let l = left as? Double, let r = right as? Int { return l - Double(r) }
            return nil
        case "*":
            if let l = left as? Int, let r = right as? Int { return l * r }
            if let l = left as? Double, let r = right as? Double { return l * r }
            if let l = left as? Int, let r = right as? Double { return Double(l) * r }
            if let l = left as? Double, let r = right as? Int { return l * Double(r) }
            return nil
        case "/":
            if let l = left as? Int, let r = right as? Int, r != 0 { return l / r }
            if let l = left as? Double, let r = right as? Double, r != 0 { return l / r }
            if let l = left as? Int, let r = right as? Double, r != 0 { return Double(l) / r }
            if let l = left as? Double, let r = right as? Int, r != 0 { return l / Double(r) }
            return nil
        case "%":
            if let l = left as? Int, let r = right as? Int, r != 0 { return l % r }
            return nil
        case "==": return isEqual(left, right)
        case "!=": return !isEqual(left, right)
        case "<":
            if let l = left as? Int, let r = right as? Int { return l < r }
            if let l = left as? Double, let r = right as? Double { return l < r }
            if let l = left as? Int, let r = right as? Double { return Double(l) < r }
            if let l = left as? Double, let r = right as? Int { return l < Double(r) }
            return false
        case ">":
            if let l = left as? Int, let r = right as? Int { return l > r }
            if let l = left as? Double, let r = right as? Double { return l > r }
            if let l = left as? Int, let r = right as? Double { return Double(l) > r }
            if let l = left as? Double, let r = right as? Int { return l > Double(r) }
            return false
        case "<=":
            if let l = left as? Int, let r = right as? Int { return l <= r }
            if let l = left as? Double, let r = right as? Double { return l <= r }
            if let l = left as? Int, let r = right as? Double { return Double(l) <= r }
            if let l = left as? Double, let r = right as? Int { return l <= Double(r) }
            return false
        case ">=":
            if let l = left as? Int, let r = right as? Int { return l >= r }
            if let l = left as? Double, let r = right as? Double { return l >= r }
            if let l = left as? Int, let r = right as? Double { return Double(l) >= r }
            if let l = left as? Double, let r = right as? Int { return l >= Double(r) }
            return false
        case "and": return isTruthy(left) && isTruthy(right)
        case "or": return isTruthy(left) || isTruthy(right)
        default: return nil
        }
    }

    private func evalUnary(_ node: UnaryOp) throws -> Any? {
        let operand = try evalExpr(node.operand)
        switch node.op {
        case "-":
            if let v = operand as? Int { return -v }
            if let v = operand as? Double { return -v }
            return nil
        case "not": return !isTruthy(operand)
        default: return nil
        }
    }

    private func evalFnCall(_ node: FnCall) throws -> Any? {
        let fnName: String
        if let ident = node.function as? Identifier {
            fnName = ident.name
        } else if let member = node.function as? MemberAccess,
                  let obj = try evalExpr(member.object) as? String {
            fnName = "\(obj).\(member.member)"
        } else {
            return nil
        }

        let fnKey = "\(env.currentSpeaker ?? "").\(fnName)"
        var fnDef = env.functions[fnKey]

        if fnDef == nil {
            // Search other speakers' functions, but prefer deterministic order
            // by sorting keys to satisfy Axiom 6 (deterministic evaluation)
            for key in env.functions.keys.sorted() {
                if key.hasSuffix(".\(fnName)") {
                    fnDef = env.functions[key]
                    break
                }
            }
        }

        guard let fn = fnDef,
              let params = fn["params"] as? [String],
              let body = fn["body"] as? [ASTNode] else { return nil }

        let argValues = try node.args.map { try evalExpr($0) }

        var localScope: [String: Any] = [:]
        for (param, argVal) in zip(params, argValues) {
            localScope[param] = argVal as Any
        }

        env.localScopes.append(localScope)
        env.returning = false
        env.returnValue = nil

        for stmt in body {
            if env.returning { break }
            try executeStatement(stmt)
        }

        env.localScopes.removeLast()
        let result = env.returnValue
        env.returning = false
        env.returnValue = nil

        return result
    }

    // MARK: - Statement Execution (for blocks)

    public func executeStatement(_ stmt: ASTNode) throws {
        if env.returning { return }

        switch stmt {
        case let s as LetStatement:
            var args: [String: Any] = ["name": s.name, "value_ast": s.value]
            if let idx = s.index { args["index_ast"] = idx }
            try opWriteVar(Operation(op: .writeVar, speaker: env.currentSpeaker,
                                     args: args, line: s.line))
        case let s as SpeakStatement:
            try opSpeakOutput(Operation(op: .speakOutput, speaker: env.currentSpeaker,
                                        args: ["value_ast": s.value], line: s.line))
        case let s as WhenBlock:
            try execWhen(s)
        case let s as IfStatement:
            try execIf(s)
        case let s as WhileLoop:
            try execWhile(s)
        case let s as ReturnStatement:
            try opReturn(Operation(op: .returnOp, speaker: env.currentSpeaker,
                                   args: ["value_ast": s.value as Any], line: s.line))
        case let s as ExpressionStatement:
            _ = try evalExpr(s.expression)
        case let s as RequestStatement:
            try opRequest(Operation(op: .request, speaker: env.currentSpeaker,
                                    args: ["target": s.target, "action_ast": s.action,
                                           "data_ast": s.data as Any], line: s.line))
        case let s as RespondStatement:
            opRespond(Operation(op: .respond, speaker: env.currentSpeaker,
                               args: ["accept": s.accept], line: s.line))
        case let s as InspectStatement:
            try opInspect(Operation(op: .inspect, speaker: env.currentSpeaker,
                                    args: ["target_ast": s.target]))
        case let s as HistoryStatement:
            try opHistory(Operation(op: .historyOp, speaker: env.currentSpeaker,
                                    args: ["target_ast": s.target]))
        case let s as LedgerStatement:
            try opLedgerRead(Operation(op: .ledgerRead, speaker: env.currentSpeaker,
                                       args: ["count_ast": s.count as Any]))
        case is VerifyStatement:
            opLedgerVerify(Operation(op: .ledgerVerify, speaker: env.currentSpeaker))
        case let s as SealStatement:
            opSeal(Operation(op: .seal, speaker: env.currentSpeaker,
                            args: ["name": s.target], line: s.line))
        case let s as FnDecl:
            opFnDefine(Operation(op: .fnDefine, speaker: env.currentSpeaker,
                                args: ["name": s.name, "params": s.params, "body": s.body], line: s.line))
        case is PassStatement: break
        case let s as FailStatement:
            try opFail(Operation(op: .fail, speaker: env.currentSpeaker,
                                args: ["reason_ast": s.reason as Any], line: s.line))
        default: break
        }
    }

    private func execWhen(_ stmt: WhenBlock) throws {
        var conditionMet: Bool? = nil
        do {
            conditionMet = isTruthy(try evalExpr(stmt.condition))
        } catch {
            conditionMet = nil
        }

        if conditionMet == true {
            do {
                for s in stmt.body {
                    if env.returning { return }
                    try executeStatement(s)
                }
            } catch {
                for s in stmt.brokenBody {
                    if env.returning { return }
                    try executeStatement(s)
                }
            }
        } else if conditionMet == false {
            for s in stmt.otherwiseBody {
                if env.returning { return }
                try executeStatement(s)
            }
        } else {
            for s in stmt.brokenBody {
                if env.returning { return }
                try executeStatement(s)
            }
        }
    }

    private func execIf(_ stmt: IfStatement) throws {
        if isTruthy(try evalExpr(stmt.condition)) {
            for s in stmt.body {
                if env.returning { return }
                try executeStatement(s)
            }
            return
        }
        for clause in stmt.elifClauses {
            if isTruthy(try evalExpr(clause.condition)) {
                for s in clause.body {
                    if env.returning { return }
                    try executeStatement(s)
                }
                return
            }
        }
        for s in stmt.elseBody {
            if env.returning { return }
            try executeStatement(s)
        }
    }

    private func execWhile(_ stmt: WhileLoop) throws {
        var maxIter = 10000
        if let maxNode = stmt.maxIterations, let maxVal = try evalExpr(maxNode) as? Int {
            maxIter = maxVal
        }

        var count = 0
        while count < maxIter {
            if !isTruthy(try evalExpr(stmt.condition)) { return }
            for s in stmt.body {
                if env.returning { return }
                try executeStatement(s)
            }
            count += 1
        }

        throw LogicaError.runtimeError(
            message: "loop exceeded max \(maxIter) iterations",
            speaker: env.currentSpeaker
        )
    }

    // MARK: - Helpers

    private func evalInspectTarget(_ node: ASTNode) -> Any {
        if let ident = node as? Identifier { return ident.name }
        if let member = node as? MemberAccess, let obj = member.object as? Identifier {
            return (obj.name, member.member)
        }
        return String(describing: (try? evalExpr(node)) ?? "unknown")
    }

    private func speakerNameById(_ id: Int) -> String {
        for (name, sid) in env.speakerIds {
            if sid == id { return name }
        }
        return env.mary.registry.get(speakerId: id)?.name ?? "speaker_\(id)"
    }

    func isTruthy(_ value: Any?) -> Bool {
        guard let value = value else { return false }
        if let b = value as? Bool { return b }
        if let i = value as? Int { return i != 0 }
        if let d = value as? Double { return d != 0 }
        if let s = value as? String { return !s.isEmpty }
        return true
    }

    private func isEqual(_ a: Any?, _ b: Any?) -> Bool {
        if a == nil && b == nil { return true }
        guard let a = a, let b = b else { return false }
        if let la = a as? Int, let lb = b as? Int { return la == lb }
        if let la = a as? Double, let lb = b as? Double { return la == lb }
        if let la = a as? Int, let lb = b as? Double { return Double(la) == lb }
        if let la = a as? Double, let lb = b as? Int { return la == Double(lb) }
        if let la = a as? String, let lb = b as? String { return la == lb }
        if let la = a as? Bool, let lb = b as? Bool { return la == lb }
        return false
    }
}

// MARK: - Public Pipeline

/// Run a Logica program from source code. Returns (output_lines, error_or_nil).
public func runLogicaProgram(source: String, quiet: Bool = true) -> (output: [String], error: LogicaError?) {
    do {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let compiler = Compiler()
        let compiled = try compiler.compile(ast)
        let runtime = Runtime(quiet: quiet)
        try runtime.execute(compiled)
        return (runtime.env.output, nil)
    } catch let error as LogicaError {
        return ([], error)
    } catch {
        return ([], LogicaError.runtimeError(message: error.localizedDescription, speaker: nil))
    }
}

/// Check a Logica program for axiom violations without executing.
public func checkLogicaProgram(source: String) -> LogicaError? {
    do {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let compiler = Compiler()
        _ = try compiler.compile(ast)
        return nil
    } catch let error as LogicaError {
        return error
    } catch {
        return LogicaError.runtimeError(message: error.localizedDescription, speaker: nil)
    }
}

/// Tokenize Logica source code. Returns (tokens, error_or_nil).
public func tokenizeLogica(source: String) -> (tokens: [Token], error: LogicaError?) {
    do {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        return (tokens, nil)
    } catch let error as LogicaError {
        return ([], error)
    } catch {
        return ([], LogicaError.runtimeError(message: error.localizedDescription, speaker: nil))
    }
}
