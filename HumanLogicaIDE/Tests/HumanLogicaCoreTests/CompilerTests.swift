// CompilerTests.swift — Tests for Logica Compiler (Proof Checker)

import XCTest
@testable import HumanLogicaCore

final class CompilerTests: XCTestCase {

    private func compile(_ source: String) throws -> CompiledProgram {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let compiler = Compiler()
        return try compiler.compile(ast)
    }

    // MARK: - Basic Compilation

    func testCompileHelloWorld() throws {
        let compiled = try compile("""
        speaker Jared
        as Jared {
            speak "Hello"
        }
        """)
        XCTAssertGreaterThan(compiled.operations.count, 0)
        XCTAssertTrue(compiled.speakers.contains("Jared"))
    }

    func testCompileMultipleSpeakers() throws {
        let compiled = try compile("""
        speaker A
        speaker B
        as A {
            speak "hello"
        }
        as B {
            speak "world"
        }
        """)
        XCTAssertTrue(compiled.speakers.contains("A"))
        XCTAssertTrue(compiled.speakers.contains("B"))
    }

    // MARK: - Axiom 1: Speaker Requirement

    func testAxiom1_CodeWithoutSpeakers() {
        // Code outside speaker context should fail
        XCTAssertThrowsError(try compile("""
        as Nobody {
            speak "hello"
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 1)
            } else {
                XCTFail("Expected axiom 1 violation, got: \(error)")
            }
        }
    }

    func testAxiom1_UndeclaredSpeaker() {
        XCTAssertThrowsError(try compile("""
        speaker Jared
        as Maria {
            speak "hello"
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 1)
            } else {
                XCTFail("Expected axiom 1 violation")
            }
        }
    }

    func testAxiom1_SpeakOutsideAsBlock() {
        XCTAssertThrowsError(try compile("""
        speaker Jared
        speak "orphan"
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 1)
            } else {
                XCTFail("Expected axiom 1 violation")
            }
        }
    }

    // MARK: - Axiom 8: Write Ownership

    func testAxiom8_WriteOwnership_DirectViolation() {
        XCTAssertThrowsError(try compile("""
        speaker Alice
        speaker Bob
        as Alice {
            let Bob.secret = "hacked"
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 8)
            } else {
                XCTFail("Expected axiom 8 violation, got: \(error)")
            }
        }
    }

    func testAxiom8_SelfWriteAllowed() throws {
        // Writing to your own variables should work
        let compiled = try compile("""
        speaker Alice
        as Alice {
            let myVar = 42
        }
        """)
        XCTAssertGreaterThan(compiled.operations.count, 0)
    }

    // BUG TEST: Write ownership violation inside if-body should be caught at compile time
    func testAxiom8_WriteOwnership_InsideIfBody() {
        // This SHOULD throw an axiom 8 violation at compile time
        // BUG: compileIf doesn't call checkBlockAxioms on the body
        XCTAssertThrowsError(try compile("""
        speaker Alice
        speaker Bob
        as Alice {
            if true {
                let Bob.secret = "hacked"
            }
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 8)
            } else {
                XCTFail("Expected axiom 8 violation inside if body, got: \(error)")
            }
        }
    }

    // BUG TEST: Write ownership violation inside while-body should be caught
    func testAxiom8_WriteOwnership_InsideWhileBody() {
        XCTAssertThrowsError(try compile("""
        speaker Alice
        speaker Bob
        as Alice {
            let x = 0
            while x < 1, max 10 {
                let Bob.secret = "hacked"
                let x = x + 1
            }
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 8)
            } else {
                XCTFail("Expected axiom 8 violation inside while body, got: \(error)")
            }
        }
    }

    // BUG TEST: Write ownership violation inside fn body should be caught
    func testAxiom8_WriteOwnership_InsideFnBody() {
        XCTAssertThrowsError(try compile("""
        speaker Alice
        speaker Bob
        as Alice {
            fn hack() {
                let Bob.secret = "hacked"
            }
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 8)
            } else {
                XCTFail("Expected axiom 8 violation inside fn body, got: \(error)")
            }
        }
    }

    // MARK: - Axiom 9: No Infinite Loops

    func testAxiom9_WhileWithoutMax() {
        XCTAssertThrowsError(try compile("""
        speaker X
        as X {
            while true {
                speak "infinite"
            }
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 9)
            } else {
                XCTFail("Expected axiom 9 violation, got: \(error)")
            }
        }
    }

    func testAxiom9_WhileWithMax() throws {
        // Should compile successfully
        let compiled = try compile("""
        speaker X
        as X {
            let i = 0
            while i < 10, max 100 {
                let i = i + 1
            }
        }
        """)
        XCTAssertGreaterThan(compiled.operations.count, 0)
    }

    // BUG TEST: While without max INSIDE when-body should be caught
    func testAxiom9_WhileWithoutMax_InsideWhenBody() {
        XCTAssertThrowsError(try compile("""
        speaker X
        as X {
            when true {
                while true {
                    speak "nested infinite"
                }
            }
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 9)
            } else {
                XCTFail("Expected axiom 9 violation, got: \(error)")
            }
        }
    }

    // MARK: - Axiom 5: Sealed Variables

    func testSealedVariableCannotBeOverwritten() {
        XCTAssertThrowsError(try compile("""
        speaker X
        as X {
            let grade = 92
            seal grade
            let grade = 100
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 5)
            } else {
                XCTFail("Expected axiom 5 violation, got: \(error)")
            }
        }
    }

    // MARK: - Request Target Validation

    func testRequestToUndeclaredSpeaker() {
        XCTAssertThrowsError(try compile("""
        speaker Alice
        as Alice {
            request Ghost "hello"
        }
        """)) { error in
            if case LogicaError.axiomViolation(let axiom, _, _, _) = error {
                XCTAssertEqual(axiom, 1)
            } else {
                XCTFail("Expected axiom 1 violation for undeclared request target, got: \(error)")
            }
        }
    }

    // MARK: - Speaker Context Restoration

    func testSpeakerContextRestored() throws {
        let compiled = try compile("""
        speaker A
        speaker B
        as A {
            speak "from A"
            as B {
                speak "from B"
            }
            speak "back to A"
        }
        """)
        // After nested as-block, speaker context should be restored to A
        let setSpeakerOps = compiled.operations.filter { $0.op == .setSpeaker }
        // Should have: set A, set B, set A (restore)
        XCTAssertGreaterThanOrEqual(setSpeakerOps.count, 3)
    }
}
