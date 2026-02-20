# Mary v1.0

### A Kernel for Human Logic

**Author:** Jared Lewis
**Date:** February 19, 2026

---

## Part I — Purpose

### 1. What Mary Is

Mary is a kernel. She enforces Human Logic on Von Neumann hardware.

The hardware underneath Mary is shared memory, destructive writes, anonymous execution. Mary's job is to make that hardware behave as if it were a Human Logic machine — partitioned memory, non-destructive state, attributed execution.

Mary does five things:

1. Manages speakers.
2. Partitions and protects memory.
3. Maintains the ledger.
4. Evaluates expressions.
5. Routes communication between speakers.

Mary does not render interfaces. Mary does not manage files in the traditional sense. Mary does not schedule processes the way Unix does. Mary evaluates expressions for speakers. That is all.

### 2. What Mary Is Not

Mary is not an operating system. Helena is the operating system. Mary is the layer beneath Helena, the same way Darwin is the layer beneath macOS.

Mary is not an application runtime. She does not know what a "world" or an "app" is. She knows speakers, expressions, memory, and the ledger.

Mary is not a database. The ledger is append-only storage, but Mary is not optimized for queries. Inspection and search are Helena's responsibility.

### 3. The Stack

```
Hardware        — Von Neumann silicon
Mary            — Kernel (enforces Human Logic)
Helena          — Operating system (worlds, apps, human interaction)
Worlds          — Applications running on Helena
```

---

## Part II — Speaker Management

### 4. Speaker Registry

**Definition 4.1 — Speaker Record.** A speaker record is a tuple:

```
speaker = (id, name, created_at, status)
```

Where:
- `id` — a unique, immutable identifier assigned at creation. Never reused.
- `name` — a human-readable label. Mutable by the speaker only.
- `created_at` — timestamp of creation. Immutable.
- `status` — `alive` or `suspended`

**Definition 4.2 — Speaker Registry.** The registry `R` is the set of all speaker records:

```
R = {speaker₁, speaker₂, ..., speakerₙ}
```

The registry is append-only. Speakers are never deleted. A speaker may be suspended (they cannot issue new expressions) but their history remains.

### 5. Speaker Authentication

**Definition 5.1 — Authentication.** Every call to Mary must include a speaker identity:

```
call(speaker_id, operation, params) → result
```

If `speaker_id` is not in `R` or is suspended, the call is rejected. No operation executes without a verified speaker.

**Definition 5.2 — The Root Speaker.** At system initialization, Mary creates one speaker:

```
root = (id: 0, name: "root", created_at: t₀, status: alive)
```

The root speaker can create other speakers. This is the only privilege root has. Root cannot write to other speakers' memory. Root cannot issue expressions on behalf of other speakers. Root follows all the same rules. Root is human.

**Definition 5.3 — Speaker Creation.** A living speaker may create new speakers:

```
s₁ : ⊤ ⊢ create_speaker(name) → new_id
```

This is an expression. It goes in the ledger. The new speaker's `created_at` is the current time. The creating speaker has no ongoing authority over the created speaker.

**Theorem 5.1 — No Orphan Speakers.** Every speaker except root has a creation expression in the ledger attributed to an existing speaker.

*Proof.* Speaker creation is an expression (Definition 5.3). Expressions require speakers (Axiom 1). The expression is recorded in the ledger (Axiom 5). Root is created by Mary at initialization, not by expression. All other speakers are created by expression. Therefore every non-root speaker has a traceable origin. ∎

---

## Part III — Memory

### 6. Memory Partitions

**Definition 6.1 — Partition.** Each speaker owns a memory partition:

```
M(s) = {(v, value) | v ∈ Var}
```

A partition is a key-value store. Keys are variable names. Values are elements of `U`.

**Definition 6.2 — System Memory.** The total system memory is the union of all partitions:

```
M = ⋃{M(s) | s ∈ R, s.status = alive}
```

Partitions do not overlap. No variable belongs to two speakers.

### 7. Memory Operations

**Definition 7.1 — Read.** Reading is unrestricted:

```
mary.read(s_caller, s_owner, var) → value
```

Any speaker may read any variable in any partition. Reading does not modify any state. Reading is logged in the ledger.

**Definition 7.2 — Write.** Writing is restricted:

