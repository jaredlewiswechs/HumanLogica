// Mary.swift — The Kernel
// She enforces Human Logic. 12 invariants. 10 guarantees. One job: be correct.
// Every operation has a speaker. Every state change has a receipt.

import Foundation

public class Mary {
    public let registry: SpeakerRegistry
    public let memory: Memory
    public let ledger: Ledger
    public let bus: RequestBus
    public let evaluator: Evaluator

    private var expressions: [Int: HLExpression] = [:]
    private var nextExprId: Int = 0
    private var booted = false
    public private(set) var root: Speaker?

    public init() {
        registry = SpeakerRegistry()
        memory = Memory()
        ledger = Ledger()
        bus = RequestBus()
        evaluator = Evaluator(registry: registry, memory: memory, ledger: ledger, bus: bus)
        boot()
    }

    // MARK: - Boot

    private func boot() {
        guard !booted else { return }
        root = registry.create(name: "root")
        memory.createPartition(speakerId: root!.id)
        ledger.append(
            speakerId: root!.id,
            operation: "boot",
            action: "mary_initialized",
            status: .active
        )
        booted = true
    }

    // MARK: - Speaker Management

    /// Create a new speaker. Caller must be alive.
    @discardableResult
    public func createSpeaker(callerId: Int, name: String) -> Speaker? {
        guard registry.authenticate(callerId) else {
            ledger.append(
                speakerId: callerId,
                operation: "create_speaker",
                action: "create:\(name)",
                status: .broken,
                breakReason: "caller_not_authenticated"
            )
            return nil
        }
        let speaker = registry.create(name: name, creatorId: callerId)
        memory.createPartition(speakerId: speaker.id)
        ledger.append(
            speakerId: callerId,
            operation: "create_speaker",
            action: "create:\(name)",
            status: .active,
            stateAfter: "new_speaker_id:\(speaker.id),name:\(name)"
        )
        return speaker
    }

    /// Suspend a speaker. Only root can do this.
    @discardableResult
    public func suspendSpeaker(callerId: Int, targetId: Int) -> Bool {
        guard callerId == 0 else {
            ledger.append(
                speakerId: callerId,
                operation: "suspend_speaker",
                action: "suspend:\(targetId)",
                status: .broken,
                breakReason: "not_root"
            )
            return false
        }
        let success = registry.suspend(speakerId: targetId)
        ledger.append(
            speakerId: callerId,
            operation: "suspend_speaker",
            action: "suspend:\(targetId)",
            status: success ? .active : .broken,
            breakReason: success ? nil : "speaker_not_found"
        )
        return success
    }

    /// List all speakers.
    public func listSpeakers(callerId: Int) -> [Speaker] {
        guard registry.authenticate(callerId) else { return [] }
        return registry.listAll()
    }

    // MARK: - Memory Operations

    /// Read any speaker's variable.
    public func read(callerId: Int, ownerId: Int, varName: String) -> Any? {
        guard registry.authenticate(callerId) else {
            ledger.append(
                speakerId: callerId,
                operation: "read",
                action: "read:\(ownerId).\(varName)",
                status: .broken,
                breakReason: "caller_not_authenticated"
            )
            return nil
        }
        let value = memory.read(ownerId: ownerId, varName: varName)
        ledger.append(
            speakerId: callerId,
            operation: "read",
            action: "read:\(ownerId).\(varName)",
            status: .active,
            stateAfter: "value:\(String(describing: value))"
        )
        return value
    }

    /// Write to caller's OWN variables only.
    /// Axiom 8: write(s1, s2.v, value) is undefined when s1 != s2.
    @discardableResult
    public func write(callerId: Int, varName: String, value: Any) -> Bool {
        guard registry.authenticate(callerId) else {
            ledger.append(
                speakerId: callerId,
                operation: "write",
                action: "write:\(varName)",
                status: .broken,
                breakReason: "caller_not_authenticated"
            )
            return false
        }
        let (success, oldValue) = memory.write(callerId: callerId, varName: varName, value: value)
        ledger.append(
            speakerId: callerId,
            operation: "write",
            action: "write:\(varName)",
            status: success ? .active : .broken,
            stateBefore: "var:\(varName),old_value:\(String(describing: oldValue))",
            stateAfter: "var:\(varName),new_value:\(String(describing: value))",
            breakReason: success ? nil : "write_failed"
        )
        return success
    }

