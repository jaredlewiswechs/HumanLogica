// MaryTests.swift — Tests for Mary (The Kernel)

import XCTest
@testable import HumanLogicaCore

final class MaryTests: XCTestCase {

    // MARK: - Boot

    func testMaryBoot() {
        let mary = Mary()
        XCTAssertNotNil(mary.root)
        XCTAssertEqual(mary.root?.name, "root")
        XCTAssertTrue(mary.ledgerVerify())
    }

    // MARK: - Speaker Management

    func testCreateSpeaker() {
        let mary = Mary()
        let speaker = mary.createSpeaker(callerId: 0, name: "Jared")
        XCTAssertNotNil(speaker)
        XCTAssertEqual(speaker?.name, "Jared")
    }

    func testCreateSpeakerByNonAuthenticated() {
        let mary = Mary()
        let speaker = mary.createSpeaker(callerId: 999, name: "Ghost")
        XCTAssertNil(speaker) // caller 999 doesn't exist
    }

    func testListSpeakers() {
        let mary = Mary()
        _ = mary.createSpeaker(callerId: 0, name: "A")
        _ = mary.createSpeaker(callerId: 0, name: "B")
        let speakers = mary.listSpeakers(callerId: 0)
        XCTAssertGreaterThanOrEqual(speakers.count, 3) // root + A + B
    }

    func testSuspendSpeaker() {
        let mary = Mary()
        let speaker = mary.createSpeaker(callerId: 0, name: "Target")!
        let success = mary.suspendSpeaker(callerId: 0, targetId: speaker.id)
        XCTAssertTrue(success)
        // Suspended speaker should not authenticate
        XCTAssertFalse(mary.registry.authenticate(speaker.id))
    }

    func testSuspendSpeakerNonRoot() {
        let mary = Mary()
        let a = mary.createSpeaker(callerId: 0, name: "A")!
        let b = mary.createSpeaker(callerId: 0, name: "B")!
        let success = mary.suspendSpeaker(callerId: a.id, targetId: b.id)
        XCTAssertFalse(success) // Only root can suspend
    }

    // MARK: - Memory Operations

    func testWriteAndRead() {
        let mary = Mary()
        let speaker = mary.createSpeaker(callerId: 0, name: "Writer")!
        let success = mary.write(callerId: speaker.id, varName: "x", value: 42)
        XCTAssertTrue(success)
        let value = mary.read(callerId: 0, ownerId: speaker.id, varName: "x")
        XCTAssertEqual(value as? Int, 42)
    }

    func testWriteToOther_Fails() {
        let mary = Mary()
        let a = mary.createSpeaker(callerId: 0, name: "A")!
        let b = mary.createSpeaker(callerId: 0, name: "B")!
        let success = mary.writeTo(callerId: a.id, targetId: b.id, varName: "x", value: 42)
        XCTAssertFalse(success) // Axiom 8: can't write to other's vars
    }

    func testReadOthersVars() {
        let mary = Mary()
        let a = mary.createSpeaker(callerId: 0, name: "A")!
        let b = mary.createSpeaker(callerId: 0, name: "B")!
        mary.write(callerId: a.id, varName: "public_data", value: "hello")
        let value = mary.read(callerId: b.id, ownerId: a.id, varName: "public_data")
        XCTAssertEqual(value as? String, "hello")
    }

