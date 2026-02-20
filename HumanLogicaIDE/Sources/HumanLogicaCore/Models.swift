// Models.swift — Data Structures
// Speakers, ledger entries, requests, and expressions.

import Foundation

/// A speaker in the system. Every statement has one.
public class Speaker: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let createdAt: Date
    public var status: SpeakerStatus

    public init(id: Int, name: String, createdAt: Date = Date(), status: SpeakerStatus = .alive) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.status = status
    }

    public var isAlive: Bool {
        status == .alive
    }
}

/// One entry in the append-only ledger. Every operation produces one.
public class LedgerEntry: Identifiable, Sendable {
    public let entryId: Int
    public let speakerId: Int
    public let operation: String
    public let condition: String?
    public let conditionResult: Bool?
    public let action: String
    public let status: Status?
    public let stateBefore: String?
    public let stateAfter: String?
    public let timestamp: Date
    public let prevHash: String
    public var entryHash: String
    public let breakReason: String?

    public var id: Int { entryId }

    public init(entryId: Int, speakerId: Int, operation: String,
                condition: String? = nil, conditionResult: Bool? = nil,
                action: String, status: Status? = nil,
                stateBefore: String? = nil, stateAfter: String? = nil,
                timestamp: Date = Date(), prevHash: String,
                entryHash: String = "", breakReason: String? = nil) {
        self.entryId = entryId
        self.speakerId = speakerId
        self.operation = operation
        self.condition = condition
        self.conditionResult = conditionResult
        self.action = action
        self.status = status
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.timestamp = timestamp
        self.prevHash = prevHash
        self.entryHash = entryHash
        self.breakReason = breakReason
    }

    /// Hash this entry for chain integrity.
    public func computeHash() -> String {
        let data = "\(entryId):\(speakerId):\(operation):\(action):\(timestamp.timeIntervalSince1970):\(prevHash)"
        return data.sha256Prefix(16)
    }
}

/// A request from one speaker to another.
public class Request: Identifiable, Sendable {
    public let requestId: Int
    public let fromSpeaker: Int
    public let toSpeaker: Int
    public let action: String
    public let data: Any?
    public var status: RequestStatus
    public let createdAt: Date
    public let expiresAt: Date?
    public var responseData: Any?

    public var id: Int { requestId }

    public init(requestId: Int, fromSpeaker: Int, toSpeaker: Int,
                action: String, data: Any? = nil,
                status: RequestStatus = .pending,
                createdAt: Date = Date(), expiresAt: Date? = nil,
                responseData: Any? = nil) {
        self.requestId = requestId
        self.fromSpeaker = fromSpeaker
        self.toSpeaker = toSpeaker
        self.action = action
        self.data = data
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.responseData = responseData
    }
}

/// A Human Logic expression: speaker : condition ⊢ action
public class HLExpression {
    public let expressionId: Int
    public let speakerId: Int
    public let condition: (() -> Bool)?
    public let conditionLabel: String
    public let action: String
    public let actionFn: (() -> Bool)?
    public let createdAt: Date
    public var version: ExpressionVersion
    public var status: Status?
    public let scopeUntil: Date?
    public let isRefusal: Bool
    public let loopCondition: (() -> Bool)?
    public let loopMax: Int?

    public init(expressionId: Int, speakerId: Int,
                condition: (() -> Bool)? = nil,
                conditionLabel: String = "⊤",
                action: String = "",
                actionFn: (() -> Bool)? = nil,
                createdAt: Date = Date(),
                version: ExpressionVersion = .current,
                status: Status? = nil,
                scopeUntil: Date? = nil,
                isRefusal: Bool = false,
                loopCondition: (() -> Bool)? = nil,
                loopMax: Int? = nil) {
        self.expressionId = expressionId
        self.speakerId = speakerId
        self.condition = condition
        self.conditionLabel = conditionLabel
        self.action = action
        self.actionFn = actionFn
        self.createdAt = createdAt
        self.version = version
        self.status = status
        self.scopeUntil = scopeUntil
        self.isRefusal = isRefusal
        self.loopCondition = loopCondition
        self.loopMax = loopMax
    }
}

// MARK: - SHA256 Helper

extension String {
    func sha256Prefix(_ length: Int) -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            // Simple SHA-256 using CommonCrypto-compatible approach
            var h: [UInt32] = [
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
            ]
            let k: [UInt32] = [
                0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
                0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
                0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
                0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
                0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
                0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
                0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
                0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
                0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
                0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
                0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
                0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
                0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
                0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
                0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
                0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
            ]

            // Pad the message
            var message = Array(buffer.bindMemory(to: UInt8.self))
            let originalLength = message.count
            message.append(0x80)
            while (message.count % 64) != 56 {
                message.append(0x00)
            }
            let bitLength = UInt64(originalLength) * 8
            for i in stride(from: 56, through: 0, by: -8) {
                message.append(UInt8((bitLength >> i) & 0xff))
            }

            // Process each 512-bit block
            for chunkStart in stride(from: 0, to: message.count, by: 64) {
                var w = [UInt32](repeating: 0, count: 64)
                for i in 0..<16 {
                    let offset = chunkStart + i * 4
                    w[i] = UInt32(message[offset]) << 24 |
                            UInt32(message[offset + 1]) << 16 |
                            UInt32(message[offset + 2]) << 8 |
                            UInt32(message[offset + 3])
                }

                for i in 16..<64 {
                    let s0 = (w[i-15].rotateRight(7)) ^ (w[i-15].rotateRight(18)) ^ (w[i-15] >> 3)
                    let s1 = (w[i-2].rotateRight(17)) ^ (w[i-2].rotateRight(19)) ^ (w[i-2] >> 10)
                    w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
                }

                var a = h[0], b = h[1], c = h[2], d = h[3]
                var e = h[4], f = h[5], g = h[6], hh = h[7]

                for i in 0..<64 {
                    let S1 = e.rotateRight(6) ^ e.rotateRight(11) ^ e.rotateRight(25)
                    let ch = (e & f) ^ (~e & g)
                    let temp1 = hh &+ S1 &+ ch &+ k[i] &+ w[i]
                    let S0 = a.rotateRight(2) ^ a.rotateRight(13) ^ a.rotateRight(22)
                    let maj = (a & b) ^ (a & c) ^ (b & c)
                    let temp2 = S0 &+ maj

                    hh = g; g = f; f = e
                    e = d &+ temp1
                    d = c; c = b; b = a
                    a = temp1 &+ temp2
                }

                h[0] = h[0] &+ a; h[1] = h[1] &+ b
                h[2] = h[2] &+ c; h[3] = h[3] &+ d
                h[4] = h[4] &+ e; h[5] = h[5] &+ f
                h[6] = h[6] &+ g; h[7] = h[7] &+ hh
            }

            for i in 0..<8 {
                hash[i * 4] = UInt8((h[i] >> 24) & 0xff)
                hash[i * 4 + 1] = UInt8((h[i] >> 16) & 0xff)
                hash[i * 4 + 2] = UInt8((h[i] >> 8) & 0xff)
                hash[i * 4 + 3] = UInt8(h[i] & 0xff)
            }
        }
        return hash.prefix(length / 2).map { String(format: "%02x", $0) }.joined()
    }
}

extension UInt32 {
    func rotateRight(_ count: UInt32) -> UInt32 {
        (self >> count) | (self << (32 - count))
    }
}
