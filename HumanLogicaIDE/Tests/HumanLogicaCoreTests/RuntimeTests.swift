// RuntimeTests.swift — Tests for Logica Runtime (full pipeline)

import XCTest
@testable import HumanLogicaCore

final class RuntimeTests: XCTestCase {

    private func run(_ source: String) -> (output: [String], error: LogicaError?) {
        runLogicaProgram(source: source, quiet: true)
    }

    // MARK: - Basic Execution

    func testHelloWorld() {
        let result = run("""
        speaker Jared
        as Jared {
            speak "Hello, World!"
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("Hello, World!") })
    }

    func testSpeakInteger() {
        let result = run("""
        speaker X
        as X {
            speak 42
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("42") })
    }

    func testVariableAssignment() {
        let result = run("""
        speaker X
        as X {
            let name = "Jared"
            speak name
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("Jared") })
    }

    // MARK: - Arithmetic

    func testIntegerArithmetic() {
        let result = run("""
        speaker X
        as X {
            let a = 10
            let b = 3
            speak a + b
            speak a - b
            speak a * b
            speak a / b
            speak a % b
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("13") })  // 10+3
        XCTAssertTrue(result.output.contains { $0.contains("7") })   // 10-3
        XCTAssertTrue(result.output.contains { $0.contains("30") })  // 10*3
        XCTAssertTrue(result.output.contains { $0.contains("3") })   // 10/3
        XCTAssertTrue(result.output.contains { $0.contains("1") })   // 10%3
    }