    func testListVars() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        mary.write(callerId: s.id, varName: "x", value: 1)
        mary.write(callerId: s.id, varName: "y", value: 2)
        let vars = mary.listVars(callerId: 0, ownerId: s.id)
        XCTAssertTrue(vars.contains("x"))
        XCTAssertTrue(vars.contains("y"))
    }

    // MARK: - Expression Submission

    func testSubmitExpression_Active() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        let expr = mary.submit(
            speakerId: s.id,
            conditionLabel: "test",
            action: "test_action",
            actionFn: { true }
        )
        XCTAssertNotNil(expr)
        XCTAssertEqual(expr?.status, .active)
    }

    func testSubmitExpression_Broken() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        let expr = mary.submit(
            speakerId: s.id,
            conditionLabel: "test",
            action: "test_action",
            actionFn: { false }
        )
        XCTAssertNotNil(expr)
        XCTAssertEqual(expr?.status, .broken)
    }

    func testSubmitExpression_Inactive() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        let expr = mary.submit(
            speakerId: s.id,
            condition: { false },
            conditionLabel: "failed_condition",
            action: "test_action"
        )
        XCTAssertNotNil(expr)
        XCTAssertEqual(expr?.status, .inactive)
    }

    func testSupersession() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        let first = mary.submit(
            speakerId: s.id,
            conditionLabel: "same",
            action: "same_action",
            actionFn: { true }
        )
        let second = mary.submit(
            speakerId: s.id,
            conditionLabel: "same",
            action: "same_action",
            actionFn: { true }
        )
        XCTAssertEqual(first?.version, .superseded)
        XCTAssertEqual(second?.version, .current)
    }

    // MARK: - Communication (Request Bus)

    func testRequestAndRespond() {
        let mary = Mary()
        let a = mary.createSpeaker(callerId: 0, name: "A")!
        let b = mary.createSpeaker(callerId: 0, name: "B")!

        let req = mary.request(callerId: a.id, targetId: b.id, action: "help")
        XCTAssertNotNil(req)

        let pending = mary.pendingRequests(callerId: b.id)
        XCTAssertEqual(pending.count, 1)

        let success = mary.respond(callerId: b.id, requestId: req!.requestId, accept: true)
        XCTAssertTrue(success)

        let pendingAfter = mary.pendingRequests(callerId: b.id)
        XCTAssertEqual(pendingAfter.count, 0)
    }

    func testRespondWrongSpeaker() {
        let mary = Mary()
        let a = mary.createSpeaker(callerId: 0, name: "A")!
        let b = mary.createSpeaker(callerId: 0, name: "B")!
        let c = mary.createSpeaker(callerId: 0, name: "C")!

        let req = mary.request(callerId: a.id, targetId: b.id, action: "help")!
        // C tries to respond to B's request
        let success = mary.respond(callerId: c.id, requestId: req.requestId, accept: true)
        XCTAssertFalse(success)
    }

    // MARK: - Ledger

    func testLedgerIntegrity() {
        let mary = Mary()
        _ = mary.createSpeaker(callerId: 0, name: "S")
        XCTAssertTrue(mary.ledgerVerify())
    }

    func testLedgerRead() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        mary.write(callerId: s.id, varName: "x", value: 42)
        let entries = mary.ledgerRead(callerId: 0)
        XCTAssertGreaterThan(entries.count, 0)
    }

    func testLedgerSearch() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        mary.write(callerId: s.id, varName: "x", value: 42)
        let results = mary.ledgerSearch(callerId: 0, operation: "write")
        XCTAssertGreaterThan(results.count, 0)
    }

    // MARK: - Inspection

    func testInspectSpeaker() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "TestSpeaker")!
        mary.write(callerId: s.id, varName: "x", value: 42)
        let info = mary.inspectSpeaker(callerId: 0, targetId: s.id)
        XCTAssertNotNil(info)
        let speakerInfo = info?["speaker"] as? [String: Any]
        XCTAssertEqual(speakerInfo?["name"] as? String, "TestSpeaker")
    }

    func testInspectVariable() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        mary.write(callerId: s.id, varName: "x", value: 42)
        let info = mary.inspectVariable(callerId: 0, ownerId: s.id, varName: "x")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?["current_value"] as? Int, 42)
    }

    // MARK: - State

    func testMaryState() {
        let mary = Mary()
        let state = mary.state()
        XCTAssertGreaterThan(state["speakers"] as? Int ?? 0, 0)
        XCTAssertGreaterThan(state["ledger_entries"] as? Int ?? 0, 0)
        XCTAssertEqual(state["ledger_integrity"] as? Bool, true)
    }

    // MARK: - Loop Expression

    func testLoopExpression() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        var counter = 0
        let result = mary.submitLoop(
            speakerId: s.id,
            conditionLabel: "loop_test",
            action: "count",
            actionFn: { counter += 1; return true },
            loopCondition: { counter < 5 },
            loopMax: 100
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.1, 5) // 5 iterations
    }

    func testLoopExpressionMaxExceeded() {
        let mary = Mary()
        let s = mary.createSpeaker(callerId: 0, name: "S")!
        let result = mary.submitLoop(
            speakerId: s.id,
            conditionLabel: "infinite",
            action: "count",
            actionFn: { true },
            loopCondition: { true }, // never terminates
            loopMax: 3
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, .broken)
    }
}
