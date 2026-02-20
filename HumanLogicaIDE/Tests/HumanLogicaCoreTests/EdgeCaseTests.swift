// EdgeCaseTests.swift — Tests for edge cases, regressions, and known bugs

import XCTest
@testable import HumanLogicaCore

final class EdgeCaseTests: XCTestCase {

    private func run(_ source: String) -> (output: [String], error: LogicaError?) {
        runLogicaProgram(source: source, quiet: true)
    }

    // MARK: - Empty Programs

    func testEmptyProgram() {
        let result = run("")
        XCTAssertNil(result.error)
        XCTAssertEqual(result.output.count, 0)
    }

    func testOnlySpeakerDecl() {
        let result = run("speaker Jared")
        XCTAssertNil(result.error)
    }

    func testOnlyComments() {
        let result = run("# just a comment\n# another comment")
        XCTAssertNil(result.error)
    }

    // MARK: - String Edge Cases

    func testEmptyString() {
        let result = run("""
        speaker X
        as X {
            let s = ""
            speak s
        }
        """)
        XCTAssertNil(result.error)
    }

    func testStringWithEscapedQuotes() {
        let result = run("""
        speaker X
        as X {
            let s = "he said \\"hello\\""
            speak s
        }
        """)
        XCTAssertNil(result.error)
    }

    // MARK: - Numeric Edge Cases

    func testZero() {
        let result = run("""
        speaker X
        as X {
            let z = 0
            speak z
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("0") })
    }

    func testNegativeNumber() {
        let result = run("""
        speaker X
        as X {
            let n = -42
            speak n
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("-42") })
    }

    func testModuloByZero() {
        let result = run("""
        speaker X
        as X {
            let r = 10 % 0
            speak r
        }
        """)
        XCTAssertNil(result.error)
        // Should return nil (guarded by r != 0)
    }

    // MARK: - None/Nil Handling