    /// Attempt to write to ANOTHER speaker's variables. Always fails (Axiom 8).
    @discardableResult
    public func writeTo(callerId: Int, targetId: Int, varName: String, value: Any) -> Bool {
        if callerId != targetId {
            ledger.append(
                speakerId: callerId,
                operation: "write_violation",
                action: "write:\(targetId).\(varName)",
                status: .broken,
                breakReason: "write_ownership_violation"
            )
            return false
        }
        return write(callerId: callerId, varName: varName, value: value)
    }

    /// List variables in a speaker's partition.
    public func listVars(callerId: Int, ownerId: Int) -> [String] {
        guard registry.authenticate(callerId) else { return [] }
        return memory.listVars(ownerId: ownerId)
    }

    // MARK: - Expression Management

    /// Submit an expression for evaluation.
    @discardableResult
    public func submit(speakerId: Int, condition: (() -> Bool)? = nil,
                       conditionLabel: String = "⊤", action: String = "",
                       actionFn: (() -> Bool)? = nil, isRefusal: Bool = false,
                       scopeUntil: Date? = nil) -> HLExpression? {
        guard registry.authenticate(speakerId) else {
            ledger.append(
                speakerId: speakerId,
                operation: "submit",
                action: action,
                status: .broken,
                breakReason: "speaker_not_authenticated"
            )
            return nil
        }

        let expr = HLExpression(
            expressionId: nextExprId,
            speakerId: speakerId,
            condition: condition,
            conditionLabel: conditionLabel,
            action: action,
            actionFn: actionFn,
            isRefusal: isRefusal,
            scopeUntil: scopeUntil
        )
        nextExprId += 1

        // Check for supersession
        for (_, existing) in expressions {
            if existing.speakerId == speakerId &&
               existing.action == action &&
               existing.conditionLabel == conditionLabel &&
               existing.version == .current {
                existing.version = .superseded
                ledger.append(
                    speakerId: speakerId,
                    operation: "supersede",
                    action: "supersede:expr_\(existing.expressionId)",
                    status: .active,
                    stateBefore: "old_expr_id:\(existing.expressionId)",
                    stateAfter: "new_expr_id:\(expr.expressionId)"
                )
            }
        }

        expressions[expr.expressionId] = expr
        evaluator.evaluate(expr)
        return expr
    }

    /// Submit a looping expression.
    public func submitLoop(speakerId: Int, condition: (() -> Bool)? = nil,
                           conditionLabel: String = "⊤", action: String = "",
                           actionFn: (() -> Bool)? = nil,
                           loopCondition: (() -> Bool)? = nil,
                           loopMax: Int? = nil) -> (HLExpression, Int)? {
        guard registry.authenticate(speakerId) else { return nil }

        let expr = HLExpression(
            expressionId: nextExprId,
            speakerId: speakerId,
            condition: condition,
            conditionLabel: conditionLabel,
            action: action,
            actionFn: actionFn,
            loopCondition: loopCondition,
            loopMax: loopMax
        )
        nextExprId += 1
        expressions[expr.expressionId] = expr

        let (_, count) = evaluator.evaluateLoop(expr)
        return (expr, count)
    }

    /// Get an expression by ID.
    public func getExpression(exprId: Int) -> HLExpression? {
        expressions[exprId]
    }

    /// Get the status of an expression.
    public func expressionStatus(callerId: Int, exprId: Int) -> Status? {
        guard registry.authenticate(callerId) else { return nil }
        return expressions[exprId]?.status
    }

    // MARK: - Communication

    /// Send a request to another speaker.
    @discardableResult
    public func request(callerId: Int, targetId: Int, action: String,
                        data: Any? = nil, timeout: TimeInterval? = nil) -> Request? {
        guard registry.authenticate(callerId) else {
            ledger.append(
                speakerId: callerId,
                operation: "request",
                action: "request:\(targetId):\(action)",
                status: .broken,
                breakReason: "caller_not_authenticated"
            )
            return nil
        }
        guard registry.authenticate(targetId) else {
            ledger.append(
                speakerId: callerId,
                operation: "request",
                action: "request:\(targetId):\(action)",
                status: .broken,
                breakReason: "target_not_found"
            )
            return nil
        }

        let expiresAt = timeout.map { Date().addingTimeInterval($0) }
        let req = bus.createRequest(fromSpeaker: callerId, toSpeaker: targetId,
                                     action: action, data: data, expiresAt: expiresAt)
        ledger.append(
            speakerId: callerId,
            operation: "request",
            action: "request:\(targetId):\(action)",
            status: .active,
            stateAfter: "request_id:\(req.requestId)"
        )
        return req
    }

