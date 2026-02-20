"""
Logica Runtime — Where Programs Execute
========================================

The runtime takes compiled operations and executes them through Mary.
Mary is the kernel. She enforces the axioms.
The runtime is the bridge between Logica syntax and Mary's system calls.

Every variable write goes through Mary.
Every operation is logged in the ledger.
Every speaker is authenticated.
"""

import sys
import os

# Add parent dir so we can import mary
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mary import Mary, Status
from .compiler import Operation, OpType, CompiledProgram
from .ast_nodes import *
from .errors import RuntimeError_


class Environment:
    """
    Runtime environment for a Logica program.

    Tracks speaker IDs, local function scopes, and the Mary kernel.
    """

    def __init__(self):
        self.mary = Mary()
        self.speaker_ids: dict[str, int] = {}  # name -> mary speaker id
        self.current_speaker: str = None
        self.current_speaker_id: int = None
        self.functions: dict[str, dict] = {}  # "speaker.fn" -> {params, body}
        self.local_scopes: list[dict] = []     # stack of local variable scopes
        self.sealed: set = set()               # "speaker.var" keys
        self.output: list[str] = []            # captured output
        self.return_value = None               # for function returns
        self.returning = False                 # flag for return unwinding


class Runtime:
    """
    Executes a compiled Logica program through Mary.

    This is where the rubber meets the road.
    """

    def __init__(self, quiet=False):
        self.env = Environment()
        self.quiet = quiet

    def execute(self, compiled: CompiledProgram):
        """Execute a compiled program."""
        for op in compiled.operations:
            if self.env.returning:
                break
            self._execute_op(op)

    def _execute_op(self, op: Operation):
        """Execute a single operation."""
        dispatch = {
            OpType.CREATE_SPEAKER: self._op_create_speaker,
            OpType.SET_SPEAKER: self._op_set_speaker,
            OpType.WRITE_VAR: self._op_write_var,
            OpType.SPEAK_OUTPUT: self._op_speak_output,
            OpType.WHEN_EVAL: self._op_when_eval,
            OpType.IF_EVAL: self._op_if_eval,
            OpType.LOOP_START: self._op_loop,
            OpType.FN_DEFINE: self._op_fn_define,
            OpType.RETURN: self._op_return,
            OpType.REQUEST: self._op_request,
            OpType.RESPOND: self._op_respond,
            OpType.INSPECT: self._op_inspect,
            OpType.HISTORY: self._op_history,
            OpType.LEDGER_READ: self._op_ledger_read,
            OpType.LEDGER_VERIFY: self._op_ledger_verify,
            OpType.SEAL: self._op_seal,
            OpType.FAIL: self._op_fail,
            OpType.PASS: lambda op: None,
            OpType.CREATE_WORLD: self._op_create_world,
            OpType.EVAL_EXPR: self._op_eval_expr,
        }
        handler = dispatch.get(op.op)
        if handler:
            handler(op)

    # ── Operation Handlers ────────────────────────────────────────────

    def _op_create_speaker(self, op: Operation):
        """Create a speaker in Mary."""
        name = op.args["name"]
        speaker = self.env.mary.create_speaker(0, name)  # root creates
        if speaker:
            self.env.speaker_ids[name] = speaker.id

    def _op_set_speaker(self, op: Operation):
        """Switch active speaker context."""
        name = op.args["name"]
        self.env.current_speaker = name
        self.env.current_speaker_id = self.env.speaker_ids.get(name)

    def _op_write_var(self, op: Operation):
        """Write to the current speaker's variable through Mary."""
        name = op.args["name"]
        value_ast = op.args["value_ast"]
        value = self._eval_expr(value_ast)

        sid = self.env.current_speaker_id
        if sid is None:
            raise RuntimeError_("no active speaker", self.env.current_speaker)

        # Check seal
        seal_key = f"{self.env.current_speaker}.{name}"
        if seal_key in self.env.sealed:
            raise RuntimeError_(
                f"variable '{name}' is sealed and cannot be modified",
                self.env.current_speaker
            )

        # Check if this is a local scope variable
        if self.env.local_scopes:
            self.env.local_scopes[-1][name] = value
            # Also write to Mary for ledger tracking
            self.env.mary.write(sid, f"local.{name}", value)
        else:
            success = self.env.mary.write(sid, name, value)
            if not success:
                raise RuntimeError_(
                    f"write failed for variable '{name}'",
                    self.env.current_speaker
                )

    def _op_speak_output(self, op: Operation):
        """Output a value. The speaker says something."""
        value_ast = op.args["value_ast"]
        value = self._eval_expr(value_ast)

        sid = self.env.current_speaker_id
        speaker_name = self.env.current_speaker

        # Log the speak in Mary
        self.env.mary.submit(
            speaker_id=sid,
            condition_label="speak",
            action=f"speak:{repr(value)}",
            action_fn=lambda: True,
        )

        output = f"  [{speaker_name}] {value}"
        self.env.output.append(output)
        if not self.quiet:
            print(output)

    def _op_when_eval(self, op: Operation):
        """
        Three-valued conditional evaluation.

        when condition { active } otherwise { inactive } broken { broken }
        """
        condition_ast = op.args["condition_ast"]
        body = op.args["body"]
        otherwise_body = op.args["otherwise_body"]
        broken_body = op.args["broken_body"]

        sid = self.env.current_speaker_id

        # Evaluate condition
        try:
            condition_result = self._eval_expr(condition_ast)
            condition_met = bool(condition_result)
        except Exception:
            condition_met = None  # broken

        if condition_met is True:
            # Active path — try to execute body
            try:
                for stmt in body:
                    self._execute_statement(stmt)
                # Log as active
                self.env.mary.submit(
                    speaker_id=sid,
                    condition=lambda: True,
                    condition_label="when:active",
                    action="when_block",
                    action_fn=lambda: True,
                )
            except Exception as e:
                # Action failed — broken path
                self.env.mary.submit(
                    speaker_id=sid,
                    condition=lambda: True,
                    condition_label="when:broken",
                    action="when_block",
                    action_fn=lambda: False,
                )
                for stmt in broken_body:
                    self._execute_statement(stmt)
        elif condition_met is False:
            # Inactive path
            self.env.mary.submit(
                speaker_id=sid,
                condition=lambda: False,
                condition_label="when:inactive",
                action="when_block",
            )
            for stmt in otherwise_body:
                self._execute_statement(stmt)
        else:
            # Broken — condition evaluation itself failed
            self.env.mary.submit(
                speaker_id=sid,
                condition=lambda: True,
                condition_label="when:broken",
                action="when_block",
                action_fn=lambda: False,
            )
            for stmt in broken_body:
                self._execute_statement(stmt)

    def _op_if_eval(self, op: Operation):
        """Execute if/elif/else."""
        condition_ast = op.args["condition_ast"]
        body = op.args["body"]
        elif_clauses = op.args.get("elif_clauses", [])
        else_body = op.args.get("else_body", [])

        if self._eval_expr(condition_ast):
            for stmt in body:
                self._execute_statement(stmt)
            return

        for clause in elif_clauses:
            if self._eval_expr(clause.condition):
                for stmt in clause.body:
                    self._execute_statement(stmt)
                return

        for stmt in else_body:
            self._execute_statement(stmt)

    def _op_loop(self, op: Operation):
        """
        Execute a bounded loop.

        Axiom 9: Every loop terminates.
        """
        condition_ast = op.args["condition_ast"]
        body = op.args["body"]
        max_ast = op.args.get("max_ast")

        max_iter = 10000  # default safety bound
        if max_ast:
            max_iter = int(self._eval_expr(max_ast))

        sid = self.env.current_speaker_id
        count = 0

        while count < max_iter:
            # Check condition
            condition_result = self._eval_expr(condition_ast)
            if not condition_result:
                # Condition unmet — loop ends (inactive)
                self.env.mary.submit(
                    speaker_id=sid,
                    condition=lambda: False,
                    condition_label="loop:terminated",
                    action=f"loop:iterations={count}",
                )
                return

            # Execute body
            for stmt in body:
                if self.env.returning:
                    return
                self._execute_statement(stmt)

            count += 1

        # Bound exceeded — broken
        self.env.mary.submit(
            speaker_id=sid,
            condition=lambda: True,
            condition_label="loop:bound_exceeded",
            action=f"loop:max={max_iter}",
            action_fn=lambda: False,
        )
        raise RuntimeError_(
            f"loop exceeded max {max_iter} iterations",
            self.env.current_speaker
        )

    def _op_fn_define(self, op: Operation):
        """Register a function."""
        name = op.args["name"]
        params = op.args["params"]
        body = op.args["body"]

        fn_key = f"{self.env.current_speaker}.{name}"
        self.env.functions[fn_key] = {
            "params": params,
            "body": body,
            "speaker": self.env.current_speaker,
        }

    def _op_return(self, op: Operation):
        """Return from a function."""
        value_ast = op.args.get("value_ast")
        if value_ast:
            self.env.return_value = self._eval_expr(value_ast)
        else:
            self.env.return_value = None
        self.env.returning = True

    def _op_request(self, op: Operation):
        """Send a request to another speaker."""
        target_name = op.args["target"]
        action_ast = op.args["action_ast"]

        action = str(self._eval_expr(action_ast))
        target_id = self.env.speaker_ids.get(target_name)

        if target_id is None:
            raise RuntimeError_(
                f"target speaker '{target_name}' not found",
                self.env.current_speaker
            )

        req = self.env.mary.request(
            self.env.current_speaker_id,
            target_id,
            action,
        )

        if not self.quiet:
            print(f"  [{self.env.current_speaker}] request -> {target_name}: {action}")

    def _op_respond(self, op: Operation):
        """Respond to pending request."""
        accept = op.args["accept"]
        sid = self.env.current_speaker_id

        pending = self.env.mary.pending_requests(sid)
        if pending:
            req = pending[0]
            self.env.mary.respond(sid, req.request_id, accept)
            action = "accepted" if accept else "refused"
            if not self.quiet:
                print(f"  [{self.env.current_speaker}] {action} request #{req.request_id}")

    def _op_inspect(self, op: Operation):
        """Inspect a speaker or variable."""
        target_ast = op.args["target_ast"]
        target = self._eval_inspect_target(target_ast)

        sid = self.env.current_speaker_id

        if isinstance(target, str) and target in self.env.speaker_ids:
            # Inspect a speaker
            target_id = self.env.speaker_ids[target]
            info = self.env.mary.inspect_speaker(sid, target_id)
            if info and not self.quiet:
                print(f"  --- inspect {target} ---")
                print(f"  speaker: {info['speaker']['name']} (#{info['speaker']['id']})")
                print(f"  status:  {info['speaker']['status']}")
                print(f"  vars:    {info['variables']}")
                print(f"  exprs:   {len(info['expressions'])}")
                for e in info['expressions'][-5:]:
                    print(f"    #{e['id']}: {e['action']} -> {e['status']}")
                print(f"  ---")
        elif isinstance(target, tuple) and len(target) == 2:
            # Inspect a variable
            speaker_name, var_name = target
            owner_id = self.env.speaker_ids.get(speaker_name, sid)
            value = self.env.mary.read(sid, owner_id, var_name)
            if not self.quiet:
                print(f"  --- inspect {speaker_name}.{var_name} ---")
                print(f"  value: {value}")
                print(f"  ---")

    def _op_history(self, op: Operation):
        """Show variable history."""
        target_ast = op.args["target_ast"]
        target = self._eval_inspect_target(target_ast)

        sid = self.env.current_speaker_id

        if isinstance(target, tuple) and len(target) == 2:
            speaker_name, var_name = target
            owner_id = self.env.speaker_ids.get(speaker_name, sid)
            result = self.env.mary.inspect_variable(sid, owner_id, var_name)
            if result and not self.quiet:
                print(f"  --- history {speaker_name}.{var_name} ---")
                print(f"  current: {result['current_value']}")
                for h in result['history']:
                    print(f"    #{h['entry_id']}: {h['before']} -> {h['after']}")
                print(f"  ---")

    def _op_ledger_read(self, op: Operation):
        """Read ledger entries."""
        count_ast = op.args.get("count_ast")
        sid = self.env.current_speaker_id

        total = self.env.mary.ledger_count(sid)
        count = total
        if count_ast:
            count = min(int(self._eval_expr(count_ast)), total)

        entries = self.env.mary.ledger_read(sid, max(0, total - count), total)
        if not self.quiet:
            print(f"  --- ledger (last {count} of {total}) ---")
            for e in entries:
                status = e.status.value if e.status else "-"
                speaker_name = self._speaker_name_by_id(e.speaker_id)
                print(f"    #{e.entry_id} [{status:>8}] {speaker_name}: {e.action}")
            print(f"  ---")

    def _op_ledger_verify(self, op: Operation):
        """Verify ledger integrity."""
        intact = self.env.mary.ledger_verify()
        if not self.quiet:
            if intact:
                print("  ledger integrity: VALID")
            else:
                print("  ledger integrity: BROKEN")

    def _op_seal(self, op: Operation):
        """Seal a variable."""
        name = op.args["name"]
        seal_key = f"{self.env.current_speaker}.{name}"
        self.env.sealed.add(seal_key)

        sid = self.env.current_speaker_id
        self.env.mary.submit(
            speaker_id=sid,
            condition_label="seal",
            action=f"seal:{name}",
            action_fn=lambda: True,
        )

        if not self.quiet:
            print(f"  [{self.env.current_speaker}] sealed: {name}")

    def _op_fail(self, op: Operation):
        """Explicit failure."""
        reason_ast = op.args.get("reason_ast")
        reason = "explicit fail"
        if reason_ast:
            reason = str(self._eval_expr(reason_ast))

        sid = self.env.current_speaker_id
        self.env.mary.submit(
            speaker_id=sid,
            condition=lambda: True,
            condition_label="fail",
            action=f"fail:{reason}",
            action_fn=lambda: False,
        )
        raise RuntimeError_(reason, self.env.current_speaker)

    def _op_create_world(self, op: Operation):
        """Create a world."""
        name = op.args["name"]
        if not self.quiet:
            print(f"  [{self.env.current_speaker}] world created: {name}")

    def _op_eval_expr(self, op: Operation):
        """Evaluate an expression statement (e.g., function call)."""
        expr_ast = op.args["expr_ast"]
        result = self._eval_expr(expr_ast)
        return result

    # ── Expression Evaluation ─────────────────────────────────────────

    def _eval_expr(self, node):
        """Evaluate an AST expression node to a Python value."""
        if node is None:
            return None

        if isinstance(node, IntegerLiteral):
            return node.value

        if isinstance(node, FloatLiteral):
            return node.value

        if isinstance(node, StringLiteral):
            return node.value

        if isinstance(node, BooleanLiteral):
            return node.value

        if isinstance(node, NoneLiteral):
            return None

        if isinstance(node, StatusLiteral):
            return node.value

        if isinstance(node, Identifier):
            return self._resolve_identifier(node.name)

        if isinstance(node, MemberAccess):
            return self._eval_member_access(node)

        if isinstance(node, BinaryOp):
            return self._eval_binary(node)

        if isinstance(node, UnaryOp):
            return self._eval_unary(node)

        if isinstance(node, FnCall):
            return self._eval_fn_call(node)

        if isinstance(node, ReadExpr):
            return self._eval_expr(node.target)

        if isinstance(node, IndexAccess):
            obj = self._eval_expr(node.object)
            idx = self._eval_expr(node.index)
            if isinstance(obj, (list, dict)):
                return obj[idx]
            return None

        return None

    def _resolve_identifier(self, name: str):
        """Resolve a variable name to its value."""
        # Check local scopes first (innermost to outermost)
        for scope in reversed(self.env.local_scopes):
            if name in scope:
                return scope[name]

        # Check Mary memory (current speaker's partition)
        sid = self.env.current_speaker_id
        if sid is not None:
            value = self.env.mary.read(sid, sid, name)
            if value is not None:
                return value

        # Check if it's a speaker name
        if name in self.env.speaker_ids:
            return name

        return None

    def _eval_member_access(self, node: MemberAccess):
        """Evaluate speaker.variable — read from another speaker's partition."""
        if isinstance(node.object, Identifier):
            speaker_name = node.object.name
            if speaker_name in self.env.speaker_ids:
                # Reading another speaker's variable — always allowed
                owner_id = self.env.speaker_ids[speaker_name]
                caller_id = self.env.current_speaker_id
                value = self.env.mary.read(caller_id, owner_id, node.member)
                return value

        # Generic object member access
        obj = self._eval_expr(node.object)
        if isinstance(obj, dict):
            return obj.get(node.member)
        return None

    def _eval_binary(self, node: BinaryOp):
        """Evaluate a binary operation."""
        left = self._eval_expr(node.left)
        right = self._eval_expr(node.right)

        ops = {
            '+': lambda a, b: a + b,
            '-': lambda a, b: a - b,
            '*': lambda a, b: a * b,
            '/': lambda a, b: a / b if b != 0 else None,
            '%': lambda a, b: a % b if b != 0 else None,
            '==': lambda a, b: a == b,
            '!=': lambda a, b: a != b,
            '<': lambda a, b: a < b,
            '>': lambda a, b: a > b,
            '<=': lambda a, b: a <= b,
            '>=': lambda a, b: a >= b,
            'and': lambda a, b: a and b,
            'or': lambda a, b: a or b,
        }

        fn = ops.get(node.op)
        if fn:
            try:
                return fn(left, right)
            except (TypeError, ValueError):
                return None
        return None

    def _eval_unary(self, node: UnaryOp):
        """Evaluate a unary operation."""
        operand = self._eval_expr(node.operand)
        if node.op == '-':
            return -operand if operand is not None else None
        if node.op == 'not':
            return not operand
        return None

    def _eval_fn_call(self, node: FnCall):
        """Evaluate a function call."""
        # Determine the function name
        if isinstance(node.function, Identifier):
            fn_name = node.function.name
        elif isinstance(node.function, MemberAccess):
            fn_name = f"{self._eval_expr(node.function.object)}.{node.function.member}"
        else:
            return None

        # Look up the function
        fn_key = f"{self.env.current_speaker}.{fn_name}"
        fn_def = self.env.functions.get(fn_key)

        if fn_def is None:
            # Try without speaker prefix
            for key, val in self.env.functions.items():
                if key.endswith(f".{fn_name}"):
                    fn_def = val
                    break

        if fn_def is None:
            return None

        # Evaluate arguments
        arg_values = [self._eval_expr(arg) for arg in node.args]

        # Create local scope
        local_scope = {}
        for param, arg_val in zip(fn_def["params"], arg_values):
            local_scope[param] = arg_val

        self.env.local_scopes.append(local_scope)
        self.env.returning = False
        self.env.return_value = None

        # Execute body
        for stmt in fn_def["body"]:
            if self.env.returning:
                break
            self._execute_statement(stmt)

        # Pop scope
        self.env.local_scopes.pop()
        result = self.env.return_value
        self.env.returning = False
        self.env.return_value = None

        return result

    # ── Statement Execution (for blocks) ──────────────────────────────

    def _execute_statement(self, stmt):
        """Execute an AST statement node directly (for blocks in when/if/while/fn)."""
        if self.env.returning:
            return

        if isinstance(stmt, LetStatement):
            name = stmt.name
            value = self._eval_expr(stmt.value)
            sid = self.env.current_speaker_id

            # Check seal
            seal_key = f"{self.env.current_speaker}.{name}"
            if seal_key in self.env.sealed:
                raise RuntimeError_(
                    f"variable '{name}' is sealed",
                    self.env.current_speaker
                )

            if self.env.local_scopes:
                self.env.local_scopes[-1][name] = value
            if sid is not None:
                self.env.mary.write(sid, name, value)

        elif isinstance(stmt, SpeakStatement):
            value = self._eval_expr(stmt.value)
            sid = self.env.current_speaker_id
            output = f"  [{self.env.current_speaker}] {value}"
            self.env.output.append(output)
            if not self.quiet:
                print(output)
            if sid:
                self.env.mary.submit(
                    speaker_id=sid,
                    condition_label="speak",
                    action=f"speak:{repr(value)}",
                    action_fn=lambda: True,
                )

        elif isinstance(stmt, WhenBlock):
            self._exec_when(stmt)

        elif isinstance(stmt, IfStatement):
            self._exec_if(stmt)

        elif isinstance(stmt, WhileLoop):
            self._exec_while(stmt)

        elif isinstance(stmt, ReturnStatement):
            if stmt.value:
                self.env.return_value = self._eval_expr(stmt.value)
            self.env.returning = True

        elif isinstance(stmt, ExpressionStatement):
            self._eval_expr(stmt.expression)

        elif isinstance(stmt, RequestStatement):
            target_id = self.env.speaker_ids.get(stmt.target)
            action = str(self._eval_expr(stmt.action))
            if target_id and self.env.current_speaker_id:
                self.env.mary.request(
                    self.env.current_speaker_id, target_id, action
                )
                if not self.quiet:
                    print(f"  [{self.env.current_speaker}] request -> {stmt.target}: {action}")

        elif isinstance(stmt, RespondStatement):
            sid = self.env.current_speaker_id
            pending = self.env.mary.pending_requests(sid)
            if pending:
                req = pending[0]
                self.env.mary.respond(sid, req.request_id, stmt.accept)

        elif isinstance(stmt, InspectStatement):
            op = Operation(op=OpType.INSPECT, speaker=self.env.current_speaker,
                           args={"target_ast": stmt.target})
            self._op_inspect(op)

        elif isinstance(stmt, HistoryStatement):
            op = Operation(op=OpType.HISTORY, speaker=self.env.current_speaker,
                           args={"target_ast": stmt.target})
            self._op_history(op)

        elif isinstance(stmt, LedgerStatement):
            op = Operation(op=OpType.LEDGER_READ, speaker=self.env.current_speaker,
                           args={"count_ast": stmt.count})
            self._op_ledger_read(op)

        elif isinstance(stmt, VerifyStatement):
            op = Operation(op=OpType.LEDGER_VERIFY, speaker=self.env.current_speaker)
            self._op_ledger_verify(op)

        elif isinstance(stmt, SealStatement):
            seal_key = f"{self.env.current_speaker}.{stmt.target}"
            self.env.sealed.add(seal_key)
            if not self.quiet:
                print(f"  [{self.env.current_speaker}] sealed: {stmt.target}")

        elif isinstance(stmt, FnDecl):
            fn_key = f"{self.env.current_speaker}.{stmt.name}"
            self.env.functions[fn_key] = {
                "params": stmt.params,
                "body": stmt.body,
                "speaker": self.env.current_speaker,
            }

        elif isinstance(stmt, PassStatement):
            pass

        elif isinstance(stmt, FailStatement):
            reason = "explicit fail"
            if stmt.reason:
                reason = str(self._eval_expr(stmt.reason))
            raise RuntimeError_(reason, self.env.current_speaker)

    def _exec_when(self, stmt: WhenBlock):
        """Execute a when block directly."""
        try:
            condition_result = self._eval_expr(stmt.condition)
            condition_met = bool(condition_result)
        except Exception:
            condition_met = None

        if condition_met is True:
            try:
                for s in stmt.body:
                    if self.env.returning:
                        return
                    self._execute_statement(s)
            except Exception:
                for s in stmt.broken_body:
                    if self.env.returning:
                        return
                    self._execute_statement(s)
        elif condition_met is False:
            for s in stmt.otherwise_body:
                if self.env.returning:
                    return
                self._execute_statement(s)
        else:
            for s in stmt.broken_body:
                if self.env.returning:
                    return
                self._execute_statement(s)

    def _exec_if(self, stmt: IfStatement):
        """Execute an if statement directly."""
        if self._eval_expr(stmt.condition):
            for s in stmt.body:
                if self.env.returning:
                    return
                self._execute_statement(s)
            return

        for clause in stmt.elif_clauses:
            if self._eval_expr(clause.condition):
                for s in clause.body:
                    if self.env.returning:
                        return
                    self._execute_statement(s)
                return

        for s in stmt.else_body:
            if self.env.returning:
                return
            self._execute_statement(s)

    def _exec_while(self, stmt: WhileLoop):
        """Execute a while loop directly."""
        max_iter = 10000
        if stmt.max_iterations:
            max_iter = int(self._eval_expr(stmt.max_iterations))

        count = 0
        while count < max_iter:
            if not self._eval_expr(stmt.condition):
                return
            for s in stmt.body:
                if self.env.returning:
                    return
                self._execute_statement(s)
            count += 1

        raise RuntimeError_(
            f"loop exceeded max {max_iter} iterations",
            self.env.current_speaker
        )

    # ── Helpers ───────────────────────────────────────────────────────

    def _eval_inspect_target(self, node):
        """Evaluate an inspect/history target to (speaker_name, var_name) or speaker_name."""
        if isinstance(node, Identifier):
            return node.name
        if isinstance(node, MemberAccess) and isinstance(node.object, Identifier):
            return (node.object.name, node.member)
        return str(self._eval_expr(node))

    def _speaker_name_by_id(self, speaker_id: int) -> str:
        """Look up speaker name by ID."""
        for name, sid in self.env.speaker_ids.items():
            if sid == speaker_id:
                return name
        # Check Mary's registry
        speaker = self.env.mary.registry.get(speaker_id)
        if speaker:
            return speaker.name
        return f"speaker_{speaker_id}"
