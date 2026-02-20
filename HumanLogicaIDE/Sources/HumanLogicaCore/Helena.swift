// Helena.swift — An Operating System for Humans
// Helena sits on Mary. She manages worlds, files, identity, inspection.
// Helena is a speaker. She follows the same rules.
// Helena does not override Mary. Helena cannot override Mary.

import Foundation

/// What a member can do in a world.
public struct WorldPermissions {
    public var read: Bool
    public var write: Bool
    public var submit: Bool
    public var request: Bool
    public var invite: Bool
    public var configure: Bool

    public init(read: Bool = true, write: Bool = true, submit: Bool = true,
                request: Bool = true, invite: Bool = false, configure: Bool = false) {
        self.read = read
        self.write = write
        self.submit = submit
        self.request = request
        self.invite = invite
        self.configure = configure
    }

    public static let full = WorldPermissions(read: true, write: true, submit: true,
                                               request: true, invite: true, configure: true)
    public static let `default` = WorldPermissions()
}

public enum WorldStatus: String {
    case open = "open"
    case closed = "closed"
    case archived = "archived"
}

/// A speaker's membership in a world.
public struct WorldMember {
    public let speakerId: Int
    public let permissions: WorldPermissions
    public let joinedAt: Date
    public var role: String

    public init(speakerId: Int, permissions: WorldPermissions, joinedAt: Date = Date(), role: String = "member") {
        self.speakerId = speakerId
        self.permissions = permissions
        self.joinedAt = joinedAt
        self.role = role
    }
}

/// An isolated environment where speakers create, compute, interact.
public class World {
    public let worldId: String
    public let name: String
    public let creatorId: Int
    public let createdAt: Date
    public var status: WorldStatus
    public var members: [Int: WorldMember]
    public let namespace: String

    public init(worldId: String, name: String, creatorId: Int, createdAt: Date = Date(),
                status: WorldStatus = .open, namespace: String = "") {
        self.worldId = worldId
        self.name = name
        self.creatorId = creatorId
        self.createdAt = createdAt
        self.status = status
        self.members = [:]
        self.namespace = namespace.isEmpty ? worldId : namespace
    }

    public func isMember(_ speakerId: Int) -> Bool {
        members[speakerId] != nil
    }

    public func getPermissions(_ speakerId: Int) -> WorldPermissions? {
        members[speakerId]?.permissions
    }

    public func can(_ speakerId: Int, _ permission: String) -> Bool {
        guard let perms = getPermissions(speakerId) else { return false }
        switch permission {
        case "read": return perms.read
        case "write": return perms.write
        case "submit": return perms.submit
        case "request": return perms.request
        case "invite": return perms.invite
        case "configure": return perms.configure
        default: return false
        }
    }
}

/// The operating system. Where humans live.
public class Helena {
    public let mary: Mary
    public let speaker: Speaker
    private var worlds: [String: World] = [:]
    private var nextWorldId: Int = 0
    private var blocks: [Int: Set<Int>] = [:]

    public init() {
        mary = Mary()
        speaker = mary.createSpeaker(callerId: 0, name: "helena")!
        mary.write(callerId: speaker.id, varName: "system.status", value: "booted")
        mary.write(callerId: speaker.id, varName: "system.boot_time", value: Date().timeIntervalSince1970)
    }

    // MARK: - Speaker Management

    public func createSpeaker(name: String) -> Int {
        guard let newSpeaker = mary.createSpeaker(callerId: speaker.id, name: name) else { return -1 }
        mary.write(callerId: newSpeaker.id, varName: "profile.name", value: name)
        mary.write(callerId: newSpeaker.id, varName: "profile.created_at", value: Date().timeIntervalSince1970)
        return newSpeaker.id
    }

    public func getSpeakerName(speakerId: Int) -> String {
        if let name = mary.read(callerId: speaker.id, ownerId: speakerId, varName: "profile.name") as? String {
            return name
        }
        return mary.registry.get(speakerId: speakerId)?.name ?? "speaker_\(speakerId)"
    }