```
mary.write(s_caller, var, value):
  if var ∉ M(s_caller) and var is new → create var in M(s_caller)
  if var ∈ M(s_caller) → update var in M(s_caller)
  if var ∈ M(s_other) where s_other ≠ s_caller → REJECT
```

**Implementation 7.1 — Hardware Enforcement.** On Von Neumann hardware, memory partitions are enforced through page-level protection. Each speaker's partition maps to a set of memory pages. The page table marks:

- Speaker's own pages: read/write
- All other pages: read-only
- Kernel (Mary) pages: no access from speakers

Context switches between speakers update the page table. This is how modern CPUs already work for process isolation — Mary simply maps it to speaker ownership instead of process IDs.

**Definition 7.3 — Write Record.** Every write produces a ledger entry:

```
write_record = (speaker, var, old_value, new_value, timestamp)
```

The old value is preserved in the ledger before the new value is written. This is how Mary achieves non-destructive state on destructive hardware. The hardware overwrites. The ledger remembers.

**Theorem 7.1 — Memory Safety from Axioms.**

Mary's memory protection is not a security feature. It is a mathematical consequence of Axiom 8 (Write Ownership).

*Proof.* Axiom 8 states: `write(s₁, s₂.v, value)` is undefined when `s₁ ≠ s₂`. Mary's write operation (Definition 7.2) rejects cross-speaker writes. The hardware enforcement (Implementation 7.1) makes this rejection physical, not just logical. The axiom requires it. Mary enforces it. The hardware implements it. ∎

---

## Part IV — The Ledger

### 8. Ledger Structure

**Definition 8.1 — Ledger Entry.** Every operation in Mary produces a ledger entry:

```
entry = (
  entry_id,          — unique, sequential, immutable
  speaker_id,        — who
  operation,         — what kind (expression, read, write, request, response, create_speaker)
  condition,         — the flag that was checked
  condition_result,  — ⊤ or ⊥
  action,            — what was attempted
  status,            — active, inactive, or broken
  state_before,      — relevant state snapshot before the operation
  state_after,       — relevant state snapshot after the operation
  timestamp          — when
)
```

**Definition 8.2 — Ledger.** The ledger `L` is a sequence of entries:

```
L = [entry₁, entry₂, ..., entryₙ]
```

Ordered by `entry_id`. Strictly sequential. No gaps.

### 9. Ledger Rules

**Rule 9.1 — Append Only.** New entries are added to the end of `L`. No existing entry is modified or removed. Ever.

**Rule 9.2 — Total Capture.** Every operation that touches state produces an entry. No exceptions. Reads, writes, expression evaluations, requests, responses, speaker creations — everything.

**Rule 9.3 — Sequential Consistency.** Entries are assigned `entry_id` values in the order they are committed. If entry A is committed before entry B, then `A.entry_id < B.entry_id`.

**Implementation 9.1 — Storage.** The ledger is stored as a sequential log file. New entries are appended to the end. The file is opened in append mode only. Mary does not open the ledger in write mode. The operating system's file append is atomic at the entry level.

For durability: the ledger is fsynced after each entry. Performance optimization (batching, write-ahead buffering) is permitted as long as no entry is lost and ordering is preserved.

**Implementation 9.2 — Integrity Verification.** Each entry contains a hash of the previous entry:

```
entry.prev_hash = hash(entry[n-1])
```

This forms a hash chain. If any entry is modified or removed, the chain breaks. Verification walks the chain and confirms continuity. This is not blockchain consensus — it is a single-writer integrity check. Mary is the only writer.

**Theorem 9.1 — Replay Correctness.**

Given the initial state `State(t₀)` and the ledger `L`, any state `State(tₙ)` can be exactly reconstructed by replaying entries in order.

*Proof.* By Human Logic Theorem T25 (Full Replayability), the computation model guarantees that initial state plus the sequence of expressions deterministically produces every subsequent state. Mary's ledger captures every expression with its full context (condition, result, state snapshots). Replaying entries in `entry_id` order through Mary's evaluator reproduces each state transition. The hash chain guarantees no entries were modified or removed. Therefore replay is correct. ∎

---

## Part V — The Evaluator

### 10. Core Evaluation

**Definition 10.1 — The Evaluator.** The evaluator is Mary's central function. It takes an expression and the current state, and returns a status:

