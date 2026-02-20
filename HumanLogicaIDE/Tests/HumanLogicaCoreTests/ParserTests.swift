// ParserTests.swift — Tests for Logica Parser

import XCTest
@testable import HumanLogicaCore

final class ParserTests: XCTestCase {

    private func parse(_ source: String) throws -> Program {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        return try parser.parse()
    }

    // MARK: - Speaker Declarations

    func testSpeakerDecl() throws {
        let program = try parse("speaker Jared")
        XCTAssertEqual(program.statements.count, 1)
        let decl = program.statements[0] as? SpeakerDecl
        XCTAssertNotNil(decl)
        XCTAssertEqual(decl?.name, "Jared")
    }

    func testMultipleSpeakers() throws {
        let program = try parse("speaker Jared\nspeaker Maria")
        XCTAssertEqual(program.statements.count, 2)
        let decl1 = program.statements[0] as? SpeakerDecl
        let decl2 = program.statements[1] as? SpeakerDecl
        XCTAssertEqual(decl1?.name, "Jared")
        XCTAssertEqual(decl2?.name, "Maria")
    }

    // MARK: - As Blocks

    func testAsBlock() throws {
        let program = try parse("""
        speaker Jared
        as Jared {
            speak "hello"
        }
        """)
        XCTAssertEqual(program.statements.count, 2)
        let asBlock = program.statements[1] as? AsBlock
        XCTAssertNotNil(asBlock)
        XCTAssertEqual(asBlock?.speakerName, "Jared")
        XCTAssertEqual(asBlock?.body.count, 1)
    }

    // MARK: - Let Statements

