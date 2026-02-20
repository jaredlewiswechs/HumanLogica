"""
Logica AST — The Shape of a Program
====================================

Every node knows its speaker. Every node knows its line.
The tree is the program. The program is a sequence of expressions.
"""

from dataclasses import dataclass, field
from typing import Optional, Any


# =============================================================================
# Base
# =============================================================================

@dataclass
class Node:
    """Base AST node. Every node has a source location."""
    line: int = 0
    col: int = 0


# =============================================================================
# Program
# =============================================================================

@dataclass
class Program(Node):
    """The root. A program is a sequence of top-level statements."""
    statements: list = field(default_factory=list)


# =============================================================================
# Top-Level Declarations
# =============================================================================

@dataclass
class SpeakerDecl(Node):
    """speaker Name"""
    name: str = ""


@dataclass
class WorldDecl(Node):
    """world Name(args)"""
    name: str = ""
    args: list = field(default_factory=list)


@dataclass
class AsBlock(Node):
    """
    as SpeakerName { ... }

    Every statement inside runs as this speaker.
    This is identity. Not scope. Not context. Identity.
    """
    speaker_name: str = ""
    body: list = field(default_factory=list)


# =============================================================================
# Statements
# =============================================================================

@dataclass
class LetStatement(Node):
    """
    let name = expr

    Write to the current speaker's partition.
    Axiom 8: You can only write to your own variables.
    """
    name: str = ""
    value: 'Expression' = None


@dataclass
class SpeakStatement(Node):
    """
    speak expr

    Output a value. The speaker says something.
    """
    value: 'Expression' = None


@dataclass
class WhenBlock(Node):
    """
    when condition {
        ... active path ...
    } otherwise {
        ... inactive path ...
    } broken {
        ... broken path ...
    }

    Three-way conditional. Not two. Three.
    Active: condition met, action fulfilled.
    Otherwise/Inactive: condition not met.
    Broken: condition met, action failed.
    """
    condition: 'Expression' = None
    body: list = field(default_factory=list)
    otherwise_body: list = field(default_factory=list)
    broken_body: list = field(default_factory=list)


@dataclass
class IfStatement(Node):
    """
    if condition { ... }
    elif condition { ... }
    else { ... }

    Sugar over when/otherwise. For familiar control flow.
    """
    condition: 'Expression' = None
    body: list = field(default_factory=list)
    elif_clauses: list = field(default_factory=list)  # list of (condition, body)
    else_body: list = field(default_factory=list)


@dataclass
class ElifClause(Node):
    """One elif branch."""
    condition: 'Expression' = None
    body: list = field(default_factory=list)


@dataclass
class WhileLoop(Node):
    """
    while condition, max N { ... }

    Axiom 9: Every loop must have a termination path or bound.
    The max clause is required if the compiler can't prove termination.
    """
    condition: 'Expression' = None
    body: list = field(default_factory=list)
    max_iterations: Optional['Expression'] = None


@dataclass
class FnDecl(Node):
    """
    fn name(params) { ... }

    Functions are owned by the speaker. Definition 14.5.
    """
    name: str = ""
    params: list = field(default_factory=list)
    body: list = field(default_factory=list)


@dataclass
class ReturnStatement(Node):
    """return expr"""
    value: Optional['Expression'] = None


@dataclass
class RequestStatement(Node):
    """
    request Target action_name
    request Target action_name with data

    Send a request to another speaker.
    This does NOT execute anything for the target.
    """
    target: str = ""
    action: 'Expression' = None
    data: Optional['Expression'] = None


@dataclass
class RespondStatement(Node):
    """
    respond accept
    respond refuse
    respond accept with data
    """
    accept: bool = True
    data: Optional['Expression'] = None


@dataclass
class InspectStatement(Node):
    """
    inspect target
    inspect target.var
    """
    target: 'Expression' = None


@dataclass
class HistoryStatement(Node):
    """
    history speaker.variable

    Every variable has a timeline. This accesses it.
    """
    target: 'Expression' = None


@dataclass
class LedgerStatement(Node):
    """
    ledger
    ledger last N

    View the append-only record.
    """
    count: Optional['Expression'] = None


@dataclass
class VerifyStatement(Node):
    """
    verify ledger

    Check the hash chain.
    """
    target: str = "ledger"


@dataclass
class SealStatement(Node):
    """
    seal variable

    Make a variable immutable. Once sealed, it cannot be overwritten.
    """
    target: str = ""


@dataclass
class PassStatement(Node):
    """pass — do nothing."""
    pass


@dataclass
class FailStatement(Node):
    """fail "reason" — explicitly break."""
    reason: Optional['Expression'] = None


@dataclass
class ExpressionStatement(Node):
    """A bare expression as a statement (function call, etc.)."""
    expression: 'Expression' = None


# =============================================================================
# Expressions
# =============================================================================

@dataclass
class Expression(Node):
    """Base expression."""
    pass


@dataclass
class IntegerLiteral(Expression):
    value: int = 0


@dataclass
class FloatLiteral(Expression):
    value: float = 0.0


@dataclass
class StringLiteral(Expression):
    value: str = ""


@dataclass
class BooleanLiteral(Expression):
    value: bool = True


@dataclass
class NoneLiteral(Expression):
    pass


@dataclass
class StatusLiteral(Expression):
    """active, inactive, broken — the three values."""
    value: str = "active"  # "active", "inactive", "broken"


@dataclass
class Identifier(Expression):
    name: str = ""


@dataclass
class MemberAccess(Expression):
    """
    speaker.variable

    Reading another speaker's variable is always allowed.
    Writing requires ownership (enforced at compile time).
    """
    object: Expression = None
    member: str = ""


@dataclass
class IndexAccess(Expression):
    """expr[key]"""
    object: Expression = None
    index: Expression = None


@dataclass
class BinaryOp(Expression):
    """expr op expr"""
    left: Expression = None
    op: str = ""
    right: Expression = None


@dataclass
class UnaryOp(Expression):
    """op expr"""
    op: str = ""
    operand: Expression = None


@dataclass
class FnCall(Expression):
    """name(args) or speaker.name(args)"""
    function: Expression = None
    args: list = field(default_factory=list)


@dataclass
class ReadExpr(Expression):
    """
    read Speaker.variable

    Explicit read from another speaker's partition.
    Always succeeds. Observation does not mutate.
    """
    target: Expression = None


@dataclass
class ConditionalExpr(Expression):
    """expr if condition else expr"""
    condition: Expression = None
    true_value: Expression = None
    false_value: Expression = None
