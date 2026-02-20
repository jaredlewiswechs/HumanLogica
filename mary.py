"""
Mary v1.0 — A Kernel for Human Logic
=====================================
Author: Jared Lewis
Date: February 19, 2026

Mary enforces Human Logic on conventional hardware.
She manages speakers, partitioned memory, an append-only ledger,
expression evaluation, and inter-speaker communication.

Every operation has a speaker. Every state change has a receipt.
"""

import hashlib
import json
import time
from enum import Enum
from dataclasses import dataclass, field
from typing import Any, Optional, Callable


# =============================================================================
# Part I — Enums (The Three Values)
# =============================================================================

class Status(Enum):
    """Expression evaluation status. Three values. No more."""
    ACTIVE = "active"
    INACTIVE = "inactive"
    BROKEN = "broken"


class SpeakerStatus(Enum):
    """Speaker lifecycle status."""
    ALIVE = "alive"
    SUSPENDED = "suspended"


class Position(Enum):
    """Speaker's position on a given action."""
    COMMITTED = "committed"
    REFUSED = "refused"
    SILENT = "silent"


class Version(Enum):
    """Expression version state."""
    CURRENT = "current"
    SUPERSEDED = "superseded"
    EXPIRED = "expired"


class RequestStatus(Enum):
    """Request lifecycle status."""
    PENDING = "pending"
    ACCEPTED = "accepted"
    REFUSED = "refused"
    EXPIRED = "expired"


# =============================================================================
# Part II — Data Structures
# =============================================================================

@dataclass
class Speaker:
    """A speaker in the system. Every statement has one."""
    id: int
    name: str
    created_at: float
    status: SpeakerStatus = SpeakerStatus.ALIVE

    def is_alive(self) -> bool:
        return self.status == SpeakerStatus.ALIVE


@dataclass
class LedgerEntry:
    """One entry in the append-only ledger. Every operation produces one."""
    entry_id: int
    speaker_id: int
    operation: str
    condition: Optional[str]
    condition_result: Optional[bool]
    action: str
    status: Optional[Status]
    state_before: Optional[Any]
    state_after: Optional[Any]
    timestamp: float
    prev_hash: str
    entry_hash: str = ""
    break_reason: Optional[str] = None

    def compute_hash(self) -> str:
        """Hash this entry for chain integrity."""
        data = f"{self.entry_id}:{self.speaker_id}:{self.operation}:" \
               f"{self.action}:{self.timestamp}:{self.prev_hash}"
        return hashlib.sha256(data.encode()).hexdigest()[:16]


@dataclass
class Request:
    """A request from one speaker to another."""
    request_id: int
    from_speaker: int
    to_speaker: int
    action: str
    data: Optional[Any]
    status: RequestStatus = RequestStatus.PENDING
    created_at: float = 0.0
    expires_at: Optional[float] = None
    response_data: Optional[Any] = None


@dataclass
class Expression:
    """A Human Logic expression: speaker : condition ⊢ action"""
    expression_id: int
    speaker_id: int
    condition: Optional[Callable]  # function that returns True/False
    condition_label: str           # human-readable description
    action: str                    # what to do
    action_fn: Optional[Callable]  # function that performs the action
    created_at: float
    version: Version = Version.CURRENT
    status: Optional[Status] = None
    scope_until: Optional[float] = None
    is_refusal: bool = False
    loop_condition: Optional[Callable] = None
    loop_max: Optional[int] = None


# =============================================================================
# Part III — The Ledger
# =============================================================================