```
mary.evaluate(speaker, condition, action) → (status, state_change)
```

**Definition 10.2 — Evaluation Procedure.**

```
evaluate(s, C, a):

  STEP 1 — AUTHENTICATE
    if s ∉ R or s.status ≠ alive → reject("speaker not found")

  STEP 2 — CHECK CONDITION
    result ← resolve(C)
    if result = ⊥ → return (inactive, no_change)

  STEP 3 — EXECUTE ACTION
    match a:
      Write(s.v ← expr):
        value ← compute(expr)
        if value = ∅ → return (broken, no_change)    // undefined propagation
        old ← M(s)(v)
        M(s)(v) ← value
        return (active, {var: v, old: old, new: value})

      Refusal(¬a'):
        if a' occurred → return (broken, no_change)
        return (active, no_change)

      Choice(a₁ | a₂ | ... | aⱼ):
        selection ← speaker_selects()               // Mary waits for speaker input
        evaluate(s, ⊤, selection)                    // evaluate the chosen action

      Request(s₂, a'):
        entry ← create_request_entry(s, s₂, a')
        return (active, {request: entry})            // request is active. s₂ is unaffected.

      Call(s.f, args):
        bind params ← args
        for each eᵢ in s.f.body:
          evaluate(s, eᵢ.C, eᵢ.a)
        unbind params
        return (active, {return: last_result})

      Return(expr):
        value ← compute(expr)
        return (active, {return: value})

  STEP 4 — LOG
    append entry to L with all fields from Definition 8.1
```

### 11. Condition Resolution

**Definition 11.1 — Condition Resolver.** The resolver evaluates a condition against current state:

```
resolve(C):
  match C:
    WorldFlag(w):
      return W(w)                                    // look up world state

    SpeakerFlag(status(s', C', a') = σ):
      e ← find_current(s', C', a')                  // find the relevant expression
      if e = ∅ → return ⊥                            // no expression = unmet (silence)
      return (V(e) = σ)                              // does status match?

    SelfFlag:
      same as SpeakerFlag with s' = s

    C₁ ∧ C₂:
      if resolve(C₁) = ⊥ → return ⊥                 // short circuit
      return resolve(C₂)

    C₁ ∨ C₂:
      if resolve(C₁) = ⊤ → return ⊤                 // short circuit
      return resolve(C₂)
```

**Theorem 11.1 — Condition Resolution Terminates.**

*Proof.* World flags resolve in constant time (lookup). Speaker flags reference prior expressions, which were evaluated at earlier times. By the time ordering of `T`, no circular references exist — you cannot condition on a future expression. Compound conditions recurse on sub-conditions, each of which is strictly simpler. Therefore resolution terminates. ∎

### 12. Loop Execution

**Definition 12.1 — Loop Handler.**

```
mary.loop(s, C, a, bound):

  count ← 0
  while true:
    result ← resolve(C)
    if result = ⊥ → return (inactive, count)         // condition unmet, loop done
    if bound ≠ ∅ and count ≥ bound → return (broken, count)  // bound exceeded
    step_result ← evaluate(s, ⊤, a)                  // condition already checked
    if step_result.status = broken → return (broken, count)   // action failed
    count ← count + 1
    // ledger entry for this iteration was created in evaluate()
```

Every iteration is a separate ledger entry. If the loop runs 1000 times, there are 1000 entries. Every pass has a receipt.

---

## Part VI — The Request Bus

### 13. Communication Architecture

**Definition 13.1 — Request Bus.** The request bus is Mary's communication system. All inter-speaker communication flows through it. No speaker communicates directly with another speaker's memory.

```
bus = {
  pending:   [request₁, request₂, ...],
  resolved:  [response₁, response₂, ...]
}
```

### 14. Request Lifecycle

**Definition 14.1 — Request.**

```
mary.request(s_from, s_to, action):

  STEP 1 — AUTHENTICATE
    verify s_from is alive
    verify s_to is alive (if not, request is broken — can't ask a suspended speaker)

  STEP 2 — CREATE REQUEST
    req = (
      request_id,          — unique
      from: s_from,
      to: s_to,
      action: action,
      status: pending,
      created_at: now,
      expires_at: timeout or ∅
    )

  STEP 3 — LOG
    append to ledger as s_from's expression, status = active
    add to bus.pending

  STEP 4 — NOTIFY
    signal s_to that a request is waiting (does not force action)

  return req
```