    // MARK: - World Management

    @discardableResult
    public func createWorld(creatorId: Int, name: String, defaultPermissions: WorldPermissions? = nil,
                             entryOpen: Bool = false) -> String? {
        guard mary.registry.authenticate(creatorId) else { return nil }

        let worldId = "world_\(nextWorldId)"
        nextWorldId += 1

        let world = World(worldId: worldId, name: name, creatorId: creatorId)
        world.members[creatorId] = WorldMember(
            speakerId: creatorId,
            permissions: .full,
            role: "creator"
        )
        worlds[worldId] = world

        mary.write(callerId: speaker.id, varName: "worlds.\(worldId).name", value: name)
        mary.write(callerId: speaker.id, varName: "worlds.\(worldId).creator", value: creatorId)
        mary.write(callerId: speaker.id, varName: "worlds.\(worldId).status", value: WorldStatus.open.rawValue)

        mary.submit(speakerId: creatorId, conditionLabel: "⊤",
                    action: "create_world:\(worldId):\(name)",
                    actionFn: { true })
        return worldId
    }

    @discardableResult
    public func joinWorld(speakerId: Int, worldId: String, permissions: WorldPermissions? = nil) -> Bool {
        guard let world = worlds[worldId], world.status == .open,
              mary.registry.authenticate(speakerId) else { return false }

        world.members[speakerId] = WorldMember(
            speakerId: speakerId,
            permissions: permissions ?? .default
        )

        mary.submit(speakerId: speakerId, conditionLabel: "invited_to:\(worldId)",
                    action: "join_world:\(worldId)", actionFn: { true })
        return true
    }

    public func getWorld(_ worldId: String) -> World? {
        worlds[worldId]
    }

    public func listWorlds(speakerId: Int) -> [World] {
        worlds.values.filter { $0.isMember(speakerId) }
    }

    // MARK: - World-Scoped Operations

    @discardableResult
    public func worldWrite(speakerId: Int, worldId: String, varName: String, value: Any) -> Bool {
        guard let world = worlds[worldId], world.can(speakerId, "write"),
              world.status != .archived else { return false }
        let fullVar = "\(worldId).\(speakerId).\(varName)"
        return mary.write(callerId: speakerId, varName: fullVar, value: value)
    }

    public func worldRead(callerId: Int, worldId: String, ownerId: Int, varName: String) -> Any? {
        guard let world = worlds[worldId], world.can(callerId, "read") else { return nil }
        let fullVar = "\(worldId).\(ownerId).\(varName)"
        return mary.read(callerId: callerId, ownerId: ownerId, varName: fullVar)
    }

    // MARK: - File Operations

    @discardableResult
    public func createFile(speakerId: Int, worldId: String, filename: String, content: Any) -> Bool {
        worldWrite(speakerId: speakerId, worldId: worldId, varName: "file.\(filename)", value: content)
    }

    public func readFile(callerId: Int, worldId: String, ownerId: Int, filename: String) -> Any? {
        worldRead(callerId: callerId, worldId: worldId, ownerId: ownerId, varName: "file.\(filename)")
    }

    // MARK: - Blocking

    @discardableResult
    public func block(speakerId: Int, targetId: Int) -> Bool {
        if blocks[speakerId] == nil { blocks[speakerId] = [] }
        blocks[speakerId]?.insert(targetId)
        mary.submit(speakerId: speakerId, conditionLabel: "⊤",
                    action: "block:\(targetId)", actionFn: { true })
        return true
    }

    public func isBlocked(speakerId: Int, bySpeaker: Int) -> Bool {
        blocks[bySpeaker]?.contains(speakerId) ?? false
    }

    // MARK: - State

    public func state() -> [String: Any] {
        [
            "mary": mary.state(),
            "worlds": worlds.count,
            "world_list": worlds.values.map { w in
                ["id": w.worldId, "name": w.name, "members": w.members.count, "status": w.status.rawValue]
            }
        ]
    }
}
