// Memory.swift — Speaker-Partitioned Memory
// Axiom 8: Only speaker s can write to s's variables.
// Definition 9.1: Any speaker can read any variable.

import Foundation

public class Memory {
    private var partitions: [Int: [String: Any]] = [:]

    public init() {}

    /// Create a memory partition for a speaker.
    public func createPartition(speakerId: Int) {
        if partitions[speakerId] == nil {
            partitions[speakerId] = [:]
        }
    }

    /// Read any speaker's variable. Unrestricted. Returns nil if not found.
    public func read(ownerId: Int, varName: String) -> Any? {
        partitions[ownerId]?[varName]
    }

    /// Write to caller's own partition ONLY. Returns (success, oldValue).
    public func write(callerId: Int, varName: String, value: Any) -> (Bool, Any?) {
        guard partitions[callerId] != nil else {
            return (false, nil)
        }
        let oldValue = partitions[callerId]?[varName]
        partitions[callerId]?[varName] = value
        return (true, oldValue)
    }

    /// Check if a write would be allowed. Only self-writes allowed.
    public func writeCheck(callerId: Int, targetId: Int) -> Bool {
        callerId == targetId
    }

    /// List variable names in a speaker's partition.
    public func listVars(ownerId: Int) -> [String] {
        Array(partitions[ownerId]?.keys ?? [String: Any]().keys)
    }

    /// Get a copy of a speaker's entire partition (read-only snapshot).
    public func getPartition(speakerId: Int) -> [String: Any] {
        partitions[speakerId] ?? [:]
    }
}
