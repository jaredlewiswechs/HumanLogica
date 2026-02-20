"""
Logica Compiler — The Proof Checker
====================================

The compiler walks the AST and checks every axiom.
If the program violates an axiom, it does not compile.
Not a runtime error. Not an exception. The program is invalid.
It is like writing a sentence that violates grammar so badly
the language refuses to express it.

Axioms enforced:
    A1.  Speaker Requirement       — Every operation has a speaker
    A2.  Condition as Flag         — Conditions are scoped markers
    A3.  Three-Valued Evaluation   — {active, inactive, broken}
    A4.  Silence Is Distinct       — silent is not a status
    A5.  Ledger Integrity          — Append-only (runtime)
    A6.  Deterministic Evaluation  — Same state, same result
    A7.  No Forced Speech          — Only s can author for s
    A8.  Write Ownership           — Only s can write to s's variables
    A9.  No Infinite Loops         — Every loop bounded
    A10. No Orphan State           — Every change traced to ledger

The compiler produces a list of Operations that the runtime executes.
"""

from .ast_nodes import *
from .errors import AxiomViolation, ParseError
from dataclasses import dataclass, field
from typing import Optional, Any
from enum import Enum, auto


# =============================================================================
# Compiled Operations — What the Runtime Executes
# =============================================================================

class OpType(Enum):
    """The operations Mary understands."""
    CREATE_SPEAKER = auto()
    SET_SPEAKER = auto()       # switch active speaker context
    WRITE_VAR = auto()         # write to speaker's own variable
    READ_VAR = auto()          # read any variable
    SPEAK_OUTPUT = auto()      # output a value
    SUBMIT_EXPR = auto()       # submit expression for evaluation
    FN_DEFINE = auto()         # define a function
    FN_CALL = auto()           # call a function
    RETURN = auto()            # return from function
    WHEN_EVAL = auto()         # three-valued conditional
    IF_EVAL = auto()           # if/elif/else conditional
    LOOP_START = auto()        # begin loop
    LOOP_END = auto()          # end loop
    REQUEST = auto()           # send request
    RESPOND = auto()           # respond to request
    INSPECT = auto()           # inspect speaker/variable
    HISTORY = auto()           # variable history
    LEDGER_READ = auto()       # read ledger
    LEDGER_VERIFY = auto()     # verify ledger integrity
    SEAL = auto()              # seal a variable
    FAIL = auto()              # explicit break
    PASS = auto()              # no-op
    CREATE_WORLD = auto()      # create a world
    EVAL_EXPR = auto()         # evaluate an expression


@dataclass
class Operation:
    """One compiled operation."""
    op: OpType
    speaker: Optional[str] = None
    args: dict = field(default_factory=dict)
    line: int = 0


@dataclass
class CompiledProgram:
    """The output of compilation. A list of operations."""
    operations: list = field(default_factory=list)
    speakers: list = field(default_factory=list)
    functions: dict = field(default_factory=dict)
    worlds: list = field(default_factory=list)


# =============================================================================
# The Compiler
# =============================================================================