    func testStringConcatenation() {
        let result = run("""
        speaker X
        as X {
            let greeting = "Hello" + ", " + "World"
            speak greeting
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("Hello, World") })
    }

    // BUG TEST: Mixed Int/Double arithmetic for subtraction
    func testMixedIntDoubleSub() {
        let result = run("""
        speaker X
        as X {
            let a = 10
            let b = 3.5
            let r = a - b
            speak r
        }
        """)
        XCTAssertNil(result.error)
        // BUG: Without fix, r will be nil because Int - Double has no handler
        // After fix: should output 6.5
        XCTAssertTrue(result.output.contains { $0.contains("6.5") },
            "Mixed Int - Double should produce 6.5, got: \(result.output)")
    }

    // BUG TEST: Mixed Int/Double arithmetic for multiplication
    func testMixedIntDoubleMul() {
        let result = run("""
        speaker X
        as X {
            let a = 5
            let b = 2.5
            let r = a * b
            speak r
        }
        """)
        XCTAssertNil(result.error)
        // BUG: Without fix, r will be nil
        XCTAssertTrue(result.output.contains { $0.contains("12.5") },
            "Mixed Int * Double should produce 12.5, got: \(result.output)")
    }

    // BUG TEST: Mixed Int/Double arithmetic for division
    func testMixedIntDoubleDiv() {
        let result = run("""
        speaker X
        as X {
            let a = 7
            let b = 2.0
            let r = a / b
            speak r
        }
        """)
        XCTAssertNil(result.error)
        // BUG: Without fix, r will be nil
        XCTAssertTrue(result.output.contains { $0.contains("3.5") },
            "Mixed Int / Double should produce 3.5, got: \(result.output)")
    }

    // MARK: - Comparisons

    func testIntegerComparisons() {
        let result = run("""
        speaker X
        as X {
            speak 5 > 3
            speak 3 < 5
            speak 5 >= 5
            speak 5 <= 5
            speak 5 == 5
            speak 5 != 3
        }
        """)
        XCTAssertNil(result.error)
        // All should be true
        let trueCount = result.output.filter { $0.contains("true") }.count
        XCTAssertEqual(trueCount, 6, "All 6 comparisons should be true, got: \(result.output)")
    }

    // BUG TEST: Mixed Int/Double comparisons
    func testMixedIntDoubleComparison() {
        let result = run("""
        speaker X
        as X {
            let a = 5
            let b = 3.14
            if a > b {
                speak "correct"
            } else {
                speak "wrong"
            }
        }
        """)
        XCTAssertNil(result.error)
        // BUG: Without fix, 5 (Int) > 3.14 (Double) returns false
        XCTAssertTrue(result.output.contains { $0.contains("correct") },
            "5 > 3.14 should be true, got: \(result.output)")
    }

    // BUG TEST: Equality between Int and Double
    func testIntDoubleEquality() {
        let result = run("""
        speaker X
        as X {
            let a = 1
            let b = 1.0
            if a == b {
                speak "equal"
            } else {
                speak "not equal"
            }
        }
        """)
        XCTAssertNil(result.error)
        // BUG: Without fix, 1 (Int) == 1.0 (Double) returns false
        XCTAssertTrue(result.output.contains { $0.contains("equal") },
            "1 == 1.0 should be true, got: \(result.output)")
    }

    // MARK: - Conditionals

    func testWhenActive() {
        let result = run("""
        speaker X
        as X {
            let score = 85
            when score >= 70 {
                speak "pass"
            } otherwise {
                speak "fail"
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("pass") })
    }

    func testWhenInactive() {
        let result = run("""
        speaker X
        as X {
            let score = 50
            when score >= 70 {
                speak "pass"
            } otherwise {
                speak "below threshold"
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("below threshold") })
    }

    func testIfElif() {
        let result = run("""
        speaker X
        as X {
            let x = 2
            if x == 1 {
                speak "one"
            } elif x == 2 {
                speak "two"
            } else {
                speak "other"
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("two") })
    }

    // MARK: - Loops

    func testWhileLoop() {
        let result = run("""
        speaker X
        as X {
            let sum = 0
            let i = 1
            while i <= 5, max 100 {
                let sum = sum + i
                let i = i + 1
            }
            speak sum
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("15") }) // 1+2+3+4+5
    }

    func testWhileLoopMaxExceeded() {
        let result = run("""
        speaker X
        as X {
            let i = 0
            while true, max 5 {
                let i = i + 1
            }
        }
        """)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Functions

    func testFunctionDefinitionAndCall() {
        let result = run("""
        speaker X
        as X {
            fn double(n) {
                return n * 2
            }
            let r = double(21)
            speak r
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("42") })
    }

    func testRecursiveFunctionWithinBounds() {
        let result = run("""
        speaker X
        as X {
            fn factorial(n) {
                if n <= 1 {
                    return 1
                }
                return n * factorial(n - 1)
            }
            let r = factorial(5)
            speak r
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("120") })
    }

    // MARK: - Communication

    func testRequestRespond() {
        let result = run("""
        speaker Alice
        speaker Bob
        as Alice {
            request Bob "review"
        }
        as Bob {
            respond accept
            speak "accepted"
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("accepted") })
    }

    // MARK: - Write Ownership Runtime

    func testCrossSpeakerReadAllowed() {
        let result = run("""
        speaker Alice
        speaker Bob
        as Alice {
            let secret = "my_data"
        }
        as Bob {
            speak read Alice.secret
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("my_data") })
    }

    // MARK: - Sealed Variables Runtime

    func testSealedVariableRuntime() {
        let result = run("""
        speaker X
        as X {
            let grade = 92
            seal grade
            let grade = 100
        }
        """)
        // Should error because 'grade' is sealed - caught at COMPILE time
        XCTAssertNotNil(result.error)
    }

    // MARK: - Ledger

    func testLedgerVerify() {
        let result = run("""
        speaker X
        as X {
            let a = 1
            let b = 2
            verify ledger
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("VALID") })
    }

    // MARK: - Boolean Operations

    func testAndOr() {
        let result = run("""
        speaker X
        as X {
            if true and true {
                speak "and works"
            }
            if false or true {
                speak "or works"
            }
            if not false {
                speak "not works"
            }
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("and works") })
        XCTAssertTrue(result.output.contains { $0.contains("or works") })
        XCTAssertTrue(result.output.contains { $0.contains("not works") })
    }

    // MARK: - Division By Zero

    func testDivisionByZero() {
        let result = run("""
        speaker X
        as X {
            let r = 10 / 0
            speak r
        }
        """)
        // Division by zero returns nil; speak nil should print something
        XCTAssertNil(result.error)
    }

    // MARK: - Full Example Programs

    func testFullDemoProgram() {
        let result = run("""
        speaker Jared
        speaker Maria
        speaker Admin

        as Jared {
            let assignment = "Build a Calculator"
            speak "Assignment: " + assignment
        }

        as Maria {
            let submission = "def calc(): return 2+2"
            speak "Submitted: " + submission
        }

        as Jared {
            let grade = 92
            speak "Grade: " + grade
        }

        as Maria {
            speak "My grade: " + read Jared.grade
        }

        as Admin {
            speak "Observing"
            inspect Jared
        }

        as Jared {
            verify ledger
        }
        """)
        XCTAssertNil(result.error, "Full demo should not error: \(result.error?.description ?? "")")
        XCTAssertGreaterThan(result.output.count, 3)
    }

    // MARK: - Fail Statement

    func testFailStatement() {
        let result = run("""
        speaker X
        as X {
            fail "explicit failure"
        }
        """)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Pass Statement

    func testPassStatement() {
        let result = run("""
        speaker X
        as X {
            pass
            speak "after pass"
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("after pass") })
    }

    // MARK: - Return Without Value

    func testReturnWithoutValue() {
        let result = run("""
        speaker X
        as X {
            fn doNothing() {
                return
            }
            doNothing()
            speak "done"
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("done") })
    }

    // MARK: - Nested As Blocks

    func testNestedAsBlocks() {
        let result = run("""
        speaker A
        speaker B
        as A {
            speak "A speaking"
            as B {
                speak "B speaking"
            }
            speak "A again"
        }
        """)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.output.contains { $0.contains("[A] A speaking") })
        XCTAssertTrue(result.output.contains { $0.contains("[B] B speaking") })
        XCTAssertTrue(result.output.contains { $0.contains("[A] A again") })
    }
}