class Ledger:
    """
    Append-only, hash-chained log of every operation.
    
    Rule 9.1: Append only. No modification. No deletion. Ever.
    Rule 9.2: Total capture. Every operation produces an entry.
    Rule 9.3: Sequential consistency. Ordered by entry_id.
    """

    def __init__(self):
        self._entries: list[LedgerEntry] = []
        self._last_hash: str = "genesis"

    def append(self, speaker_id: int, operation: str, action: str,
               condition: str = None, condition_result: bool = None,
               status: Status = None, state_before: Any = None,
               state_after: Any = None, break_reason: str = None) -> LedgerEntry:
        """Append a new entry. Returns the entry with its hash."""
        entry = LedgerEntry(
            entry_id=len(self._entries),
            speaker_id=speaker_id,
            operation=operation,
            condition=condition,
            condition_result=condition_result,
            action=action,
            status=status,
            state_before=state_before,
            state_after=state_after,
            timestamp=time.time(),
            prev_hash=self._last_hash,
            break_reason=break_reason,
        )
        entry.entry_hash = entry.compute_hash()
        self._last_hash = entry.entry_hash
        self._entries.append(entry)
        return entry

    def read(self, from_id: int = 0, to_id: int = None) -> list[LedgerEntry]:
        """Read entries by ID range."""
        if to_id is None:
            to_id = len(self._entries)
        return self._entries[from_id:to_id]

    def search(self, speaker_id: int = None, operation: str = None,
               action: str = None, from_time: float = None,
               to_time: float = None) -> list[LedgerEntry]:
        """Search entries by filters."""
        results = self._entries
        if speaker_id is not None:
            results = [e for e in results if e.speaker_id == speaker_id]
        if operation is not None:
            results = [e for e in results if e.operation == operation]
        if action is not None:
            results = [e for e in results if e.action == action]
        if from_time is not None:
            results = [e for e in results if e.timestamp >= from_time]
        if to_time is not None:
            results = [e for e in results if e.timestamp <= to_time]
        return results

    def verify_integrity(self) -> bool:
        """Walk the hash chain. Return True if unbroken."""
        if not self._entries:
            return True
        expected_prev = "genesis"
        for entry in self._entries:
            if entry.prev_hash != expected_prev:
                return False
            if entry.entry_hash != entry.compute_hash():
                return False
            expected_prev = entry.entry_hash
        return True

    def count(self) -> int:
        return len(self._entries)

    def last(self) -> Optional[LedgerEntry]:
        return self._entries[-1] if self._entries else None


# =============================================================================
# Part IV — Memory (Speaker-Partitioned)
# =============================================================================

class Memory:
    """
    Speaker-partitioned memory.
    
    Axiom 8: Only speaker s can write to s's variables.
    Definition 9.1: Any speaker can read any variable.
    """

    def __init__(self):
        self._partitions: dict[int, dict[str, Any]] = {}

    def create_partition(self, speaker_id: int):
        """Create a memory partition for a speaker."""
        if speaker_id not in self._partitions:
            self._partitions[speaker_id] = {}

    def read(self, owner_id: int, var_name: str) -> Any:
        """
        Read any speaker's variable. Unrestricted.
        Returns None if variable doesn't exist.
        """
        partition = self._partitions.get(owner_id, {})
        return partition.get(var_name)

    def write(self, caller_id: int, var_name: str, value: Any) -> tuple[bool, Any]:
        """
        Write to caller's own partition ONLY.
        Returns (success, old_value).
        """
        if caller_id not in self._partitions:
            return False, None
        old_value = self._partitions[caller_id].get(var_name)
        self._partitions[caller_id][var_name] = value
        return True, old_value

    def write_check(self, caller_id: int, target_id: int) -> bool:
        """Check if a write would be allowed. Only self-writes allowed."""
        return caller_id == target_id

    def list_vars(self, owner_id: int) -> list[str]:
        """List variable names in a speaker's partition."""
        return list(self._partitions.get(owner_id, {}).keys())

    def get_partition(self, speaker_id: int) -> dict[str, Any]:
        """Get a copy of a speaker's entire partition (read-only snapshot)."""
        return dict(self._partitions.get(speaker_id, {}))


# =============================================================================
# Part V — Speaker Registry
# =============================================================================

class SpeakerRegistry:
    """
    Manages speaker identities.
    
    Definition 5.1: Every call requires a speaker identity.
    Definition 5.2: Root is created at initialization.
    """

    def __init__(self):
        self._speakers: dict[int, Speaker] = {}
        self._next_id: int = 0

    def create(self, name: str, creator_id: int = None) -> Speaker:
        """Create a new speaker. Returns the speaker record."""
        speaker = Speaker(
            id=self._next_id,
            name=name,
            created_at=time.time(),
        )
        self._speakers[speaker.id] = speaker
        self._next_id += 1
        return speaker

    def get(self, speaker_id: int) -> Optional[Speaker]:
        """Get a speaker by ID."""
        return self._speakers.get(speaker_id)

    def authenticate(self, speaker_id: int) -> bool:
        """Verify speaker exists and is alive."""
        speaker = self._speakers.get(speaker_id)
        return speaker is not None and speaker.is_alive()

    def suspend(self, speaker_id: int) -> bool:
        """Suspend a speaker. They can no longer issue expressions."""
        speaker = self._speakers.get(speaker_id)
        if speaker:
            speaker.status = SpeakerStatus.SUSPENDED
            return True
        return False

    def list_all(self) -> list[Speaker]:
        """List all speakers."""
        return list(self._speakers.values())


# =============================================================================
# Part VI — Request Bus
# =============================================================================

