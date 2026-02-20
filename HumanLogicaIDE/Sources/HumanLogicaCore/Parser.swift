// Parser.swift — Source Text to Abstract Syntax Tree
// Recursive descent parser for Logica. Consumes tokens, produces AST.

import Foundation

public class Parser {
    private let tokens: [Token]
    private var pos: Int = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    // MARK: - Utilities

    private func current() -> Token {
        guard pos < tokens.count else {
            return Token(type: .eof, value: "", line: 0, col: 0)
        }
        return tokens[pos]
    }

    private func peek(offset: Int = 0) -> Token {
        let idx = pos + offset
        guard idx < tokens.count else {
            return Token(type: .eof, value: "", line: 0, col: 0)
        }
        return tokens[idx]
    }

    @discardableResult
    private func advance() -> Token {
        let token = current()
        pos += 1
        return token
    }

    @discardableResult
    private func expect(_ type: TokenType) throws -> Token {
        let token = current()
        guard token.type == type else {
            throw LogicaError.parseError(
                message: "expected \(type.rawValue), got \(token.type.rawValue) ('\(token.value)')",
                line: token.line, col: token.col
            )
        }
        return advance()
    }

    private func match(_ types: TokenType...) -> Bool {
        types.contains(current().type)
    }

    private func skipNewlines() {
        while match(.newline) {
            advance()
        }
    }

    private var atEnd: Bool {
        current().type == .eof
    }

    // MARK: - Top-Level

    public func parse() throws -> Program {
        let program = Program()
        skipNewlines()
        while !atEnd {
            if let stmt = try parseStatement() {
                program.statements.append(stmt)
            }
            skipNewlines()
        }
        return program
    }

    // MARK: - Statements

    private func parseStatement() throws -> ASTNode? {
        skipNewlines()
        guard !atEnd else { return nil }

        let token = current()

        switch token.type {
        case .speaker: return try parseSpeakerDecl()
        case .world: return try parseWorldDecl()
        case .as: return try parseAsBlock()
        case .let: return try parseLet()
        case .speak: return try parseSpeak()
        case .when: return try parseWhen()
        case .if: return try parseIf()
        case .while: return try parseWhile()
        case .fn: return try parseFn()
        case .return: return try parseReturn()
        case .request: return try parseRequest()
        case .respond: return try parseRespond()
        case .inspect: return try parseInspect()
        case .history: return try parseHistory()
        case .ledger: return try parseLedger()
        case .verify: return try parseVerify()
        case .seal: return try parseSeal()
        case .pass: return try parsePass()
        case .fail: return try parseFail()
        default: return try parseExprStatement()
        }
    }

    private func parseSpeakerDecl() throws -> SpeakerDecl {
        let token = try expect(.speaker)
        let nameToken = try expect(.identifier)
        consumeTerminator()
        return SpeakerDecl(name: nameToken.value, line: token.line, col: token.col)
    }

    private func parseWorldDecl() throws -> WorldDecl {
        let token = try expect(.world)
        let nameToken = try expect(.identifier)
        var args: [ASTNode] = []
        if match(.lparen) {
            advance()
            while !match(.rparen) {
                args.append(try parseExpression())
                if match(.comma) { advance() }
            }
            try expect(.rparen)
        }
        consumeTerminator()
        return WorldDecl(name: nameToken.value, args: args, line: token.line, col: token.col)
    }

    private func parseAsBlock() throws -> AsBlock {
        let token = try expect(.as)
        let nameToken = try expect(.identifier)
        skipNewlines()
        try expect(.lbrace)
        let body = try parseBlockBody()
        try expect(.rbrace)
        return AsBlock(speakerName: nameToken.value, body: body, line: token.line, col: token.col)
    }

    private func parseLet() throws -> LetStatement {
        let token = try expect(.let)
        var nameParts = [try expect(.identifier).value]
        while match(.dot) {
            advance()
            nameParts.append(try expect(.identifier).value)
        }
        let name = nameParts.joined(separator: ".")

        if match(.lbracket) {
            advance()
            _ = try parseExpression()
            try expect(.rbracket)
        }

        try expect(.assign)
        let value = try parseExpression()
        consumeTerminator()
        return LetStatement(name: name, value: value, line: token.line, col: token.col)
    }

    private func parseSpeak() throws -> SpeakStatement {
        let token = try expect(.speak)
        let value = try parseExpression()
        consumeTerminator()
        return SpeakStatement(value: value, line: token.line, col: token.col)
    }

    private func parseWhen() throws -> WhenBlock {
        let token = try expect(.when)
        let condition = try parseExpression()
        skipNewlines()
        try expect(.lbrace)
        let body = try parseBlockBody()
        try expect(.rbrace)

        var otherwiseBody: [ASTNode] = []
        var brokenBody: [ASTNode] = []

        skipNewlines()
        if match(.otherwise) {
            advance()
            skipNewlines()
            try expect(.lbrace)
            otherwiseBody = try parseBlockBody()
            try expect(.rbrace)
        }

        skipNewlines()
        if match(.broken) {
            advance()
            skipNewlines()
            try expect(.lbrace)
            brokenBody = try parseBlockBody()
            try expect(.rbrace)
        }

        return WhenBlock(condition: condition, body: body, otherwiseBody: otherwiseBody,
                         brokenBody: brokenBody, line: token.line, col: token.col)
    }

