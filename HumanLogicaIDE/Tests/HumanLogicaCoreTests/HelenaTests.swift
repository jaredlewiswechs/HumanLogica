// HelenaTests.swift — Tests for Helena (OS Layer)

import XCTest
@testable import HumanLogicaCore

final class HelenaTests: XCTestCase {

    // MARK: - Boot

    func testHelenaBoot() {
        let helena = Helena()
        let state = helena.state()
        XCTAssertNotNil(state["mary"])
    }

    // MARK: - Speaker Management

    func testCreateSpeaker() {
        let helena = Helena()
        let id = helena.createSpeaker(name: "Jared")
        XCTAssertGreaterThan(id, 0)
    }

    func testGetSpeakerName() {
        let helena = Helena()
        let id = helena.createSpeaker(name: "Jared")
        let name = helena.getSpeakerName(speakerId: id)
        XCTAssertEqual(name, "Jared")
    }

    // MARK: - World Management

    func testCreateWorld() {
        let helena = Helena()
        let speakerId = helena.createSpeaker(name: "Creator")
        let worldId = helena.createWorld(creatorId: speakerId, name: "TestWorld")
        XCTAssertNotNil(worldId)
    }

    func testJoinWorld() {
        let helena = Helena()
        let creator = helena.createSpeaker(name: "Creator")
        let joiner = helena.createSpeaker(name: "Joiner")
        let worldId = helena.createWorld(creatorId: creator, name: "TestWorld")!
        let success = helena.joinWorld(speakerId: joiner, worldId: worldId)
        XCTAssertTrue(success)
    }

    func testWorldWrite() {
        let helena = Helena()
        let speaker = helena.createSpeaker(name: "Writer")
        let worldId = helena.createWorld(creatorId: speaker, name: "TestWorld")!
        let success = helena.worldWrite(speakerId: speaker, worldId: worldId, varName: "data", value: 42)
        XCTAssertTrue(success)
    }

    func testWorldRead() {
        let helena = Helena()
        let speaker = helena.createSpeaker(name: "RW")
        let worldId = helena.createWorld(creatorId: speaker, name: "TestWorld")!
        helena.worldWrite(speakerId: speaker, worldId: worldId, varName: "data", value: "hello")
        let value = helena.worldRead(callerId: speaker, worldId: worldId, ownerId: speaker, varName: "data")
        XCTAssertEqual(value as? String, "hello")
    }

    func testWorldWriteNonMember() {
        let helena = Helena()
        let creator = helena.createSpeaker(name: "Creator")
        let outsider = helena.createSpeaker(name: "Outsider")
        let worldId = helena.createWorld(creatorId: creator, name: "Private")!
        let success = helena.worldWrite(speakerId: outsider, worldId: worldId, varName: "hack", value: "fail")
        XCTAssertFalse(success)
    }

    // MARK: - File Operations

    func testCreateAndReadFile() {
        let helena = Helena()
        let speaker = helena.createSpeaker(name: "FileUser")
        let worldId = helena.createWorld(creatorId: speaker, name: "FileWorld")!
        helena.createFile(speakerId: speaker, worldId: worldId, filename: "readme.txt", content: "Hello")
        let content = helena.readFile(callerId: speaker, worldId: worldId, ownerId: speaker, filename: "readme.txt")
        XCTAssertEqual(content as? String, "Hello")
    }

    // MARK: - Blocking

    func testBlock() {
        let helena = Helena()
        let a = helena.createSpeaker(name: "A")
        let b = helena.createSpeaker(name: "B")
        helena.block(speakerId: a, targetId: b)
        XCTAssertTrue(helena.isBlocked(speakerId: b, bySpeaker: a))
        XCTAssertFalse(helena.isBlocked(speakerId: a, bySpeaker: b))
    }

    // MARK: - World Listing

    func testListWorlds() {
        let helena = Helena()
        let speaker = helena.createSpeaker(name: "Multi")
        helena.createWorld(creatorId: speaker, name: "World1")
        helena.createWorld(creatorId: speaker, name: "World2")
        let worlds = helena.listWorlds(speakerId: speaker)
        XCTAssertEqual(worlds.count, 2)
    }

    func testGetWorld() {
        let helena = Helena()
        let speaker = helena.createSpeaker(name: "Creator")
        let worldId = helena.createWorld(creatorId: speaker, name: "TestWorld")!
        let world = helena.getWorld(worldId)
        XCTAssertNotNil(world)
        XCTAssertEqual(world?.name, "TestWorld")
    }
}