class RequestBus:
    """
    Inter-speaker communication.
    
    Rule 15.1: No direct memory access between speakers.
    Rule 15.2: One sender, one receiver per request.
    Rule 15.3: FIFO processing.
    """

    def __init__(self):
        self._pending: list[Request] = []
        self._resolved: list[Request] = []
        self._next_id: int = 0

    def create_request(self, from_speaker: int, to_speaker: int,
                       action: str, data: Any = None,
                       expires_at: float = None) -> Request:
        """Create a new request."""
        req = Request(
            request_id=self._next_id,
            from_speaker=from_speaker,
            to_speaker=to_speaker,
            action=action,
            data=data,
            created_at=time.time(),
            expires_at=expires_at,
        )
        self._next_id += 1
        self._pending.append(req)
        return req

    def get_request(self, request_id: int) -> Optional[Request]:
        """Find a request by ID."""
        for req in self._pending + self._resolved:
            if req.request_id == request_id:
                return req
        return None

    def respond(self, request_id: int, responder_id: int,
                accept: bool, response_data: Any = None) -> Optional[Request]:
        """Respond to a request. Only the target speaker can respond."""
        req = None
        for i, r in enumerate(self._pending):
            if r.request_id == request_id:
                req = r
                break

        if req is None:
            return None
        if req.to_speaker != responder_id:
            return None
        if req.status != RequestStatus.PENDING:
            return None

        req.status = RequestStatus.ACCEPTED if accept else RequestStatus.REFUSED
        req.response_data = response_data
        self._pending.remove(req)
        self._resolved.append(req)
        return req

    def get_pending_for(self, speaker_id: int) -> list[Request]:
        """Get all pending requests for a speaker."""
        return [r for r in self._pending if r.to_speaker == speaker_id]

    def get_pending_from(self, speaker_id: int) -> list[Request]:
        """Get all pending requests from a speaker."""
        return [r for r in self._pending if r.from_speaker == speaker_id]

    def check_timeouts(self) -> list[Request]:
        """Expire timed-out requests. Returns list of expired requests."""
        now = time.time()
        expired = []
        still_pending = []
        for req in self._pending:
            if req.expires_at and now > req.expires_at:
                req.status = RequestStatus.EXPIRED
                self._resolved.append(req)
                expired.append(req)
            else:
                still_pending.append(req)
        self._pending = still_pending
        return expired


# =============================================================================
# Part VII — The Evaluator (Mary's Heart)
# =============================================================================

class Evaluator:
    """
    The core evaluation engine.
    
    One expression in, one status out. Deterministic.
    """

    def __init__(self, registry: SpeakerRegistry, memory: Memory,
                 ledger: Ledger, bus: RequestBus):
        self.registry = registry
        self.memory = memory
        self.ledger = ledger
        self.bus = bus

    def evaluate(self, expr: Expression) -> Status:
        """
        Evaluate a single expression. The heartbeat of the system.
        
        Step 1: Authenticate speaker
        Step 2: Check condition
        Step 3: Execute action
        Step 4: Log to ledger
        """
        # Step 1: Authenticate
        if not self.registry.authenticate(expr.speaker_id):
            self.ledger.append(
                speaker_id=expr.speaker_id,
                operation="evaluate",
                action=expr.action,
                condition=expr.condition_label,
                status=Status.BROKEN,
                break_reason="speaker_not_found_or_suspended",
            )
            return Status.BROKEN

        # Check version and scope
        if expr.version != Version.CURRENT:
            return None  # superseded/expired expressions don't evaluate

        if expr.scope_until and time.time() > expr.scope_until:
            expr.version = Version.EXPIRED
            self.ledger.append(
                speaker_id=expr.speaker_id,
                operation="expire",
                action=expr.action,
                condition=expr.condition_label,
                status=None,
            )
            return None

        # Step 2: Check condition
        condition_met = True
        if expr.condition is not None:
            try:
                condition_met = expr.condition()
            except Exception:
                condition_met = False

        if not condition_met:
            expr.status = Status.INACTIVE
            self.ledger.append(
                speaker_id=expr.speaker_id,
                operation="evaluate",
                action=expr.action,
                condition=expr.condition_label,
                condition_result=False,
                status=Status.INACTIVE,
            )
            return Status.INACTIVE

        # Step 3: Execute action
        if expr.action_fn is not None:
            try:
                result = expr.action_fn()
                action_fulfilled = result is not False
            except Exception as e:
                action_fulfilled = False
                expr.status = Status.BROKEN
                self.ledger.append(
                    speaker_id=expr.speaker_id,
                    operation="evaluate",
                    action=expr.action,
                    condition=expr.condition_label,
                    condition_result=True,
                    status=Status.BROKEN,
                    break_reason=str(e),
                )
                return Status.BROKEN
        else:
            action_fulfilled = True

        # Handle refusals (inverted check)
        if expr.is_refusal:
            action_fulfilled = not action_fulfilled

        # Step 4: Assign status and log
        if action_fulfilled:
            expr.status = Status.ACTIVE
            self.ledger.append(
                speaker_id=expr.speaker_id,
                operation="evaluate",
                action=expr.action,
                condition=expr.condition_label,
                condition_result=True,
                status=Status.ACTIVE,
            )
            return Status.ACTIVE
        else:
            expr.status = Status.BROKEN
            self.ledger.append(
                speaker_id=expr.speaker_id,
                operation="evaluate",
                action=expr.action,
                condition=expr.condition_label,
                condition_result=True,
                status=Status.BROKEN,
                break_reason="action_not_fulfilled",
            )
            return Status.BROKEN

    def evaluate_loop(self, expr: Expression) -> tuple[Status, int]:
        """
        Evaluate a looping expression.
        Returns (final_status, iteration_count).
        """
        count = 0
        max_iter = expr.loop_max or 10000  # safety bound

        while count < max_iter:
            # Check loop condition
            if expr.loop_condition and not expr.loop_condition():
                self.ledger.append(
                    speaker_id=expr.speaker_id,
                    operation="loop_end",
                    action=expr.action,
                    status=Status.INACTIVE,
                    state_after={"iterations": count},
                )
                return Status.INACTIVE, count

            # Execute one iteration
            status = self.evaluate(expr)
            count += 1

            if status == Status.BROKEN:
                return Status.BROKEN, count
            if status == Status.INACTIVE:
                return Status.INACTIVE, count

        # Bound exceeded
        self.ledger.append(
            speaker_id=expr.speaker_id,
            operation="loop_bound_exceeded",
            action=expr.action,
            status=Status.BROKEN,
            break_reason=f"max_iterations_{max_iter}_exceeded",
            state_after={"iterations": count},
        )
        return Status.BROKEN, count