    private func parseIf() throws -> IfStatement {
        let token = try expect(.if)
        let condition = try parseExpression()
        skipNewlines()
        try expect(.lbrace)
        let body = try parseBlockBody()
        try expect(.rbrace)

        var elifClauses: [ElifClause] = []
        var elseBody: [ASTNode] = []

        while true {
            skipNewlines()
            if match(.elif) {
                let elifToken = advance()
                let elifCond = try parseExpression()
                skipNewlines()
                try expect(.lbrace)
                let elifBody = try parseBlockBody()
                try expect(.rbrace)
                elifClauses.append(ElifClause(condition: elifCond, body: elifBody,
                                              line: elifToken.line, col: elifToken.col))
            } else {
                break
            }
        }

        skipNewlines()
        if match(.else) {
            advance()
            skipNewlines()
            try expect(.lbrace)
            elseBody = try parseBlockBody()
            try expect(.rbrace)
        }

        return IfStatement(condition: condition, body: body, elifClauses: elifClauses,
                           elseBody: elseBody, line: token.line, col: token.col)
    }

    private func parseWhile() throws -> WhileLoop {
        let token = try expect(.while)
        let condition = try parseExpression()

        var maxIterations: ASTNode? = nil
        if match(.comma) {
            advance()
            try expect(.max)
            maxIterations = try parseExpression()
        }

        skipNewlines()
        try expect(.lbrace)
        let body = try parseBlockBody()
        try expect(.rbrace)

        return WhileLoop(condition: condition, body: body, maxIterations: maxIterations,
                         line: token.line, col: token.col)
    }

    private func parseFn() throws -> FnDecl {
        let token = try expect(.fn)
        let name = try expect(.identifier).value
        try expect(.lparen)

        var params: [String] = []
        while !match(.rparen) {
            params.append(try expect(.identifier).value)
            if match(.comma) { advance() }
        }
        try expect(.rparen)

        skipNewlines()
        try expect(.lbrace)
        let body = try parseBlockBody()
        try expect(.rbrace)

        return FnDecl(name: name, params: params, body: body, line: token.line, col: token.col)
    }

    private func parseReturn() throws -> ReturnStatement {
        let token = try expect(.return)
        var value: ASTNode? = nil
        if !match(.newline, .rbrace, .eof) {
            value = try parseExpression()
        }
        consumeTerminator()
        return ReturnStatement(value: value, line: token.line, col: token.col)
    }

    private func parseRequest() throws -> RequestStatement {
        let token = try expect(.request)
        let target = try expect(.identifier).value
        let action = try parseExpression()
        consumeTerminator()
        return RequestStatement(target: target, action: action, line: token.line, col: token.col)
    }

    private func parseRespond() throws -> RespondStatement {
        let token = try expect(.respond)
        var accept = true
        if match(.accept) {
            advance()
        } else if match(.refuse) {
            advance()
            accept = false
        }
        consumeTerminator()
        return RespondStatement(accept: accept, line: token.line, col: token.col)
    }

    private func parseInspect() throws -> InspectStatement {
        let token = try expect(.inspect)
        let target = try parseExpression()
        consumeTerminator()
        return InspectStatement(target: target, line: token.line, col: token.col)
    }

    private func parseHistory() throws -> HistoryStatement {
        let token = try expect(.history)
        let target = try parseExpression()
        consumeTerminator()
        return HistoryStatement(target: target, line: token.line, col: token.col)
    }

    private func parseLedger() throws -> LedgerStatement {
        let token = try expect(.ledger)
        var count: ASTNode? = nil
        if match(.identifier) && current().value == "last" {
            advance()
            count = try parseExpression()
        } else if match(.integer) {
            count = try parseExpression()
        }
        consumeTerminator()
        return LedgerStatement(count: count, line: token.line, col: token.col)
    }

    private func parseVerify() throws -> VerifyStatement {
        let token = try expect(.verify)
        if match(.ledger) { advance() }
        consumeTerminator()
        return VerifyStatement(line: token.line, col: token.col)
    }

    private func parseSeal() throws -> SealStatement {
        let token = try expect(.seal)
        let name = try expect(.identifier).value
        consumeTerminator()
        return SealStatement(target: name, line: token.line, col: token.col)
    }

    private func parsePass() throws -> PassStatement {
        let token = try expect(.pass)
        consumeTerminator()
        return PassStatement(line: token.line, col: token.col)
    }

    private func parseFail() throws -> FailStatement {
        let token = try expect(.fail)
        var reason: ASTNode? = nil
        if !match(.newline, .rbrace, .eof) {
            reason = try parseExpression()
        }
        consumeTerminator()
        return FailStatement(reason: reason, line: token.line, col: token.col)
    }

