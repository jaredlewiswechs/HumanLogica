// RequestBus.swift — Inter-Speaker Communication
// Rule 15.1: No direct memory access between speakers.
// Rule 15.2: One sender, one receiver per request.
// Rule 15.3: FIFO processing.

import Foundation

public class RequestBus {
    private var pending: [Request] = []
    private var resolved: [Request] = []
    private var nextId: Int = 0

    public init() {}

    /// Create a new request.
    @discardableResult
    public func createRequest(fromSpeaker: Int, toSpeaker: Int,
                               action: String, data: Any? = nil,
                               expiresAt: Date? = nil) -> Request {
        let req = Request(
            requestId: nextId,
            fromSpeaker: fromSpeaker,
            toSpeaker: toSpeaker,
            action: action,
            data: data,
            createdAt: Date(),
            expiresAt: expiresAt
        )
        nextId += 1
        pending.append(req)
        return req
    }

    /// Find a request by ID.
    public func getRequest(requestId: Int) -> Request? {
        (pending + resolved).first { $0.requestId == requestId }
    }

    /// Respond to a request. Only the target speaker can respond.
    @discardableResult
    public func respond(requestId: Int, responderId: Int,
                         accept: Bool, responseData: Any? = nil) -> Request? {
        guard let index = pending.firstIndex(where: { $0.requestId == requestId }) else {
            return nil
        }
        let req = pending[index]
        guard req.toSpeaker == responderId else { return nil }
        guard req.status == .pending else { return nil }

        req.status = accept ? .accepted : .refused
        req.responseData = responseData
        pending.remove(at: index)
        resolved.append(req)
        return req
    }

    /// Get all pending requests for a speaker.
    public func getPendingFor(speakerId: Int) -> [Request] {
        pending.filter { $0.toSpeaker == speakerId }
    }

    /// Get all pending requests from a speaker.
    public func getPendingFrom(speakerId: Int) -> [Request] {
        pending.filter { $0.fromSpeaker == speakerId }
    }

    /// Expire timed-out requests. Returns list of expired requests.
    public func checkTimeouts() -> [Request] {
        let now = Date()
        var expired: [Request] = []
        var stillPending: [Request] = []

        for req in pending {
            if let expiresAt = req.expiresAt, now > expiresAt {
                req.status = .expired
                resolved.append(req)
                expired.append(req)
            } else {
                stillPending.append(req)
            }
        }
        pending = stillPending
        return expired
    }

    public var pendingCount: Int { pending.count }
}