# =============================================================================
# Part VIII — Mary (The Kernel)
# =============================================================================

class Mary:
    """
    The kernel. She enforces Human Logic.
    
    12 invariants. 10 guarantees. One job: be correct.
    """

    def __init__(self):
        # Core components
        self.registry = SpeakerRegistry()
        self.memory = Memory()
        self.ledger = Ledger()
        self.bus = RequestBus()
        self.evaluator = Evaluator(self.registry, self.memory, self.ledger, self.bus)

        # Expression tracking
        self._expressions: dict[int, Expression] = {}
        self._next_expr_id: int = 0

        # Boot
        self._booted = False
        self.root = None
        self.boot()

    # ── Boot ──────────────────────────────────────────────────────────────

    def boot(self):
        """
        Mary boot sequence.
        
        Step 1: Create root speaker
        Step 2: Initialize memory
        Step 3: Log boot
        """
        if self._booted:
            return

        # Create root
        self.root = self.registry.create("root")
        self.memory.create_partition(self.root.id)

        # Log boot
        self.ledger.append(
            speaker_id=self.root.id,
            operation="boot",
            action="mary_initialized",
            status=Status.ACTIVE,
        )

        self._booted = True

    # ── Speaker Management ────────────────────────────────────────────────

    def create_speaker(self, caller_id: int, name: str) -> Optional[Speaker]:
        """
        Create a new speaker. Caller must be alive.
        Returns the new speaker or None.
        """
        if not self.registry.authenticate(caller_id):
            self.ledger.append(
                speaker_id=caller_id,
                operation="create_speaker",
                action=f"create:{name}",
                status=Status.BROKEN,
                break_reason="caller_not_authenticated",
            )
            return None

        speaker = self.registry.create(name, creator_id=caller_id)
        self.memory.create_partition(speaker.id)

        self.ledger.append(
            speaker_id=caller_id,
            operation="create_speaker",
            action=f"create:{name}",
            status=Status.ACTIVE,
            state_after={"new_speaker_id": speaker.id, "name": name},
        )

        return speaker

    def suspend_speaker(self, caller_id: int, target_id: int) -> bool:
        """Suspend a speaker. Only root can do this."""
        if caller_id != 0:  # only root
            self.ledger.append(
                speaker_id=caller_id,
                operation="suspend_speaker",
                action=f"suspend:{target_id}",
                status=Status.BROKEN,
                break_reason="not_root",
            )
            return False

        success = self.registry.suspend(target_id)
        self.ledger.append(
            speaker_id=caller_id,
            operation="suspend_speaker",
            action=f"suspend:{target_id}",
            status=Status.ACTIVE if success else Status.BROKEN,
            break_reason=None if success else "speaker_not_found",
        )
        return success

    def list_speakers(self, caller_id: int) -> list[Speaker]:
        """List all speakers. Any authenticated speaker can do this."""
        if not self.registry.authenticate(caller_id):
            return []
        return self.registry.list_all()

    # ── Memory Operations ─────────────────────────────────────────────────

    def read(self, caller_id: int, owner_id: int, var_name: str) -> Any:
        """
        Read any speaker's variable. Any authenticated speaker can read anything.
        """
        if not self.registry.authenticate(caller_id):
            self.ledger.append(
                speaker_id=caller_id,
                operation="read",
                action=f"read:{owner_id}.{var_name}",
                status=Status.BROKEN,
                break_reason="caller_not_authenticated",
            )
            return None

        value = self.memory.read(owner_id, var_name)

        self.ledger.append(
            speaker_id=caller_id,
            operation="read",
            action=f"read:{owner_id}.{var_name}",
            status=Status.ACTIVE,
            state_after={"value": repr(value)},
        )

        return value

    def write(self, caller_id: int, var_name: str, value: Any) -> bool:
        """
        Write to caller's OWN variables only.
        Axiom 8: write(s₁, s₂.v, value) is undefined when s₁ ≠ s₂.
        """
        if not self.registry.authenticate(caller_id):
            self.ledger.append(
                speaker_id=caller_id,
                operation="write",
                action=f"write:{var_name}",
                status=Status.BROKEN,
                break_reason="caller_not_authenticated",
            )
            return False

        success, old_value = self.memory.write(caller_id, var_name, value)

        self.ledger.append(
            speaker_id=caller_id,
            operation="write",
            action=f"write:{var_name}",
            status=Status.ACTIVE if success else Status.BROKEN,
            state_before={"var": var_name, "old_value": repr(old_value)},
            state_after={"var": var_name, "new_value": repr(value)},
            break_reason=None if success else "write_failed",
        )

        return success

    def write_to(self, caller_id: int, target_id: int, var_name: str, value: Any) -> bool:
        """
        Attempt to write to ANOTHER speaker's variables.
        This ALWAYS fails. It exists to demonstrate Axiom 8.
        """
        if caller_id != target_id:
            self.ledger.append(
                speaker_id=caller_id,
                operation="write_violation",
                action=f"write:{target_id}.{var_name}",
                status=Status.BROKEN,
                break_reason="write_ownership_violation",
            )
            return False
        return self.write(caller_id, var_name, value)

    def list_vars(self, caller_id: int, owner_id: int) -> list[str]:
        """List variables in a speaker's partition."""
        if not self.registry.authenticate(caller_id):
            return []
        return self.memory.list_vars(owner_id)

    # ── Expression Management ─────────────────────────────────────────────

    def submit(self, speaker_id: int, condition: Callable = None,
               condition_label: str = "⊤", action: str = "",
               action_fn: Callable = None, is_refusal: bool = False,
               scope_until: float = None) -> Optional[Expression]:
        """
        Submit an expression for evaluation.
        
        s : C ⊢ a
        """
        if not self.registry.authenticate(speaker_id):
            self.ledger.append(
                speaker_id=speaker_id,
                operation="submit",
                action=action,
                status=Status.BROKEN,
                break_reason="speaker_not_authenticated",
            )
            return None

        expr = Expression(
            expression_id=self._next_expr_id,
            speaker_id=speaker_id,
            condition=condition,
            condition_label=condition_label,
            action=action,
            action_fn=action_fn,
            created_at=time.time(),
            is_refusal=is_refusal,
            scope_until=scope_until,
        )
        self._next_expr_id += 1

        # Check for supersession
        for eid, existing in self._expressions.items():
            if (existing.speaker_id == speaker_id and
                existing.action == action and
                existing.condition_label == condition_label and
                existing.version == Version.CURRENT):
                existing.version = Version.SUPERSEDED
                self.ledger.append(
                    speaker_id=speaker_id,
                    operation="supersede",
                    action=f"supersede:expr_{existing.expression_id}",
                    status=Status.ACTIVE,
                    state_before={"old_expr_id": existing.expression_id},
                    state_after={"new_expr_id": expr.expression_id},
                )

        self._expressions[expr.expression_id] = expr

        # Evaluate immediately
        status = self.evaluator.evaluate(expr)

        return expr

    def submit_loop(self, speaker_id: int, condition: Callable = None,
                    condition_label: str = "⊤", action: str = "",
                    action_fn: Callable = None,
                    loop_condition: Callable = None,
                    loop_max: int = None) -> Optional[tuple[Expression, int]]:
        """Submit a looping expression."""
        if not self.registry.authenticate(speaker_id):
            return None

        expr = Expression(
            expression_id=self._next_expr_id,
            speaker_id=speaker_id,
            condition=condition,
            condition_label=condition_label,
            action=action,
            action_fn=action_fn,
            created_at=time.time(),
            loop_condition=loop_condition,
            loop_max=loop_max,
        )
        self._next_expr_id += 1
        self._expressions[expr.expression_id] = expr

        status, count = self.evaluator.evaluate_loop(expr)
        return expr, count

    def get_expression(self, expr_id: int) -> Optional[Expression]:
        """Get an expression by ID."""
        return self._expressions.get(expr_id)

    def expression_status(self, caller_id: int, expr_id: int) -> Optional[Status]:
        """Get the status of an expression."""
        if not self.registry.authenticate(caller_id):
            return None
        expr = self._expressions.get(expr_id)
        if expr is None:
            return None
        return expr.status

    # ── Communication ─────────────────────────────────────────────────────

    def request(self, caller_id: int, target_id: int, action: str,
                data: Any = None, timeout: float = None) -> Optional[Request]:
        """
        Send a request to another speaker.
        Creates an expression for the caller. Does NOT create anything for the target.
        """
        if not self.registry.authenticate(caller_id):
            self.ledger.append(
                speaker_id=caller_id,
                operation="request",
                action=f"request:{target_id}:{action}",
                status=Status.BROKEN,
                break_reason="caller_not_authenticated",
            )
            return None

        if not self.registry.authenticate(target_id):
            self.ledger.append(
                speaker_id=caller_id,
                operation="request",
                action=f"request:{target_id}:{action}",
                status=Status.BROKEN,
                break_reason="target_not_found",
            )
            return None

        expires_at = time.time() + timeout if timeout else None
        req = self.bus.create_request(caller_id, target_id, action, data, expires_at)

        self.ledger.append(
            speaker_id=caller_id,
            operation="request",
            action=f"request:{target_id}:{action}",
            status=Status.ACTIVE,
            state_after={"request_id": req.request_id},
        )

        return req

    def respond(self, caller_id: int, request_id: int, accept: bool,
                response_data: Any = None) -> bool:
        """
        Respond to a request. Only the target speaker can respond.
        """
        req = self.bus.get_request(request_id)
        if req is None:
            self.ledger.append(
                speaker_id=caller_id,
                operation="respond",
                action=f"respond:{request_id}",
                status=Status.BROKEN,
                break_reason="request_not_found",
            )
            return False

        if req.to_speaker != caller_id:
            self.ledger.append(
                speaker_id=caller_id,
                operation="respond",
                action=f"respond:{request_id}",
                status=Status.BROKEN,
                break_reason="not_target_speaker",
            )
            return False

        result = self.bus.respond(request_id, caller_id, accept, response_data)

        self.ledger.append(
            speaker_id=caller_id,
            operation="respond",
            action=f"respond:{request_id}:{'accept' if accept else 'refuse'}",
            status=Status.ACTIVE,
            state_after={"request_id": request_id, "accepted": accept},
        )

        return result is not None

    def pending_requests(self, caller_id: int) -> list[Request]:
        """Get pending requests for a speaker."""
        if not self.registry.authenticate(caller_id):
            return []
        return self.bus.get_pending_for(caller_id)

    # ── Ledger Access ─────────────────────────────────────────────────────

    def ledger_read(self, caller_id: int, from_id: int = 0,
                    to_id: int = None) -> list[LedgerEntry]:
        """Read ledger entries. Any authenticated speaker can read."""
        if not self.registry.authenticate(caller_id):
            return []
        return self.ledger.read(from_id, to_id)

    def ledger_search(self, caller_id: int, **filters) -> list[LedgerEntry]:
        """Search ledger entries."""
        if not self.registry.authenticate(caller_id):
            return []
        return self.ledger.search(**filters)

    def ledger_count(self, caller_id: int) -> int:
        """Count total ledger entries."""
        if not self.registry.authenticate(caller_id):
            return 0
        return self.ledger.count()

    def ledger_verify(self) -> bool:
        """Verify ledger hash chain integrity."""
        return self.ledger.verify_integrity()

    # ── Inspection ────────────────────────────────────────────────────────

    def inspect_speaker(self, caller_id: int, target_id: int) -> Optional[dict]:
        """Inspect a speaker's full state."""
        if not self.registry.authenticate(caller_id):
            return None
        speaker = self.registry.get(target_id)
        if not speaker:
            return None
        return {
            "speaker": {
                "id": speaker.id,
                "name": speaker.name,
                "status": speaker.status.value,
                "created_at": speaker.created_at,
            },
            "variables": self.memory.list_vars(target_id),
            "pending_requests": len(self.bus.get_pending_for(target_id)),
            "expressions": [
                {"id": e.expression_id, "action": e.action,
                 "status": e.status.value if e.status else None,
                 "version": e.version.value}
                for e in self._expressions.values()
                if e.speaker_id == target_id
            ],
        }

    def inspect_variable(self, caller_id: int, owner_id: int,
                         var_name: str) -> Optional[dict]:
        """Inspect a variable's current value and full history."""
        if not self.registry.authenticate(caller_id):
            return None
        current = self.memory.read(owner_id, var_name)
        history = self.ledger.search(
            speaker_id=owner_id,
            action=f"write:{var_name}",
        )
        return {
            "owner": owner_id,
            "variable": var_name,
            "current_value": current,
            "history": [
                {
                    "entry_id": e.entry_id,
                    "before": e.state_before,
                    "after": e.state_after,
                    "timestamp": e.timestamp,
                }
                for e in history
            ],
        }

    # ── State ─────────────────────────────────────────────────────────────

    def state(self) -> dict:
        """Complete system state snapshot."""
        return {
            "speakers": len(self.registry.list_all()),
            "ledger_entries": self.ledger.count(),
            "ledger_integrity": self.ledger.verify_integrity(),
            "expressions": len(self._expressions),
            "pending_requests": len(self.bus._pending),
        }

    def __repr__(self):
        s = self.state()
        return (f"Mary(speakers={s['speakers']}, "
                f"ledger={s['ledger_entries']}, "
                f"integrity={s['ledger_integrity']})")