    private func parseExprStatement() throws -> ExpressionStatement {
        let expr = try parseExpression()
        consumeTerminator()
        return ExpressionStatement(expression: expr, line: expr.line, col: expr.col)
    }

    // MARK: - Block Parsing

    private func parseBlockBody() throws -> [ASTNode] {
        var statements: [ASTNode] = []
        skipNewlines()
        while !match(.rbrace) && !atEnd {
            if let stmt = try parseStatement() {
                statements.append(stmt)
            }
            skipNewlines()
        }
        return statements
    }

    // MARK: - Expressions

    private func parseExpression() throws -> ASTNode {
        try parseOr()
    }

    private func parseOr() throws -> ASTNode {
        var left = try parseAnd()
        while match(.or) {
            let opToken = advance()
            let right = try parseAnd()
            left = BinaryOp(left: left, op: "or", right: right, line: opToken.line, col: opToken.col)
        }
        return left
    }

    private func parseAnd() throws -> ASTNode {
        var left = try parseNot()
        while match(.and) {
            let opToken = advance()
            let right = try parseNot()
            left = BinaryOp(left: left, op: "and", right: right, line: opToken.line, col: opToken.col)
        }
        return left
    }

    private func parseNot() throws -> ASTNode {
        if match(.not) {
            let opToken = advance()
            let operand = try parseNot()
            return UnaryOp(op: "not", operand: operand, line: opToken.line, col: opToken.col)
        }
        return try parseComparison()
    }

    private func parseComparison() throws -> ASTNode {
        var left = try parseAddition()
        while match(.eq, .neq, .lt, .gt, .lte, .gte) {
            let opToken = advance()
            let right = try parseAddition()
            left = BinaryOp(left: left, op: opToken.value, right: right, line: opToken.line, col: opToken.col)
        }
        return left
    }

    private func parseAddition() throws -> ASTNode {
        var left = try parseMultiplication()
        while match(.plus, .minus) {
            let opToken = advance()
            let right = try parseMultiplication()
            left = BinaryOp(left: left, op: opToken.value, right: right, line: opToken.line, col: opToken.col)
        }
        return left
    }

    private func parseMultiplication() throws -> ASTNode {
        var left = try parseUnary()
        while match(.star, .slash, .percent) {
            let opToken = advance()
            let right = try parseUnary()
            left = BinaryOp(left: left, op: opToken.value, right: right, line: opToken.line, col: opToken.col)
        }
        return left
    }

    private func parseUnary() throws -> ASTNode {
        if match(.minus) {
            let opToken = advance()
            let operand = try parseUnary()
            return UnaryOp(op: "-", operand: operand, line: opToken.line, col: opToken.col)
        }
        return try parsePostfix()
    }

    private func parsePostfix() throws -> ASTNode {
        var expr = try parsePrimary()

        while true {
            if match(.dot) {
                advance()
                let member = try expect(.identifier)
                expr = MemberAccess(object: expr, member: member.value, line: member.line, col: member.col)
            } else if match(.lparen) {
                advance()
                var args: [ASTNode] = []
                while !match(.rparen) {
                    args.append(try parseExpression())
                    if match(.comma) { advance() }
                }
                try expect(.rparen)
                expr = FnCall(function: expr, args: args, line: expr.line, col: expr.col)
            } else if match(.lbracket) {
                advance()
                let index = try parseExpression()
                try expect(.rbracket)
                expr = IndexAccess(object: expr, index: index, line: expr.line, col: expr.col)
            } else {
                break
            }
        }
        return expr
    }

    private func parsePrimary() throws -> ASTNode {
        let token = current()

        switch token.type {
        case .integer:
            advance()
            return IntegerLiteral(value: Int(token.value)!, line: token.line, col: token.col)
        case .float:
            advance()
            return FloatLiteral(value: Double(token.value)!, line: token.line, col: token.col)
        case .string:
            advance()
            return StringLiteral(value: token.value, line: token.line, col: token.col)
        case .true, .false:
            advance()
            return BooleanLiteral(value: token.type == .true, line: token.line, col: token.col)
        case .none:
            advance()
            return NoneLiteral(line: token.line, col: token.col)
        case .active:
            advance()
            return StatusLiteral(value: "active", line: token.line, col: token.col)
        case .inactive:
            advance()
            return StatusLiteral(value: "inactive", line: token.line, col: token.col)
        case .broken:
            advance()
            return StatusLiteral(value: "broken", line: token.line, col: token.col)
        case .read:
            advance()
            let target = try parsePostfix()
            return ReadExpr(target: target, line: token.line, col: token.col)
        case .identifier:
            advance()
            return Identifier(name: token.value, line: token.line, col: token.col)
        case .lparen:
            advance()
            let expr = try parseExpression()
            try expect(.rparen)
            return expr
        default:
            throw LogicaError.parseError(
                message: "unexpected token: '\(token.value)'",
                line: token.line, col: token.col
            )
        }
    }

    // MARK: - Helpers

    private func consumeTerminator() {
        if match(.newline) {
            while match(.newline) { advance() }
        }
        // else: allow missing terminator (end of block/file)
    }
}