    /// Respond to a request. Only the target speaker can respond.
    @discardableResult
    public func respond(callerId: Int, requestId: Int, accept: Bool,
                        responseData: Any? = nil) -> Bool {
        guard let req = bus.getRequest(requestId: requestId) else {
            ledger.append(
                speakerId: callerId,
                operation: "respond",
                action: "respond:\(requestId)",
                status: .broken,
                breakReason: "request_not_found"
            )
            return false
        }
        guard req.toSpeaker == callerId else {
            ledger.append(
                speakerId: callerId,
                operation: "respond",
                action: "respond:\(requestId)",
                status: .broken,
                breakReason: "not_target_speaker"
            )
            return false
        }

        let result = bus.respond(requestId: requestId, responderId: callerId,
                                  accept: accept, responseData: responseData)
        ledger.append(
            speakerId: callerId,
            operation: "respond",
            action: "respond:\(requestId):\(accept ? "accept" : "refuse")",
            status: .active,
            stateAfter: "request_id:\(requestId),accepted:\(accept)"
        )
        return result != nil
    }

    /// Get pending requests for a speaker.
    public func pendingRequests(callerId: Int) -> [Request] {
        guard registry.authenticate(callerId) else { return [] }
        return bus.getPendingFor(speakerId: callerId)
    }

    // MARK: - Ledger Access

    public func ledgerRead(callerId: Int, fromId: Int = 0, toId: Int? = nil) -> [LedgerEntry] {
        guard registry.authenticate(callerId) else { return [] }
        return ledger.read(fromId: fromId, toId: toId)
    }

    public func ledgerSearch(callerId: Int, speakerId: Int? = nil,
                             operation: String? = nil, action: String? = nil,
                             fromTime: Date? = nil, toTime: Date? = nil) -> [LedgerEntry] {
        guard registry.authenticate(callerId) else { return [] }
        return ledger.search(speakerId: speakerId, operation: operation,
                             action: action, fromTime: fromTime, toTime: toTime)
    }

    public func ledgerCount(callerId: Int) -> Int {
        guard registry.authenticate(callerId) else { return 0 }
        return ledger.count
    }

    public func ledgerVerify() -> Bool {
        ledger.verifyIntegrity()
    }

    // MARK: - Inspection

    public func inspectSpeaker(callerId: Int, targetId: Int) -> [String: Any]? {
        guard registry.authenticate(callerId) else { return nil }
        guard let speaker = registry.get(speakerId: targetId) else { return nil }
        let exprs = expressions.values
            .filter { $0.speakerId == targetId }
            .map { expr -> [String: Any] in
                [
                    "id": expr.expressionId,
                    "action": expr.action,
                    "status": expr.status?.rawValue ?? "nil",
                    "version": expr.version.rawValue
                ]
            }
        return [
            "speaker": [
                "id": speaker.id,
                "name": speaker.name,
                "status": speaker.status.rawValue,
                "created_at": speaker.createdAt.timeIntervalSince1970
            ],
            "variables": memory.listVars(ownerId: targetId),
            "pending_requests": bus.getPendingFor(speakerId: targetId).count,
            "expressions": exprs
        ]
    }

    public func inspectVariable(callerId: Int, ownerId: Int, varName: String) -> [String: Any]? {
        guard registry.authenticate(callerId) else { return nil }
        let current = memory.read(ownerId: ownerId, varName: varName)
        let history = ledger.search(speakerId: ownerId, action: "write:\(varName)")
        return [
            "owner": ownerId,
            "variable": varName,
            "current_value": current as Any,
            "history": history.map { e in
                [
                    "entry_id": e.entryId,
                    "before": e.stateBefore as Any,
                    "after": e.stateAfter as Any,
                    "timestamp": e.timestamp.timeIntervalSince1970
                ]
            }
        ]
    }

    // MARK: - State

    public func state() -> [String: Any] {
        [
            "speakers": registry.listAll().count,
            "ledger_entries": ledger.count,
            "ledger_integrity": ledger.verifyIntegrity(),
            "expressions": expressions.count,
            "pending_requests": bus.pendingCount
        ]
    }
}
