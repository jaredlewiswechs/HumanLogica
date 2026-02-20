// Evaluator.swift — The Core Evaluation Engine
// One expression in, one status out. Deterministic.

import Foundation

public class Evaluator {
    public let registry: SpeakerRegistry
    public let memory: Memory
    public let ledger: Ledger
    public let bus: RequestBus

    public init(registry: SpeakerRegistry, memory: Memory, ledger: Ledger, bus: RequestBus) {
        self.registry = registry
        self.memory = memory
        self.ledger = ledger
        self.bus = bus
    }

    /// Evaluate a single expression. The heartbeat of the system.
    /// Step 1: Authenticate speaker
    /// Step 2: Check condition
    /// Step 3: Execute action
    /// Step 4: Log to ledger
    @discardableResult
    public func evaluate(_ expr: HLExpression) -> Status {
        // Step 1: Authenticate
        guard registry.authenticate(expr.speakerId) else {
            ledger.append(
                speakerId: expr.speakerId,
                operation: "evaluate",
                action: expr.action,
                condition: expr.conditionLabel,
                status: .broken,
                breakReason: "speaker_not_found_or_suspended"
            )
            return .broken
        }

        // Check version and scope
        guard expr.version == .current else {
            return .inactive
        }

        if let scopeUntil = expr.scopeUntil, Date() > scopeUntil {
            expr.version = .expired
            ledger.append(
                speakerId: expr.speakerId,
                operation: "expire",
                action: expr.action,
                condition: expr.conditionLabel
            )
            return .inactive
        }

        // Step 2: Check condition
        var conditionMet = true
        if let condition = expr.condition {
            conditionMet = condition()
        }

        if !conditionMet {
            expr.status = .inactive
            ledger.append(
                speakerId: expr.speakerId,
                operation: "evaluate",
                action: expr.action,
                condition: expr.conditionLabel,
                conditionResult: false,
                status: .inactive
            )
            return .inactive
        }

        // Step 3: Execute action
        if let actionFn = expr.actionFn {
            let actionFulfilled: Bool
            actionFulfilled = actionFn()

            let finalFulfilled = expr.isRefusal ? !actionFulfilled : actionFulfilled

            // Step 4: Assign status and log
            if finalFulfilled {
                expr.status = .active
                ledger.append(
                    speakerId: expr.speakerId,
                    operation: "evaluate",
                    action: expr.action,
                    condition: expr.conditionLabel,
                    conditionResult: true,
                    status: .active
                )
                return .active
            } else {
                expr.status = .broken
                ledger.append(
                    speakerId: expr.speakerId,
                    operation: "evaluate",
                    action: expr.action,
                    condition: expr.conditionLabel,
                    conditionResult: true,
                    status: .broken,
                    breakReason: "action_not_fulfilled"
                )
                return .broken
            }
        } else {
            // No action function — condition met, action trivially fulfilled
            let fulfilled = !expr.isRefusal
            if fulfilled {
                expr.status = .active
                ledger.append(
                    speakerId: expr.speakerId,
                    operation: "evaluate",
                    action: expr.action,
                    condition: expr.conditionLabel,
                    conditionResult: true,
                    status: .active
                )
                return .active
            } else {
                expr.status = .broken
                ledger.append(
                    speakerId: expr.speakerId,
                    operation: "evaluate",
                    action: expr.action,
                    condition: expr.conditionLabel,
                    conditionResult: true,
                    status: .broken,
                    breakReason: "action_not_fulfilled"
                )
                return .broken
            }
        }
    }

    /// Evaluate a looping expression. Returns (final_status, iteration_count).
    public func evaluateLoop(_ expr: HLExpression) -> (Status, Int) {
        var count = 0
        let maxIter = expr.loopMax ?? 10000

        while count < maxIter {
            if let loopCondition = expr.loopCondition, !loopCondition() {
                ledger.append(
                    speakerId: expr.speakerId,
                    operation: "loop_end",
                    action: expr.action,
                    status: .inactive,
                    stateAfter: "iterations:\(count)"
                )
                return (.inactive, count)
            }

            let status = evaluate(expr)
            count += 1

            if status == .broken { return (.broken, count) }
            if status == .inactive { return (.inactive, count) }
        }

        // Bound exceeded
        ledger.append(
            speakerId: expr.speakerId,
            operation: "loop_bound_exceeded",
            action: expr.action,
            status: .broken,
            breakReason: "max_iterations_\(maxIter)_exceeded",
            stateAfter: "iterations:\(count)"
        )
        return (.broken, count)
    }
}