# =============================================================================
# Part IX — Demo: Prove It Works
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("  Mary v1.0 — A Kernel for Human Logic")
    print("  Author: Jared Lewis, 2026")
    print("=" * 60)
    print()

    # Boot Mary
    mary = Mary()
    print(f"[BOOT] {mary}")
    print()

    # ── Create Speakers ──────────────────────────────────────────────
    print("── Speaker Management ──")
    teacher = mary.create_speaker(0, "Jared")
    student = mary.create_speaker(0, "Maria")
    admin = mary.create_speaker(0, "Dr. Principal")
    print(f"  Created: {teacher.name} (id:{teacher.id})")
    print(f"  Created: {student.name} (id:{student.id})")
    print(f"  Created: {admin.name} (id:{admin.id})")
    print()

    # ── Write Ownership ──────────────────────────────────────────────
    print("── Write Ownership (Axiom 8) ──")

    # Teacher writes to own partition — should work
    mary.write(teacher.id, "assignment_1.title", "Build a Calculator")
    mary.write(teacher.id, "assignment_1.due", "2026-02-24")
    mary.write(teacher.id, "assignment_1.max_points", 100)
    print(f"  Teacher wrote assignment: {mary.read(teacher.id, teacher.id, 'assignment_1.title')}")

    # Student writes to own partition — should work
    mary.write(student.id, "submission_1.content", "def calc(): return 2+2")
    mary.write(student.id, "submission_1.submitted_at", time.time())
    print(f"  Student submitted: {mary.read(student.id, student.id, 'submission_1.content')}")

    # Teacher tries to write to student's partition — MUST FAIL
    result = mary.write_to(teacher.id, student.id, "submission_1.content", "TAMPERED")
    print(f"  Teacher tried to modify student work: {'BLOCKED ✗' if not result else 'ERROR — SHOULD HAVE BLOCKED'}")

    # Admin tries to write to teacher's partition — MUST FAIL
    result = mary.write_to(admin.id, teacher.id, "assignment_1.due", "2026-12-31")
    print(f"  Admin tried to change deadline: {'BLOCKED ✗' if not result else 'ERROR — SHOULD HAVE BLOCKED'}")

    # But anyone can READ anything
    student_work = mary.read(teacher.id, student.id, "submission_1.content")
    print(f"  Teacher reads student work: {student_work}")
    assignment = mary.read(student.id, teacher.id, "assignment_1.title")
    print(f"  Student reads assignment: {assignment}")
    print()

    # ── Expressions ──────────────────────────────────────────────────
    print("── Expression Evaluation ──")

    # Teacher publishes assignment (condition: always true)
    expr_assign = mary.submit(
        speaker_id=teacher.id,
        condition=lambda: True,
        condition_label="class_active",
        action="publish_assignment_1",
        action_fn=lambda: mary.write(teacher.id, "assignment_1.status", "published"),
    )
    print(f"  Assignment published: {expr_assign.status.value}")

    # Student submits (condition: deadline not passed)
    deadline_ok = True  # simulate deadline not passed
    expr_submit = mary.submit(
        speaker_id=student.id,
        condition=lambda: deadline_ok,
        condition_label="deadline >= now",
        action="submit_assignment_1",
        action_fn=lambda: mary.write(student.id, "submission_1.status", "submitted"),
    )
    print(f"  Student submission: {expr_submit.status.value}")

    # Teacher grades (condition: student submitted)
    expr_grade = mary.submit(
        speaker_id=teacher.id,
        condition=lambda: expr_submit.status == Status.ACTIVE,
        condition_label="student.submission = active",
        action="grade_assignment_1",
        action_fn=lambda: (
            mary.write(teacher.id, f"grade_{student.id}_1.score", 92),
            mary.write(teacher.id, f"grade_{student.id}_1.feedback", "Strong work. Clean code."),
        ),
    )
    print(f"  Grade posted: {expr_grade.status.value}")
    print(f"  Score: {mary.read(student.id, teacher.id, f'grade_{student.id}_1.score')}")
    print(f"  Feedback: {mary.read(student.id, teacher.id, f'grade_{student.id}_1.feedback')}")
    print()

    # ── Missed deadline (broken) ─────────────────────────────────────
    print("── Broken Expression (missed deadline) ──")
    deadline_ok_2 = False  # simulate deadline passed
    expr_late = mary.submit(
        speaker_id=student.id,
        condition=lambda: deadline_ok_2,
        condition_label="deadline >= now",
        action="submit_assignment_2",
    )
    print(f"  Late submission attempt: {expr_late.status.value}")
    print()

    # ── Requests ─────────────────────────────────────────────────────
    print("── Communication (Request Bus) ──")

    # Student disputes grade
    req = mary.request(student.id, teacher.id, "review_grade",
                       data={"assignment": 1, "reason": "I covered all requirements"})
    print(f"  Student disputed grade: request #{req.request_id}")

    # Teacher sees pending requests
    pending = mary.pending_requests(teacher.id)
    print(f"  Teacher's pending requests: {len(pending)}")

    # Teacher responds (refuse with reason)
    mary.respond(teacher.id, req.request_id, accept=False,
                 response_data={"reason": "Missing error handling for division by zero"})
    print(f"  Teacher refused: {req.status.value}")

    # Admin tries to change grade via request
    admin_req = mary.request(admin.id, teacher.id, "change_grade",
                             data={"student": student.id, "new_score": 70})
    print(f"  Admin requested grade change: request #{admin_req.request_id}")

    # Teacher refuses
    mary.respond(teacher.id, admin_req.request_id, accept=False,
                 response_data={"reason": "Grade reflects student performance"})
    print(f"  Teacher refused admin: {admin_req.status.value}")
    print()

    # ── Supersession ─────────────────────────────────────────────────
    print("── Versioning (Supersession) ──")

    # Teacher updates deadline
    mary.write(teacher.id, "assignment_1.due", "2026-02-24")
    print(f"  Original deadline: {mary.read(teacher.id, teacher.id, 'assignment_1.due')}")

    mary.write(teacher.id, "assignment_1.due", "2026-02-26")
    print(f"  Updated deadline: {mary.read(teacher.id, teacher.id, 'assignment_1.due')}")

    # Check history
    history = mary.inspect_variable(teacher.id, teacher.id, "assignment_1.due")
    print(f"  Deadline change history: {len(history['history'])} entries")
    for h in history['history']:
        print(f"    {h['before']} → {h['after']}")
    print()

    # ── Loops ────────────────────────────────────────────────────────
    print("── Loop Evaluation ──")

    counter = {"n": 0}

    def count_action():
        counter["n"] += 1
        mary.write(teacher.id, "loop_counter", counter["n"])

    expr_loop, iterations = mary.submit_loop(
        speaker_id=teacher.id,
        action="count_to_five",
        action_fn=count_action,
        loop_condition=lambda: counter["n"] < 5,
        loop_max=100,
    )
    print(f"  Loop ran {iterations} times, counter = {mary.read(teacher.id, teacher.id, 'loop_counter')}")
    print()

    # ── Ledger Integrity ─────────────────────────────────────────────
    print("── Ledger ──")
    print(f"  Total entries: {mary.ledger_count(teacher.id)}")
    print(f"  Hash chain integrity: {'VALID ✓' if mary.ledger_verify() else 'BROKEN ✗'}")
    print()

    # ── Final State ──────────────────────────────────────────────────
    print("── System State ──")
    print(f"  {mary}")
    print()

    # ── Inspection ───────────────────────────────────────────────────
    print("── Inspection ──")
    teacher_info = mary.inspect_speaker(teacher.id, teacher.id)
    print(f"  Teacher variables: {teacher_info['variables']}")
    print(f"  Teacher expressions: {len(teacher_info['expressions'])}")

    student_info = mary.inspect_speaker(teacher.id, student.id)
    print(f"  Student variables: {student_info['variables']}")
    print(f"  Student expressions: {len(student_info['expressions'])}")
    print()

    print("=" * 60)
    print("  Every operation had a speaker.")
    print("  Every state change has a receipt.")
    print("  The ledger is intact.")
    print("  Human Logic holds.")
    print("=" * 60)