    func testNoneLiteral() {
        let result = run("""
        speaker X
        as X {
            let x = none
            if x == none {
                speak "is none"
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("is none") })
    }

    // MARK: - Deeply Nested Structures

    func testNestedIfStatements() {
        let result = run("""
        speaker X
        as X {
            let a = 1
            if a == 1 {
                if a == 1 {
                    if a == 1 {
                        speak "deep"
                    }
                }
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("deep") })
    }

    func testNestedWhenBlocks() {
        let result = run("""
        speaker X
        as X {
            let a = true
            when a {
                when a {
                    speak "nested when"
                }
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("nested when") })
    }

    // MARK: - Function Edge Cases

    func testFunctionNoParams() {
        let result = run("""
        speaker X
        as X {
            fn greet() {
                speak "hello"
            }
            greet()
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("hello") })
    }

    func testFunctionNoReturn() {
        let result = run("""
        speaker X
        as X {
            fn sideEffect() {
                speak "effect"
            }
            let r = sideEffect()
            speak r
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("effect") })
    }

    // MARK: - Multiple As Blocks Same Speaker

    func testMultipleAsBlocksSameSpeaker() {
        let result = run("""
        speaker X
        as X {
            let count = 1
            speak count
        }
        as X {
            let count = count + 1
            speak count
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("1") })
        XCTAssertTrue(result.output.contains { $0.contains("2") })
    }

    // MARK: - Variable Shadowing in Functions

    func testVariableShadowingInFunction() {
        let result = run("""
        speaker X
        as X {
            let x = 10
            fn getX() {
                return x
            }
            let r = getX()
            speak r
        }
        """)
        XCTAssertNil(result.error)
        // Function should NOT see the outer 'x' through local scope
        // It reads from Mary's memory instead
    }

    // MARK: - Ledger Integrity After Operations

    func testLedgerIntegrityAfterManyOps() {
        let result = run("""
        speaker X
        as X {
            let a = 1
            let b = 2
            let c = 3
            let d = a + b + c
            speak d
            verify ledger
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("6") })
        XCTAssertTrue(result.output.contains { $0.contains("VALID") })
    }

    // MARK: - Status Literals

    func testStatusLiterals() {
        let result = run("""
        speaker X
        as X {
            let s = active
            speak s
            let s2 = inactive
            speak s2
            let s3 = broken
            speak s3
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("active") })
        XCTAssertTrue(result.output.contains { $0.contains("inactive") })
        XCTAssertTrue(result.output.contains { $0.contains("broken") })
    }

    // MARK: - Whitespace Handling

    func testExtraNewlines() {
        let result = run("""
        speaker X


        as X {

            speak "hello"

        }

        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("hello") })
    }

    // MARK: - World Declaration

    func testWorldDecl() {
        let result = run("""
        speaker X
        as X {
            world Classroom
            speak "world created"
        }
        """)
        XCTAssertNil(result.error)
    }

    // MARK: - Inspect and History

    func testInspectAndHistory() {
        let result = run("""
        speaker X
        as X {
            let name = "first"
            let name = "second"
            inspect X
            history X.name
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertGreaterThan(result.output.count, 0)
    }

    // MARK: - Ledger Display

    func testLedgerLastN() {
        let result = run("""
        speaker X
        as X {
            let a = 1
            let b = 2
            ledger last 3
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertGreaterThan(result.output.count, 0)
    }

    // MARK: - Request to Non-Existent Speaker at Runtime

    func testRequestToUndeclaredAtRuntime() {
        // Parser allows any identifier as target, compiler should catch it
        let result = run("""
        speaker X
        as X {
            request Ghost "hello"
        }
        """)
        XCTAssertNotNil(result.error) // Should fail at compile
    }

    // MARK: - Complex Expression Precedence

    func testOperatorPrecedence() {
        let result = run("""
        speaker X
        as X {
            let r = 2 + 3 * 4
            speak r
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("14") }) // Not 20
    }

    func testParenthesizedExpression() {
        let result = run("""
        speaker X
        as X {
            let r = (2 + 3) * 4
            speak r
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("20") })
    }

    // MARK: - Boolean Edge Cases

    func testTruthyValues() {
        let result = run("""
        speaker X
        as X {
            if 1 {
                speak "int truthy"
            }
            if "non-empty" {
                speak "string truthy"
            }
            if 0 {
                speak "WRONG"
            } else {
                speak "zero falsy"
            }
            if "" {
                speak "WRONG"
            } else {
                speak "empty string falsy"
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("int truthy") })
        XCTAssertTrue(result.output.contains { $0.contains("string truthy") })
        XCTAssertTrue(result.output.contains { $0.contains("zero falsy") })
        XCTAssertTrue(result.output.contains { $0.contains("empty string falsy") })
    }

    // MARK: - SHA-256 Hash

    func testSHA256Prefix() {
        let hash1 = "hello".sha256Prefix(16)
        let hash2 = "hello".sha256Prefix(16)
        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
        XCTAssertEqual(hash1.count, 16, "Hash prefix length should match requested length")

        let hash3 = "world".sha256Prefix(16)
        XCTAssertNotEqual(hash1, hash3, "Different inputs should produce different hashes")
    }

    func testSHA256EmptyString() {
        let hash = "".sha256Prefix(16)
        XCTAssertEqual(hash.count, 16)
    }

    // MARK: - Tokenize Helper

    func testTokenizeHelper() {
        let (tokens, error) = tokenizeLogica(source: "speaker Jared")
        XCTAssertNil(error)
        XCTAssertGreaterThan(tokens.count, 0)
    }

    func testCheckHelper() {
        let error = checkLogicaProgram(source: """
        speaker X
        as X {
            speak "valid"
        }
        """)
        XCTAssertNil(error)
    }

    func testCheckHelperWithViolation() {
        let error = checkLogicaProgram(source: """
        speaker X
        as X {
            while true {
                speak "infinite"
            }
        }
        """)
        XCTAssertNotNil(error)
    }
}
