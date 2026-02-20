// Ledger.swift — Append-Only, Hash-Chained Log
// Rule 9.1: Append only. No modification. No deletion. Ever.
// Rule 9.2: Total capture. Every operation produces an entry.
// Rule 9.3: Sequential consistency. Ordered by entry_id.

import Foundation

public class Ledger {
    private var entries: [LedgerEntry] = []
    private var lastHash: String = "genesis"

    public init() {}

    /// Append a new entry. Returns the entry with its hash.
    @discardableResult
    public func append(speakerId: Int, operation: String, action: String,
                       condition: String? = nil, conditionResult: Bool? = nil,
                       status: Status? = nil, stateBefore: String? = nil,
                       stateAfter: String? = nil, breakReason: String? = nil) -> LedgerEntry {
        let entry = LedgerEntry(
            entryId: entries.count,
            speakerId: speakerId,
            operation: operation,
            condition: condition,
            conditionResult: conditionResult,
            action: action,
            status: status,
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            timestamp: Date(),
            prevHash: lastHash,
            breakReason: breakReason
        )
        entry.entryHash = entry.computeHash()
        lastHash = entry.entryHash
        entries.append(entry)
        return entry
    }

    /// Read entries by ID range.
    public func read(fromId: Int = 0, toId: Int? = nil) -> [LedgerEntry] {
        let end = toId ?? entries.count
        let safeStart = max(0, min(fromId, entries.count))
        let safeEnd = max(safeStart, min(end, entries.count))
        return Array(entries[safeStart..<safeEnd])
    }

    /// Search entries by filters.
    public func search(speakerId: Int? = nil, operation: String? = nil,
                       action: String? = nil, fromTime: Date? = nil,
                       toTime: Date? = nil) -> [LedgerEntry] {
        var results = entries
        if let sid = speakerId {
            results = results.filter { $0.speakerId == sid }
        }
        if let op = operation {
            results = results.filter { $0.operation == op }
        }
        if let act = action {
            results = results.filter { $0.action == act }
        }
        if let from = fromTime {
            results = results.filter { $0.timestamp >= from }
        }
        if let to = toTime {
            results = results.filter { $0.timestamp <= to }
        }
        return results
    }

    /// Walk the hash chain. Return true if unbroken.
    public func verifyIntegrity() -> Bool {
        if entries.isEmpty { return true }
        var expectedPrev = "genesis"
        for entry in entries {
            if entry.prevHash != expectedPrev { return false }
            if entry.entryHash != entry.computeHash() { return false }
            expectedPrev = entry.entryHash
        }
        return true
    }

    public var count: Int { entries.count }

    public var last: LedgerEntry? { entries.last }

    /// Get all entries (read-only snapshot).
    public var allEntries: [LedgerEntry] { entries }
}