**Definition 14.2 — Response.**

```
mary.respond(s_responder, request_id, response_type):

  STEP 1 — VALIDATE
    req ← find request by request_id
    if req.to ≠ s_responder → reject("not your request")
    if req.status ≠ pending → reject("already resolved")

  STEP 2 — PROCESS
    match response_type:
      accept(action_result):
        evaluate(s_responder, ⊤, req.action)         // s_responder does the thing
        req.status ← accepted

      refuse:
        req.status ← refused
        // s_responder issues a refusal expression

      // silent is not a response. it is the absence of one.
      // Mary does not process silence. silence just is.

  STEP 3 — LOG
    append to ledger as s_responder's expression
    move from bus.pending to bus.resolved

  STEP 4 — NOTIFY REQUESTER
    signal s_from that request has been resolved
```

**Definition 14.3 — Timeout.**

```
mary.check_timeouts():

  for each req in bus.pending:
    if req.expires_at ≠ ∅ and now > req.expires_at:
      req.status ← expired
      move to bus.resolved
      append timeout entry to ledger attributed to system clock, not to any speaker
      notify s_from
```

Timeout is not attributed to the responder. The responder didn't refuse — they didn't speak. Timeout is a clock event, not a speaker event.

### 15. Request Rules

**Rule 15.1 — No Bypass.** Speakers cannot access each other's memory partitions directly. All data transfer between speakers goes through the request bus. Even reading another speaker's variable goes through Mary (Definition 7.1).

**Rule 15.2 — No Batching of Identity.** A request comes from exactly one speaker and goes to exactly one speaker. No broadcast. No multicast at the kernel level. If a speaker wants to request the same action from five speakers, that is five requests.

*Rationale:* Each request is an expression. Each expression has one speaker. Broadcasting would create ambiguity about who committed to the request.

**Rule 15.3 — No Priority.** Requests are processed in the order they arrive. Mary does not prioritize one speaker over another. The bus is FIFO.

**Theorem 15.1 — Communication Safety.**

No inter-speaker communication results in unauthorized state change.

*Proof.* All communication flows through the request bus (Rule 15.1). A request creates an expression for `s_from` only (Definition 14.1 Step 3). A response creates an expression for `s_responder` only (Definition 14.2 Step 3). If `s_responder` accepts, the action is evaluated as `s_responder`'s expression, writing only to `s_responder`'s memory (Axiom 8). At no point does `s_from` write to `s_to`'s memory. ∎

---

## Part VII — Scheduling

### 16. Expression Scheduling

**Definition 16.1 — Evaluation Queue.** Mary maintains a queue of expressions awaiting evaluation:

```
Q = [e₁, e₂, ..., eₙ]
```

New expressions are added to the back. Evaluation proceeds from the front. FIFO.

**Definition 16.2 — Turn.** A turn is one evaluation cycle:

```
mary.turn():
  e ← Q.dequeue()
  result ← evaluate(e.speaker, e.condition, e.action)
  // ledger entry created during evaluate()
  // if e generated new expressions (chain reactions), they are enqueued
```

**Definition 16.3 — Tick.** A tick is one complete pass through all pending expressions:

```
mary.tick():
  snapshot ← copy(Q)
  for each e in snapshot:
    mary.turn()
  mary.check_timeouts()
```

A tick processes everything that was pending at the start of the tick. New expressions generated during the tick are processed in the next tick. This prevents infinite loops within a single tick.

**Theorem 16.1 — Tick Finiteness.**

Every tick terminates in finite time.

*Proof.* A tick processes a finite snapshot of the queue. Each evaluation is finite (Human Logic Theorem T14). New expressions generated during evaluation are queued for the next tick, not the current one. Therefore the current tick processes a bounded number of expressions, each in finite time. ∎

### 17. Multi-Speaker Concurrency

**Definition 17.1 — Concurrency Model.** Mary does not execute speakers in parallel. Mary is single-threaded. One expression evaluates at a time.

*Rationale:* Determinism. If two speakers could execute simultaneously and both read/write shared world flags, the result could depend on timing. Mary eliminates this by serializing all evaluation. The ledger order is the execution order. There is no ambiguity.

