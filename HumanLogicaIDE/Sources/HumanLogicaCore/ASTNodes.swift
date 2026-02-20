// ASTNodes.swift — The Shape of a Program
// Every node knows its speaker. Every node knows its line.
// The tree is the program. The program is a sequence of expressions.

import Foundation

// MARK: - Base

public class ASTNode {
    public var line: Int
    public var col: Int

    public init(line: Int = 0, col: Int = 0) {
        self.line = line
        self.col = col
    }
}

// MARK: - Program

/// The root. A program is a sequence of top-level statements.
public class Program: ASTNode {
    public var statements: [ASTNode] = []

    public override init(line: Int = 0, col: Int = 0) {
        super.init(line: line, col: col)
    }
}

// MARK: - Top-Level Declarations

/// speaker Name
public class SpeakerDecl: ASTNode {
    public let name: String

    public init(name: String, line: Int = 0, col: Int = 0) {
        self.name = name
        super.init(line: line, col: col)
    }
}

/// world Name(args)
public class WorldDecl: ASTNode {
    public let name: String
    public let args: [ASTNode]

    public init(name: String, args: [ASTNode] = [], line: Int = 0, col: Int = 0) {
        self.name = name
        self.args = args
        super.init(line: line, col: col)
    }
}

/// as SpeakerName { ... }
/// Every statement inside runs as this speaker.
/// This is identity. Not scope. Not context. Identity.
public class AsBlock: ASTNode {
    public let speakerName: String
    public let body: [ASTNode]

    public init(speakerName: String, body: [ASTNode], line: Int = 0, col: Int = 0) {
        self.speakerName = speakerName
        self.body = body
        super.init(line: line, col: col)
    }
}

// MARK: - Statements

/// let name = expr  /  let name[index] = expr
public class LetStatement: ASTNode {
    public let name: String
    public let value: ASTNode
    public let index: ASTNode?

    public init(name: String, value: ASTNode, index: ASTNode? = nil, line: Int = 0, col: Int = 0) {
        self.name = name
        self.value = value
        self.index = index
        super.init(line: line, col: col)
    }
}

/// speak expr
public class SpeakStatement: ASTNode {
    public let value: ASTNode