    func testLetStatement() throws {
        let program = try parse("""
        speaker X
        as X {
            let name = "hello"
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as? LetStatement
        XCTAssertNotNil(letStmt)
        XCTAssertEqual(letStmt?.name, "name")
        XCTAssertTrue(letStmt?.value is StringLiteral)
    }

    func testLetDottedName() throws {
        let program = try parse("""
        speaker X
        as X {
            let person.name = "Jared"
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as? LetStatement
        XCTAssertEqual(letStmt?.name, "person.name")
    }

    // MARK: - Speak Statements

    func testSpeakLiteral() throws {
        let program = try parse("""
        speaker X
        as X {
            speak "Hello"
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let speak = asBlock.body[0] as? SpeakStatement
        XCTAssertNotNil(speak)
        XCTAssertTrue(speak?.value is StringLiteral)
    }

    // MARK: - When Blocks

    func testWhenBlock() throws {
        let program = try parse("""
        speaker X
        as X {
            when true {
                speak "active"
            } otherwise {
                speak "inactive"
            } broken {
                speak "broken"
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let when = asBlock.body[0] as? WhenBlock
        XCTAssertNotNil(when)
        XCTAssertEqual(when?.body.count, 1)
        XCTAssertEqual(when?.otherwiseBody.count, 1)
        XCTAssertEqual(when?.brokenBody.count, 1)
    }

    func testWhenBlockWithoutOtherwise() throws {
        let program = try parse("""
        speaker X
        as X {
            when true {
                speak "yes"
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let when = asBlock.body[0] as? WhenBlock
        XCTAssertNotNil(when)
        XCTAssertEqual(when?.otherwiseBody.count, 0)
        XCTAssertEqual(when?.brokenBody.count, 0)
    }

    // MARK: - If/Elif/Else

    func testIfStatement() throws {
        let program = try parse("""
        speaker X
        as X {
            if true {
                speak "yes"
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let ifStmt = asBlock.body[0] as? IfStatement
        XCTAssertNotNil(ifStmt)
        XCTAssertEqual(ifStmt?.body.count, 1)
        XCTAssertEqual(ifStmt?.elifClauses.count, 0)
        XCTAssertEqual(ifStmt?.elseBody.count, 0)
    }

    func testIfElif() throws {
        let program = try parse("""
        speaker X
        as X {
            let x = 5
            if x == 1 {
                speak "one"
            } elif x == 5 {
                speak "five"
            } else {
                speak "other"
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let ifStmt = asBlock.body[1] as? IfStatement
        XCTAssertNotNil(ifStmt)
        XCTAssertEqual(ifStmt?.elifClauses.count, 1)
        XCTAssertEqual(ifStmt?.elseBody.count, 1)
    }

    // MARK: - While Loops

    func testWhileLoop() throws {
        let program = try parse("""
        speaker X
        as X {
            let i = 0
            while i < 10, max 100 {
                let i = i + 1
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let whileLoop = asBlock.body[1] as? WhileLoop
        XCTAssertNotNil(whileLoop)
        XCTAssertNotNil(whileLoop?.maxIterations)
    }

    func testWhileLoopWithoutMax() throws {
        // Parser allows it; compiler should reject it
        let program = try parse("""
        speaker X
        as X {
            while true {
                speak "loop"
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let whileLoop = asBlock.body[0] as? WhileLoop
        XCTAssertNotNil(whileLoop)
        XCTAssertNil(whileLoop?.maxIterations) // parser allows, compiler catches
    }

    // MARK: - Functions

    func testFnDecl() throws {
        let program = try parse("""
        speaker X
        as X {
            fn add(a, b) {
                return a + b
            }
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let fn = asBlock.body[0] as? FnDecl
        XCTAssertNotNil(fn)
        XCTAssertEqual(fn?.name, "add")
        XCTAssertEqual(fn?.params, ["a", "b"])
        XCTAssertEqual(fn?.body.count, 1)
    }

    // MARK: - Expressions

    func testBinaryExpression() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = 1 + 2 * 3
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        // Should parse as 1 + (2 * 3) due to precedence
        let add = letStmt.value as? BinaryOp
        XCTAssertNotNil(add)
        XCTAssertEqual(add?.op, "+")
        XCTAssertTrue(add?.left is IntegerLiteral)
        XCTAssertTrue(add?.right is BinaryOp)
        let mul = add?.right as? BinaryOp
        XCTAssertEqual(mul?.op, "*")
    }

    func testComparisonExpression() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = x >= 10
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        let cmp = letStmt.value as? BinaryOp
        XCTAssertEqual(cmp?.op, ">=")
    }

    func testUnaryNegation() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = -5
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        let unary = letStmt.value as? UnaryOp
        XCTAssertNotNil(unary)
        XCTAssertEqual(unary?.op, "-")
    }

    func testNotExpression() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = not true
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        let unary = letStmt.value as? UnaryOp
        XCTAssertEqual(unary?.op, "not")
    }

    func testFunctionCall() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = add(1, 2)
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        let call = letStmt.value as? FnCall
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.args.count, 2)
    }

    func testMemberAccess() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = obj.field
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        let access = letStmt.value as? MemberAccess
        XCTAssertNotNil(access)
        XCTAssertEqual(access?.member, "field")
    }

    func testIndexAccess() throws {
        let program = try parse("""
        speaker X
        as X {
            let r = arr[0]
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let letStmt = asBlock.body[0] as! LetStatement
        let access = letStmt.value as? IndexAccess
        XCTAssertNotNil(access)
    }

    // MARK: - Communication

    func testRequestStatement() throws {
        let program = try parse("""
        speaker X
        speaker Y
        as X {
            request Y "do_something"
        }
        """)
        let asBlock = program.statements[2] as! AsBlock
        let req = asBlock.body[0] as? RequestStatement
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.target, "Y")
    }

    func testRespondAccept() throws {
        let program = try parse("""
        speaker X
        as X {
            respond accept
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let resp = asBlock.body[0] as? RespondStatement
        XCTAssertNotNil(resp)
        XCTAssertTrue(resp!.accept)
    }

    func testRespondRefuse() throws {
        let program = try parse("""
        speaker X
        as X {
            respond refuse
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let resp = asBlock.body[0] as? RespondStatement
        XCTAssertNotNil(resp)
        XCTAssertFalse(resp!.accept)
    }

    // MARK: - Inspection & Ledger

    func testInspect() throws {
        let program = try parse("""
        speaker X
        as X {
            inspect X
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        XCTAssertTrue(asBlock.body[0] is InspectStatement)
    }

    func testHistory() throws {
        let program = try parse("""
        speaker X
        as X {
            history X.name
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        XCTAssertTrue(asBlock.body[0] is HistoryStatement)
    }

    func testVerify() throws {
        let program = try parse("""
        speaker X
        as X {
            verify ledger
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        XCTAssertTrue(asBlock.body[0] is VerifyStatement)
    }

    func testSeal() throws {
        let program = try parse("""
        speaker X
        as X {
            seal myVar
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let seal = asBlock.body[0] as? SealStatement
        XCTAssertEqual(seal?.target, "myVar")
    }

    func testPassStatement() throws {
        let program = try parse("""
        speaker X
        as X {
            pass
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        XCTAssertTrue(asBlock.body[0] is PassStatement)
    }

    func testFailStatement() throws {
        let program = try parse("""
        speaker X
        as X {
            fail "something went wrong"
        }
        """)
        let asBlock = program.statements[1] as! AsBlock
        let fail = asBlock.body[0] as? FailStatement
        XCTAssertNotNil(fail)
        XCTAssertNotNil(fail?.reason)
    }

    // MARK: - Error Cases

    func testUnexpectedToken() {
        XCTAssertThrowsError(try parse("+ +")) { error in
            guard case LogicaError.parseError = error else {
                XCTFail("Expected parseError")
                return
            }
        }
    }
}