**Definition 17.2 — Speaker Fairness.** Mary processes expressions in arrival order. No speaker is starved. If two expressions arrive at the same time, they are ordered by speaker ID (lower first). This is arbitrary but deterministic.

**Theorem 17.1 — Deterministic Execution.**

Given the same initial state and the same sequence of incoming expressions, Mary produces the same ledger and the same final state.

*Proof.* Mary is single-threaded (Definition 17.1). Expression order is deterministic (FIFO with speaker ID tiebreaker, Definition 17.2). Each evaluation is deterministic (Human Logic Axiom 6). Therefore the entire execution sequence is deterministic. ∎

---

## Part VIII — World Interface

### 18. World Flags

**Definition 18.1 — World Flag Manager.** Mary maintains the set of world flags `W`:

```
W = {(name, value) | name ∈ WorldNames, value ∈ {⊤, ⊥}}
```

World flags represent external facts. They are not owned by any speaker.

**Definition 18.2 — World Flag Updates.** World flags are updated through two channels:

```
Channel 1 — Hardware sensors:
  Physical inputs (clock, network, hardware state) update world flags directly.
  These are logged in the ledger attributed to "world" (not a speaker).

Channel 2 — Helena:
  The operating system layer may update world flags to reflect application state.
  These are logged in the ledger attributed to Helena's system speaker.
```

**Definition 18.3 — Clock.** The system clock is a world flag:

```
W.clock = current_time
```

Mary updates this at the start of every tick. Time advances monotonically.

---

### 19. Helena Interface

**Definition 19.1 — System Calls.** Helena communicates with Mary through a fixed set of system calls:

```
SPEAKER MANAGEMENT:
  mary.create_speaker(caller, name) → speaker_id
  mary.suspend_speaker(caller, target) → status       // only root
  mary.list_speakers(caller) → [speaker_record]

MEMORY:
  mary.read(caller, owner, var) → value
  mary.write(caller, var, value) → status
  mary.list_vars(caller, owner) → [var_name]

EXPRESSIONS:
  mary.submit(caller, condition, action) → entry_id
  mary.submit_loop(caller, condition, action, bound) → entry_id
  mary.status(caller, entry_id) → status

COMMUNICATION:
  mary.request(caller, target, action) → request_id
  mary.respond(caller, request_id, response) → status
  mary.pending_requests(caller) → [request]

LEDGER:
  mary.ledger_read(caller, from_id, to_id) → [entry]
  mary.ledger_search(caller, filters) → [entry]
  mary.ledger_count(caller) → count

WORLD:
  mary.set_world_flag(caller, name, value) → status   // Helena only
  mary.get_world_flag(caller, name) → value
```

Every system call requires a caller (speaker). Every system call is logged. There are no backdoors.

**Definition 19.2 — Helena's Speaker.** Helena itself is a speaker in the system:

```
helena = (id: 1, name: "helena", created_at: t₀, status: alive)
```

Created by root at initialization. Helena issues expressions like any other speaker. Helena follows all the same rules. The only special privilege: Helena can update world flags (Definition 18.2, Channel 2).

---

## Part IX — Initialization

### 20. Boot Sequence

```
mary.boot():

  STEP 1 — INITIALIZE TIME
    t ← t₀
    T ← [t₀]

  STEP 2 — INITIALIZE LEDGER
    L ← []
    open ledger file in append mode

  STEP 3 — CREATE ROOT
    root ← (id: 0, name: "root", created_at: t₀, status: alive)
    R ← {root}
    append creation entry to L

  STEP 4 — CREATE HELENA
    helena ← (id: 1, name: "helena", created_at: t₀, status: alive)
    R ← R ∪ {helena}
    append creation entry to L (attributed to root)

  STEP 5 — INITIALIZE MEMORY
    M(root) ← {}
    M(helena) ← {}

  STEP 6 — INITIALIZE WORLD
    W ← {(clock, t₀)}

  STEP 7 — INITIALIZE QUEUES
    Q ← []
    bus.pending ← []
    bus.resolved ← []

  STEP 8 — START TICK LOOP
    while true:
      mary.tick()
      t ← t + 1
```

After Step 8, Mary is running. Helena can connect and begin issuing expressions through system calls. Speakers can be created. Worlds can be built.

