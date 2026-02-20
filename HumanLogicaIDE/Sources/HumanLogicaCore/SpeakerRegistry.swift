// SpeakerRegistry.swift — Speaker Identity Management
// Definition 5.1: Every call requires a speaker identity.
// Definition 5.2: Root is created at initialization.

import Foundation

public class SpeakerRegistry {
    private var speakers: [Int: Speaker] = [:]
    private var nextId: Int = 0

    public init() {}

    /// Create a new speaker. Returns the speaker record.
    @discardableResult
    public func create(name: String, creatorId: Int? = nil) -> Speaker {
        let speaker = Speaker(id: nextId, name: name, createdAt: Date())
        speakers[speaker.id] = speaker
        nextId += 1
        return speaker
    }

    /// Get a speaker by ID.
    public func get(speakerId: Int) -> Speaker? {
        speakers[speakerId]
    }

    /// Verify speaker exists and is alive.
    public func authenticate(speakerId: Int) -> Bool {
        guard let speaker = speakers[speakerId] else { return false }
        return speaker.isAlive
    }

    /// Suspend a speaker. They can no longer issue expressions.
    public func suspend(speakerId: Int) -> Bool {
        guard let speaker = speakers[speakerId] else { return false }
        speaker.status = .suspended
        return true
    }

    /// List all speakers.
    public func listAll() -> [Speaker] {
        Array(speakers.values)
    }
}