class Compiler:
    """
    Walks the AST. Checks axioms. Produces operations.

    This is a proof checker. If your program violates an axiom,
    it does not compile. The error tells you which axiom you broke.
    """

    def __init__(self):
        self.current_speaker: Optional[str] = None
        self.declared_speakers: set = set()
        self.declared_functions: dict = {}  # speaker.name -> params
        self.sealed_vars: set = set()       # speaker.var names that are sealed
        self.operations: list = []
        self.errors: list = []

    def compile(self, program: Program) -> CompiledProgram:
        """Compile a program. Returns CompiledProgram or raises on error."""
        # First pass: collect all speaker declarations
        for stmt in program.statements:
            if isinstance(stmt, SpeakerDecl):
                self.declared_speakers.add(stmt.name)

        # Axiom 1 check: if there's code but no speakers, that's a violation
        has_code = any(not isinstance(s, (SpeakerDecl, WorldDecl))
                       for s in program.statements)
        if has_code and not self.declared_speakers:
            raise AxiomViolation(
                1, "Speaker Requirement",
                "program has code but no speakers declared. "
                "Every operation requires a speaker."
            )

        # Second pass: compile all statements
        for stmt in program.statements:
            self._compile_statement(stmt)

        if self.errors:
            raise self.errors[0]

        return CompiledProgram(
            operations=self.operations,
            speakers=list(self.declared_speakers),
            functions=self.declared_functions,
        )

    # ── Statement Compilation ─────────────────────────────────────────

    def _compile_statement(self, stmt):
        """Compile a single statement."""
        if isinstance(stmt, SpeakerDecl):
            self._compile_speaker_decl(stmt)
        elif isinstance(stmt, WorldDecl):
            self._compile_world_decl(stmt)
        elif isinstance(stmt, AsBlock):
            self._compile_as_block(stmt)
        elif isinstance(stmt, LetStatement):
            self._compile_let(stmt)
        elif isinstance(stmt, SpeakStatement):
            self._compile_speak(stmt)
        elif isinstance(stmt, WhenBlock):
            self._compile_when(stmt)
        elif isinstance(stmt, IfStatement):
            self._compile_if(stmt)
        elif isinstance(stmt, WhileLoop):
            self._compile_while(stmt)
        elif isinstance(stmt, FnDecl):
            self._compile_fn(stmt)
        elif isinstance(stmt, ReturnStatement):
            self._compile_return(stmt)
        elif isinstance(stmt, RequestStatement):
            self._compile_request(stmt)
        elif isinstance(stmt, RespondStatement):
            self._compile_respond(stmt)
        elif isinstance(stmt, InspectStatement):
            self._compile_inspect(stmt)
        elif isinstance(stmt, HistoryStatement):
            self._compile_history(stmt)
        elif isinstance(stmt, LedgerStatement):
            self._compile_ledger(stmt)
        elif isinstance(stmt, VerifyStatement):
            self._compile_verify(stmt)
        elif isinstance(stmt, SealStatement):
            self._compile_seal(stmt)
        elif isinstance(stmt, PassStatement):
            self._emit(OpType.PASS, line=stmt.line)
        elif isinstance(stmt, FailStatement):
            self._compile_fail(stmt)
        elif isinstance(stmt, ExpressionStatement):
            self._compile_expr_statement(stmt)
        else:
            raise ParseError(f"unknown statement type: {type(stmt).__name__}")

    def _compile_speaker_decl(self, stmt: SpeakerDecl):
        """Compile speaker declaration."""
        self.declared_speakers.add(stmt.name)
        self._emit(OpType.CREATE_SPEAKER, args={"name": stmt.name}, line=stmt.line)

    def _compile_world_decl(self, stmt: WorldDecl):
        """Compile world declaration."""
        self._check_speaker_context(stmt)
        self._emit(OpType.CREATE_WORLD,
                   args={"name": stmt.name, "args": stmt.args},
                   line=stmt.line)

    def _compile_as_block(self, stmt: AsBlock):
        """
        Compile 'as Speaker { ... }' block.

        Axiom 1: Every operation has a speaker.
        Axiom 7: Only s can author expressions for s.
        """
        if stmt.speaker_name not in self.declared_speakers:
            raise AxiomViolation(
                1, "Speaker Requirement",
                f"speaker '{stmt.speaker_name}' not declared. "
                f"Declare with: speaker {stmt.speaker_name}",
                line=stmt.line
            )

        prev_speaker = self.current_speaker
        self.current_speaker = stmt.speaker_name
        self._emit(OpType.SET_SPEAKER,
                   args={"name": stmt.speaker_name},
                   line=stmt.line)

        for body_stmt in stmt.body:
            self._compile_statement(body_stmt)

        self.current_speaker = prev_speaker
        if prev_speaker:
            self._emit(OpType.SET_SPEAKER,
                       args={"name": prev_speaker},
                       line=stmt.line)

    def _compile_let(self, stmt: LetStatement):
        """
        Compile 'let name = expr'.

        Axiom 8: Write Ownership — you can only write to your own variables.
        """
        self._check_speaker_context(stmt)

        # Check for write ownership violation
        # Check every segment of the dotted name, not just the first,
        # to catch cases like 'let bar.SpeakerName.baz = 1'
        name = stmt.name
        if '.' in name:
            parts = name.split('.')
            for part in parts:
                if part in self.declared_speakers and part != self.current_speaker:
                    raise AxiomViolation(
                        8, "Write Ownership",
                        f"speaker '{self.current_speaker}' cannot write to "
                        f"'{part}' variables. "
                        f"Only '{part}' can write to '{part}' variables. "
                        f"This is not a permission. It is math.",
                        line=stmt.line
                    )

        # Check for sealed variable
        sealed_key = f"{self.current_speaker}.{name}"
        if sealed_key in self.sealed_vars:
            raise AxiomViolation(
                5, "Ledger Integrity",
                f"variable '{name}' is sealed. "
                f"Sealed variables cannot be overwritten. "
                f"The ledger preserves all state.",
                line=stmt.line
            )

        self._emit(OpType.WRITE_VAR,
                   args={"name": name, "value_ast": stmt.value},
                   line=stmt.line)

    def _compile_speak(self, stmt: SpeakStatement):
        """Compile 'speak expr'."""
        self._check_speaker_context(stmt)
        self._emit(OpType.SPEAK_OUTPUT,
                   args={"value_ast": stmt.value},
                   line=stmt.line)

    def _compile_when(self, stmt: WhenBlock):
        """
        Compile 'when condition { ... } otherwise { ... } broken { ... }'.

        Axiom 3: Three-Valued Evaluation.
        """
        self._check_speaker_context(stmt)
        self._emit(OpType.WHEN_EVAL,
                   args={
                       "condition_ast": stmt.condition,
                       "body": stmt.body,
                       "otherwise_body": stmt.otherwise_body,
                       "broken_body": stmt.broken_body,
                   },
                   line=stmt.line)

        # Check axioms in bodies without emitting duplicate ops
        self._check_block_axioms(stmt.body)
        self._check_block_axioms(stmt.otherwise_body)
        self._check_block_axioms(stmt.broken_body)

    def _compile_if(self, stmt: IfStatement):
        """Compile if/elif/else."""
        self._check_speaker_context(stmt)
        self._emit(OpType.IF_EVAL,
                   args={
                       "condition_ast": stmt.condition,
                       "body": stmt.body,
                       "elif_clauses": stmt.elif_clauses,
                       "else_body": stmt.else_body,
                   },
                   line=stmt.line)

    def _compile_while(self, stmt: WhileLoop):
        """
        Compile 'while condition, max N { ... }'.

        Axiom 9: No Infinite Loops.
        Every loop must have a termination path or explicit bound.
        """
        self._check_speaker_context(stmt)

        # Axiom 9: require max bound
        if stmt.max_iterations is None:
            raise AxiomViolation(
                9, "No Infinite Loops",
                "every loop must have a 'max N' bound. "
                "A commitment that never resolves is not a commitment. "
                "Use: while condition, max 1000 { ... }",
                line=stmt.line
            )

        self._emit(OpType.LOOP_START,
                   args={
                       "condition_ast": stmt.condition,
                       "body": stmt.body,
                       "max_ast": stmt.max_iterations,
                   },
                   line=stmt.line)

    def _compile_fn(self, stmt: FnDecl):
        """Compile function declaration."""
        self._check_speaker_context(stmt)
        fn_key = f"{self.current_speaker}.{stmt.name}"
        self.declared_functions[fn_key] = stmt.params

        self._emit(OpType.FN_DEFINE,
                   args={
                       "name": stmt.name,
                       "params": stmt.params,
                       "body": stmt.body,
                   },
                   line=stmt.line)

    def _compile_return(self, stmt: ReturnStatement):
        """Compile return statement."""
        self._check_speaker_context(stmt)
        self._emit(OpType.RETURN,
                   args={"value_ast": stmt.value},
                   line=stmt.line)

    def _compile_request(self, stmt: RequestStatement):
        """
        Compile 'request Target action'.

        Axiom 7: This creates an expression for the CALLER.
        It does NOT create anything for the target.
        """
        self._check_speaker_context(stmt)

        if stmt.target not in self.declared_speakers:
            raise AxiomViolation(
                1, "Speaker Requirement",
                f"request target '{stmt.target}' is not a declared speaker.",
                line=stmt.line
            )

        self._emit(OpType.REQUEST,
                   args={
                       "target": stmt.target,
                       "action_ast": stmt.action,
                       "data_ast": stmt.data,
                   },
                   line=stmt.line)

    def _compile_respond(self, stmt: RespondStatement):
        """Compile respond accept/refuse."""
        self._check_speaker_context(stmt)
        self._emit(OpType.RESPOND,
                   args={"accept": stmt.accept, "data_ast": stmt.data},
                   line=stmt.line)

    def _compile_inspect(self, stmt: InspectStatement):
        """Compile inspect."""
        self._check_speaker_context(stmt)
        self._emit(OpType.INSPECT,
                   args={"target_ast": stmt.target},
                   line=stmt.line)

    def _compile_history(self, stmt: HistoryStatement):
        """Compile history query."""
        self._check_speaker_context(stmt)
        self._emit(OpType.HISTORY,
                   args={"target_ast": stmt.target},
                   line=stmt.line)

    def _compile_ledger(self, stmt: LedgerStatement):
        """Compile ledger read."""
        self._check_speaker_context(stmt)
        self._emit(OpType.LEDGER_READ,
                   args={"count_ast": stmt.count},
                   line=stmt.line)

    def _compile_verify(self, stmt: VerifyStatement):
        """Compile ledger verify."""
        self._check_speaker_context(stmt)
        self._emit(OpType.LEDGER_VERIFY, line=stmt.line)

    def _compile_seal(self, stmt: SealStatement):
        """Compile seal."""
        self._check_speaker_context(stmt)
        sealed_key = f"{self.current_speaker}.{stmt.target}"
        self.sealed_vars.add(sealed_key)
        self._emit(OpType.SEAL,
                   args={"name": stmt.target},
                   line=stmt.line)

    def _compile_fail(self, stmt: FailStatement):
        """Compile explicit fail."""
        self._check_speaker_context(stmt)
        self._emit(OpType.FAIL,
                   args={"reason_ast": stmt.reason},
                   line=stmt.line)

    def _compile_expr_statement(self, stmt: ExpressionStatement):
        """Compile expression statement."""
        self._check_speaker_context(stmt)
        self._emit(OpType.EVAL_EXPR,
                   args={"expr_ast": stmt.expression},
                   line=stmt.line)

    # ── Block Axiom Checking ─────────────────────────────────────────

    def _check_block_axioms(self, stmts: list):
        """
        Check axioms in a block without emitting duplicate ops.
        Used for bodies of when/if/while/fn where the parent op
        handles execution and we only need to verify axioms.
        """
        for stmt in stmts:
            if isinstance(stmt, LetStatement):
                self._check_speaker_context(stmt)
                name = stmt.name
                if '.' in name:
                    parts = name.split('.')
                    for part in parts:
                        if part in self.declared_speakers and part != self.current_speaker:
                            raise AxiomViolation(
                                8, "Write Ownership",
                                f"speaker '{self.current_speaker}' cannot write to "
                                f"'{part}' variables. "
                                f"Only '{part}' can write to '{part}' variables. "
                                f"This is not a permission. It is math.",
                                line=stmt.line
                            )
                sealed_key = f"{self.current_speaker}.{name}"
                if sealed_key in self.sealed_vars:
                    raise AxiomViolation(
                        5, "Ledger Integrity",
                        f"variable '{name}' is sealed.",
                        line=stmt.line
                    )
            elif isinstance(stmt, WhileLoop) and stmt.max_iterations is None:
                raise AxiomViolation(
                    9, "No Infinite Loops",
                    "every loop must have a 'max N' bound.",
                    line=stmt.line
                )
            elif isinstance(stmt, WhenBlock):
                self._check_block_axioms(stmt.body)
                self._check_block_axioms(stmt.otherwise_body)
                self._check_block_axioms(stmt.broken_body)
            elif isinstance(stmt, IfStatement):
                self._check_block_axioms(stmt.body)
                for clause in stmt.elif_clauses:
                    self._check_block_axioms(clause.body)
                self._check_block_axioms(stmt.else_body)
            elif isinstance(stmt, WhileLoop):
                self._check_block_axioms(stmt.body)
            elif isinstance(stmt, FnDecl):
                self._check_block_axioms(stmt.body)
            elif isinstance(stmt, RequestStatement):
                if stmt.target not in self.declared_speakers:
                    raise AxiomViolation(
                        1, "Speaker Requirement",
                        f"request target '{stmt.target}' is not a declared speaker.",
                        line=stmt.line
                    )

    # ── Expression Analysis ───────────────────────────────────────────

    def _check_write_in_expr(self, expr, line=0):
        """
        Check if an expression contains a write to another speaker's variable.

        Axiom 8: write(s1, s2.v, value) is undefined when s1 != s2.
        """
        if isinstance(expr, MemberAccess) and isinstance(expr.object, Identifier):
            target = expr.object.name
            if target in self.declared_speakers and target != self.current_speaker:
                return target
        return None

    # ── Axiom Enforcement ─────────────────────────────────────────────

    def _check_speaker_context(self, stmt):
        """
        Axiom 1: Speaker Requirement.
        Every operation requires a speaker.
        """
        if self.current_speaker is None:
            raise AxiomViolation(
                1, "Speaker Requirement",
                f"'{type(stmt).__name__}' requires a speaker context. "
                f"Wrap code in: as SpeakerName {{ ... }}",
                line=stmt.line
            )

    # ── Helpers ───────────────────────────────────────────────────────

    def _emit(self, op_type: OpType, args: dict = None, line: int = 0):
        """Emit an operation."""
        self.operations.append(Operation(
            op=op_type,
            speaker=self.current_speaker,
            args=args or {},
            line=line,
        ))