**Theorem 20.1 — Boot Determinism.** Given the same hardware, Mary's boot sequence produces the same initial state every time.

*Proof.* Every step in the boot sequence is deterministic. Root and Helena are created with fixed IDs. Memory starts empty. The ledger starts empty. World flags start with only the clock. No randomness is introduced. ∎

---

## Part X — Error Handling

### 21. Error Model

Mary does not crash. Mary does not throw exceptions. Mary evaluates expressions and returns statuses.

**Definition 21.1 — Error as Broken.** When an operation cannot be completed, the expression is evaluated as `broken`. The reason is recorded in the ledger entry.

```
Possible break reasons:
  speaker_not_found      — speaker ID not in registry
  speaker_suspended      — speaker exists but is suspended
  write_violation         — attempted write to another speaker's memory
  undefined_variable     — referenced variable has no value
  division_by_zero       — arithmetic error
  bound_exceeded         — loop hit its maximum
  timeout                — request expired without response
  invalid_expression     — malformed input
```

**Definition 21.2 — Break Record.** When an expression breaks, the ledger entry includes:

```
entry.break_reason = reason
entry.break_context = {relevant state at time of break}
```

**Rule 21.1 — No Silent Failure.** Every failure produces a ledger entry. There is no operation in Mary that can fail without being recorded. If the ledger append itself fails (disk full, hardware error), Mary halts. A system that cannot record is a system that cannot be trusted.

**Definition 21.3 — Mary Halt.** If Mary cannot maintain ledger integrity, Mary stops:

```
mary.halt(reason):
  write halt reason to stderr
  fsync any buffered ledger entries
  stop tick loop
  // Mary does not attempt recovery. Recovery is a boot operation.
```

**Theorem 21.1 — Consistent Failure.**

The system is always in a known state. Either Mary is running and the ledger is complete, or Mary is halted and the ledger is complete up to the halt point.

*Proof.* Mary logs before executing (write records capture old values before writes). If Mary halts mid-operation, the incomplete operation was not committed to the ledger. On reboot, replay from the ledger reproduces the last consistent state. No partial operations survive. ∎

---

## Part XI — Security

### 22. Security Model

Mary's security is not a layer. It is not a feature. It is a consequence of the axioms.

**Theorem 22.1 — No Unauthorized State Change.**

A speaker's memory can only be changed by that speaker.

*Proof.* Axiom 8 (Write Ownership) + Implementation 7.1 (Hardware Enforcement) + Theorem 15.1 (Communication Safety). Writes are restricted at the logic level, enforced at the hardware level, and preserved through communication. ∎

**Theorem 22.2 — No Anonymous Operation.**

Every operation in the system is attributed to a speaker.

*Proof.* Every system call requires a caller (Definition 19.1). Every expression requires a speaker (Axiom 1). Every ledger entry records a speaker (Definition 8.1). The only non-speaker entries are world flag updates from hardware sensors, which are attributed to "world" — a named, known source. ∎

**Theorem 22.3 — Full Audit Trail.**

Every state change can be traced to its origin.

*Proof.* By Theorem 9.1 (Replay Correctness), the ledger contains every operation. By Theorem 22.2, every operation has a speaker. By Definition 7.3, every write records old and new values. Therefore any state can be traced backward through the ledger to the expression and speaker that caused it. ∎

**Theorem 22.4 — No Privilege Escalation.**

No sequence of valid operations can grant a speaker write access to another speaker's memory.

*Proof.* Write access is determined by Axiom 8, which is unconditional. It does not depend on state, permissions, roles, or any mutable value. It depends only on identity: `s₁ = s₂` or not. Since speaker IDs are immutable (Definition 4.1), no operation can change the identity relationship. Therefore no operation can change write access. ∎

---

## Part XII — Performance Considerations

### 23. Where Mary Is Slow

Mary is honest about her costs.

**Logging.** Every operation hits the ledger. This is I/O on every step. On spinning disks, this is the bottleneck. On SSDs, this is manageable. On NVMe, this is fast. On memory-mapped logs, this is very fast.

**Single-threaded evaluation.** Mary serializes everything for determinism. This means one core does all the work. Multi-core hardware is underutilized by Mary herself.

**No shared mutable state.** Speakers cannot share variables. Data must be copied through requests. This is slower than shared memory.

### 24. Where Mary Is Fast

