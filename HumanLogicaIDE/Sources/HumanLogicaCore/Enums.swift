// Enums.swift — The Three Values and More
// Every operation has a speaker. Every status has meaning.

import Foundation

/// Expression evaluation status. Three values. No more.
public enum Status: String, Codable, Sendable {
    case active = "active"
    case inactive = "inactive"
    case broken = "broken"
}

/// Speaker lifecycle status.
public enum SpeakerStatus: String, Codable, Sendable {
    case alive = "alive"
    case suspended = "suspended"
}

/// Speaker's position on a given action.
public enum Position: String, Codable, Sendable {
    case committed = "committed"
    case refused = "refused"
    case silent = "silent"
}

/// Expression version state.
public enum ExpressionVersion: String, Codable, Sendable {
    case current = "current"
    case superseded = "superseded"
    case expired = "expired"
}

/// Request lifecycle status.
public enum RequestStatus: String, Codable, Sendable {
    case pending = "pending"
    case accepted = "accepted"
    case refused = "refused"
    case expired = "expired"
}