    public init(value: ASTNode, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// when condition { active } otherwise { inactive } broken { broken }
/// Three-way conditional. Not two. Three.
public class WhenBlock: ASTNode {
    public let condition: ASTNode
    public let body: [ASTNode]
    public let otherwiseBody: [ASTNode]
    public let brokenBody: [ASTNode]

    public init(condition: ASTNode, body: [ASTNode], otherwiseBody: [ASTNode] = [],
                brokenBody: [ASTNode] = [], line: Int = 0, col: Int = 0) {
        self.condition = condition
        self.body = body
        self.otherwiseBody = otherwiseBody
        self.brokenBody = brokenBody
        super.init(line: line, col: col)
    }
}

/// if condition { ... } elif { ... } else { ... }
public class IfStatement: ASTNode {
    public let condition: ASTNode
    public let body: [ASTNode]
    public let elifClauses: [ElifClause]
    public let elseBody: [ASTNode]

    public init(condition: ASTNode, body: [ASTNode], elifClauses: [ElifClause] = [],
                elseBody: [ASTNode] = [], line: Int = 0, col: Int = 0) {
        self.condition = condition
        self.body = body
        self.elifClauses = elifClauses
        self.elseBody = elseBody
        super.init(line: line, col: col)
    }
}

public class ElifClause: ASTNode {
    public let condition: ASTNode
    public let body: [ASTNode]

    public init(condition: ASTNode, body: [ASTNode], line: Int = 0, col: Int = 0) {
        self.condition = condition
        self.body = body
        super.init(line: line, col: col)
    }
}

/// while condition, max N { ... }
public class WhileLoop: ASTNode {
    public let condition: ASTNode
    public let body: [ASTNode]
    public let maxIterations: ASTNode?

    public init(condition: ASTNode, body: [ASTNode], maxIterations: ASTNode? = nil,
                line: Int = 0, col: Int = 0) {
        self.condition = condition
        self.body = body
        self.maxIterations = maxIterations
        super.init(line: line, col: col)
    }
}

/// fn name(params) { body }
public class FnDecl: ASTNode {
    public let name: String
    public let params: [String]
    public let body: [ASTNode]

    public init(name: String, params: [String], body: [ASTNode], line: Int = 0, col: Int = 0) {
        self.name = name
        self.params = params
        self.body = body
        super.init(line: line, col: col)
    }
}

/// return expr
public class ReturnStatement: ASTNode {
    public let value: ASTNode?

    public init(value: ASTNode? = nil, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// request Target action
public class RequestStatement: ASTNode {
    public let target: String
    public let action: ASTNode
    public let data: ASTNode?

    public init(target: String, action: ASTNode, data: ASTNode? = nil, line: Int = 0, col: Int = 0) {
        self.target = target
        self.action = action
        self.data = data
        super.init(line: line, col: col)
    }
}

/// respond accept / respond refuse
public class RespondStatement: ASTNode {
    public let accept: Bool
    public let data: ASTNode?

    public init(accept: Bool = true, data: ASTNode? = nil, line: Int = 0, col: Int = 0) {
        self.accept = accept
        self.data = data
        super.init(line: line, col: col)
    }
}

/// inspect target
public class InspectStatement: ASTNode {
    public let target: ASTNode

    public init(target: ASTNode, line: Int = 0, col: Int = 0) {
        self.target = target
        super.init(line: line, col: col)
    }
}

/// history speaker.variable
public class HistoryStatement: ASTNode {
    public let target: ASTNode

    public init(target: ASTNode, line: Int = 0, col: Int = 0) {
        self.target = target
        super.init(line: line, col: col)
    }
}

/// ledger / ledger last N
public class LedgerStatement: ASTNode {
    public let count: ASTNode?

    public init(count: ASTNode? = nil, line: Int = 0, col: Int = 0) {
        self.count = count
        super.init(line: line, col: col)
    }
}

/// verify ledger
public class VerifyStatement: ASTNode {
    public let target: String

    public init(target: String = "ledger", line: Int = 0, col: Int = 0) {
        self.target = target
        super.init(line: line, col: col)
    }
}

/// seal variable
public class SealStatement: ASTNode {
    public let target: String

    public init(target: String, line: Int = 0, col: Int = 0) {
        self.target = target
        super.init(line: line, col: col)
    }
}

/// pass — do nothing
public class PassStatement: ASTNode {}

/// fail "reason"
public class FailStatement: ASTNode {
    public let reason: ASTNode?

    public init(reason: ASTNode? = nil, line: Int = 0, col: Int = 0) {
        self.reason = reason
        super.init(line: line, col: col)
    }
}

/// A bare expression used as a statement
public class ExpressionStatement: ASTNode {
    public let expression: ASTNode

    public init(expression: ASTNode, line: Int = 0, col: Int = 0) {
        self.expression = expression
        super.init(line: line, col: col)
    }
}

// MARK: - Expressions

/// Integer literal
public class IntegerLiteral: ASTNode {
    public let value: Int

    public init(value: Int, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// Float literal
public class FloatLiteral: ASTNode {
    public let value: Double

    public init(value: Double, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// String literal
public class StringLiteral: ASTNode {
    public let value: String

    public init(value: String, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// Boolean literal
public class BooleanLiteral: ASTNode {
    public let value: Bool

    public init(value: Bool, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// None literal
public class NoneLiteral: ASTNode {}

/// active, inactive, broken — the three values.
public class StatusLiteral: ASTNode {
    public let value: String

    public init(value: String, line: Int = 0, col: Int = 0) {
        self.value = value
        super.init(line: line, col: col)
    }
}

/// Identifier reference
public class Identifier: ASTNode {
    public let name: String

    public init(name: String, line: Int = 0, col: Int = 0) {
        self.name = name
        super.init(line: line, col: col)
    }
}

/// speaker.variable
public class MemberAccess: ASTNode {
    public let object: ASTNode
    public let member: String

    public init(object: ASTNode, member: String, line: Int = 0, col: Int = 0) {
        self.object = object
        self.member = member
        super.init(line: line, col: col)
    }
}

/// expr[key]
public class IndexAccess: ASTNode {
    public let object: ASTNode
    public let index: ASTNode

    public init(object: ASTNode, index: ASTNode, line: Int = 0, col: Int = 0) {
        self.object = object
        self.index = index
        super.init(line: line, col: col)
    }
}

/// expr op expr
public class BinaryOp: ASTNode {
    public let left: ASTNode
    public let op: String
    public let right: ASTNode

    public init(left: ASTNode, op: String, right: ASTNode, line: Int = 0, col: Int = 0) {
        self.left = left
        self.op = op
        self.right = right
        super.init(line: line, col: col)
    }
}

/// op expr
public class UnaryOp: ASTNode {
    public let op: String
    public let operand: ASTNode

    public init(op: String, operand: ASTNode, line: Int = 0, col: Int = 0) {
        self.op = op
        self.operand = operand
        super.init(line: line, col: col)
    }
}

/// name(args)
public class FnCall: ASTNode {
    public let function: ASTNode
    public let args: [ASTNode]

    public init(function: ASTNode, args: [ASTNode], line: Int = 0, col: Int = 0) {
        self.function = function
        self.args = args
        super.init(line: line, col: col)
    }
}

/// read Speaker.variable
public class ReadExpr: ASTNode {
    public let target: ASTNode

    public init(target: ASTNode, line: Int = 0, col: Int = 0) {
        self.target = target
        super.init(line: line, col: col)
    }
}