**No locks.** Single-threaded means no mutexes, no deadlocks, no race conditions, no lock contention. The entire class of concurrency bugs does not exist.

**No garbage collection.** Memory is partitioned and speaker-owned. When a speaker is suspended, their partition can be archived in bulk. No reference counting. No mark-and-sweep.

**No permission checks at runtime.** Write ownership is enforced by page tables, which are checked by hardware, not software. Zero runtime cost for memory protection.

**Replay instead of backup.** Disaster recovery is replay from ledger, not restore from snapshot. The ledger is the backup.

### 25. Parallelism Strategy

Mary is single-threaded, but Helena can distribute work.

**Definition 25.1 — Sharding.** If speakers are independent (no speaker flags referencing each other), their expressions can be evaluated by separate Mary instances on separate cores. Each instance maintains its own ledger. Ledgers are merged by timestamp for global replay.

**Definition 25.2 — Shard Condition.** Two speakers `s₁` and `s₂` can be evaluated in parallel if and only if:

```
¬∃ e ∈ L: e.condition references status(s₁, ...) or status(s₂, ...)
           where e.speaker = s₂ or e.speaker = s₁
```

No cross-references, no dependency. Safe to parallelize.

Helena manages shard assignment. Mary instances do not coordinate with each other. They just enforce Human Logic on their assigned speakers.

---

## Part XIII — Formal Summary

### 26. Components

```
Mary = (R, M, L, W, Q, bus, evaluator, resolver, clock)

R         — Speaker Registry          (set of speaker records)
M         — Memory                    (partitioned, speaker-owned)
L         — Ledger                    (append-only, hash-chained)
W         — World Flags               (external facts)
Q         — Evaluation Queue          (FIFO)
bus       — Request Bus               (pending + resolved)
evaluator — Core evaluation function  (Definition 10.1)
resolver  — Condition resolver        (Definition 11.1)
clock     — Monotonic time source     (world flag)
```

### 27. Invariants

```
I1.  Every operation has a speaker.
I2.  Every operation is logged.
I3.  Memory is partitioned by speaker.
I4.  Writes are owner-only.
I5.  The ledger is append-only.
I6.  The ledger hash chain is unbroken.
I7.  Evaluation is single-threaded.
I8.  Evaluation is deterministic.
I9.  Requests are FIFO.
I10. No speaker is privileged (including root, except for speaker creation).
I11. No operation modifies another speaker's state without their explicit acceptance.
I12. Mary halts rather than operate with a broken ledger.
```

### 28. System Calls (Complete)

```
SPEAKERS:   create_speaker, suspend_speaker, list_speakers
MEMORY:     read, write, list_vars
EXPRESSIONS: submit, submit_loop, status
COMMUNICATION: request, respond, pending_requests
LEDGER:     ledger_read, ledger_search, ledger_count
WORLD:      set_world_flag, get_world_flag
```

### 29. Guarantees

Mary provides these guarantees by construction, not by configuration:

```
G1.  Memory safety            — Axiom 8 + hardware page tables
G2.  Full attribution         — Axiom 1 + logging
G3.  Deterministic replay     — single-threaded + append-only ledger
G4.  No privilege escalation  — immutable identity + unconditional write rules
G5.  No silent failure        — every break is logged
G6.  Finite execution         — bounded loops + finite ticks
G7.  Communication safety     — request bus + no direct memory access
G8.  Consistent recovery      — log-before-write + replay from ledger
G9.  Fair scheduling          — FIFO with deterministic tiebreaker
G10. Audit completeness       — total capture of all operations
```

---

## Part XIV — Closing

### 30. What Mary Proves

Mary proves that Human Logic is not just math on paper. It can be enforced on real hardware. The gap between the computation model and the silicon is bridgeable.

Von Neumann gave us shared memory, destructive writes, and anonymous execution. Mary sits on top of that hardware and says: partitioned memory, non-destructive state, attributed execution. The axioms hold. The theorems hold. The guarantees hold.

Mary is small. Twelve invariants. Twenty-eight system calls. One evaluation function. One ledger. One bus. She does not try to be clever. She tries to be correct.

Helena builds the world humans see. Mary makes sure the world humans see is honest.

---

*Mary v1.0*
*Jared Lewis, 2026*
*All rights reserved.*
