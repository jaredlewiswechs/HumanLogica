# Human Logic

A computation model where every operation has a speaker.

**Author:** Jared Lewis
**Date:** February 2026
**License:** All Rights Reserved
**Status:** Working prototype — math, kernel, OS, app, and language all functional

---

## Quick Start

```bash
# No dependencies. Python 3.10+.

# Run "Hello World" in Logica
python3 logica.py examples/hello_world.logica

# Run the full language demo (10 programs, axiom checks, everything)
python3 logica_demo.py

# Run the full stack demo (Mary → Helena → Classroom)
python3 demo.py

# Interactive Logica REPL
python3 logica.py

# Interactive Classroom shell
python3 classroom.py
```

---

## The Stack

```
┌─────────────────────────────────────────────┐
│  Logica           — programming language    │
├─────────────────────────────────────────────┤
│  Classroom World  — first application       │
├─────────────────────────────────────────────┤
│  Helena           — operating system        │
├─────────────────────────────────────────────┤
│  Mary             — kernel                  │
├─────────────────────────────────────────────┤
│  Human Logic      — computation model       │
└─────────────────────────────────────────────┘
```

| Layer | Purpose | Size |
|-------|---------|------|
| **Human Logic** | Formal model. 10 axioms, 25 theorems, Turing complete. | `human_logic_v2.md` |
| **Mary** | Kernel. Speaker registry, partitioned memory, append-only ledger, evaluator. | `mary.py` (1,238 lines) |
| **Helena** | OS. Worlds, files, identity, inspection, audit. | `helena.py` (485 lines) |
| **Classroom** | App. Assignments, submissions, grading, disputes, attendance. | `classroom.py` (1,069 lines) |
| **Logica** | Language. Lexer, parser, compiler (proof checker), runtime. | `logica/` (2,766 lines) |

Zero external dependencies. Standard library only.

---

## Logica Language

Logica compiles to Mary kernel operations. The compiler is a proof checker — programs that violate axioms don't compile.

### Syntax Overview

```python
# Declare speakers
speaker Teacher
speaker Student

# Code runs inside a speaker context
as Teacher {
    let assignment = "Build a Calculator"
    let max_points = 100
    speak "Assignment posted"
}

as Student {
    # Reading any speaker's data — always allowed
    let task = read Teacher.assignment

    # Writing to your own partition — works
    let submission = "def calc(): return 2+2"
    speak "Submitted"

    # Writing to another speaker's partition — won't compile
    # let Teacher.max_points = 200
    # → Axiom 8 violation: speaker 'Student' cannot write to 'Teacher' variables.
}
```

### Three-Valued Evaluation

Not boolean. Active / inactive / broken.

```python
when deadline_ok {
    speak "Submitted"        # active: condition met, action fulfilled
} otherwise {
    speak "Deadline passed"  # inactive: condition not met (not failure)
} broken {
    speak "Upload failed"    # broken: condition met, action failed
}
```

### Bounded Loops

Every loop requires a `max` bound. Axiom 9: no unbounded loops.

```python
while i < 10, max 1000 {
    let i = i + 1
}

# This won't compile:
# while true { speak "forever" }
# → Axiom 9 violation: every loop must have a 'max N' bound.
```

### Functions, Communication, Inspection

```python
as Mathematician {
    fn fibonacci(n) {
        let prev = 0
        let curr = 1
        let i = 2
        while i <= n, max 1000 {
            let next = prev + curr
            let prev = curr
            let curr = next
            let i = i + 1
        }
        return curr
    }

    let result = fibonacci(10)
    speak "fibonacci(10) = 55"
}

# Communication via requests (no forced speech — Axiom 7)
as Student { request Teacher "review_grade" }
as Teacher { respond refuse }

# Inspection
as Teacher {
    inspect Student
    history Student.submission
    ledger last 10
    verify ledger
}
```

### Keywords

| Category | Keywords |
|----------|----------|
| Identity | `speaker`, `as` |
| Variables | `let`, `read` |
| Expressions | `speak`, `when`, `otherwise`, `broken` |
| Control | `if`, `elif`, `else`, `pass`, `fail` |
| Functions | `fn`, `return` |
| Loops | `while`, `max` |
| Communication | `request`, `respond`, `accept`, `refuse` |
| Inspection | `inspect`, `history`, `ledger`, `verify` |
| Other | `world`, `seal` |
| Values | `active`, `inactive`, `true`, `false`, `none`, `not`, `and`, `or` |

### CLI

```bash
python3 logica.py <file.logica>        # Run a program
python3 logica.py --check <file>       # Check axioms without running
python3 logica.py --tokens <file>      # Show tokenization
python3 logica.py --ast <file>         # Show parsed AST
python3 logica.py                      # Interactive REPL
```

---

## Axioms Enforced

The compiler and runtime enforce all 10 axioms. Five at compile time, five through the Mary kernel.

### Compile Time

| # | Axiom | What it prevents |
|---|-------|------------------|
| A1 | Speaker Requirement | Code outside an `as Speaker {}` block |
| A3 | Three-Valued Evaluation | Forces `when/otherwise/broken` instead of just if/else |
| A7 | No Forced Speech | One speaker can't author expressions for another |
| A8 | Write Ownership | `let OtherSpeaker.var = x` won't compile |
| A9 | No Infinite Loops | `while` without `max` won't compile |

### Runtime (via Mary)

| # | Axiom | What it enforces |
|---|-------|------------------|
| A2 | Condition as Flag | Conditions are scoped markers, not universal laws |
| A5 | Ledger Integrity | Append-only, hash-chained, verifiable |
| A6 | Deterministic Evaluation | Same state → same result |
| A10 | No Orphan State | Every memory change traced to a ledger entry |
| A4 | Silence Is Distinct | Silent is absence of evaluation, not a status |

---

## Architecture

### Logica Pipeline

```
Source (.logica)
    ↓
Lexer (logica/lexer.py)        → Tokens
    ↓
Parser (logica/parser.py)      → AST
    ↓
Compiler (logica/compiler.py)  → Compiled Operations (axioms checked here)
    ↓
Runtime (logica/runtime.py)    → Executes through Mary kernel
```

### Mary Kernel

Everything goes through Mary.

**Components:**
- **Speaker Registry** — Identity management. IDs are immutable, never reused.
- **Partitioned Memory** — Each speaker owns a partition. Reads are universal, writes are owner-only.
- **Append-Only Ledger** — Hash-chained log of every operation. No deletions, no mutations.
- **Evaluator** — Evaluates expressions to active, inactive, or broken.
- **Request Bus** — Inter-speaker communication. FIFO, no bypass.

**Key API in `mary.py`:**

```python
class Mary:
    def create_speaker(caller_id, name) → Speaker
    def read(caller_id, owner_id, var) → value       # unrestricted
    def write(caller_id, var, value) → bool           # owner-only
    def submit(speaker_id, condition, action) → entry # log expression
    def request(from_id, to_id, action) → Request     # communication
    def respond(speaker_id, request_id, accept) → bool
    def ledger_verify() → bool                        # hash chain check
    def inspect_speaker(caller_id, target_id) → dict
    def inspect_variable(caller_id, owner_id, var) → dict
```

### Helena OS

Helena sits on Mary. Manages worlds, files, and the human-facing layer. Helena is a speaker (id: 1) — she follows the same rules.

```python
class Helena:
    def create_speaker(name) → int
    def create_world(creator_id, name) → str
    def join_world(speaker_id, world_id) → bool
    def world_write(speaker_id, world_id, var, value) → bool
    def world_read(caller_id, world_id, owner_id, var) → value
    def inspect_world(caller_id, world_id) → dict
    def audit(caller_id, world_id) → list[dict]
```

### Classroom World

First application. Teacher, students, admin.

```python
class Classroom:
    def enroll_student(student_id)
    def create_assignment(title, description, max_points)
    def submit_work(student_id, assignment_id, content) → receipt
    def grade(student_id, assignment_id, score, feedback) → receipt
    def dispute_grade(student_id, assignment_id, reason)
    def gradebook() → list[dict]
    def transcript(student_id) → dict
```

---

## File Guide

### Specifications

| File | What |
|------|------|
| `human_logic_v2.md` | Full computation model. 10 axioms, 25 theorems, formal grammar, Turing completeness proof. |
| `mary_v1.md` | Kernel spec. Speaker registry, memory, ledger, evaluator, request bus. 12 invariants. |
| `helena_v1.md` | OS spec. Worlds, files, identity, inspection, events. 14 rules. |
| `classroom_world_v1.md` | App spec. Assignments, submissions, grades, disputes, attendance. 12 rules. |

### Implementation

| File | Lines | What |
|------|-------|------|
| `mary.py` | 1,238 | Kernel. Zero dependencies. |
| `helena.py` | 485 | OS. Imports `mary.py`. |
| `classroom.py` | 1,069 | App + interactive shell. Imports `helena.py`. |
| `logica/lexer.py` | 357 | Tokenizer. 25 keywords, operators, literals. |
| `logica/ast_nodes.py` | 360 | AST node definitions. Every node tracks line/col. |
| `logica/parser.py` | 600 | Recursive descent parser. |
| `logica/compiler.py` | 524 | Proof checker. Validates axioms, emits operations. |
| `logica/runtime.py` | 862 | Executes compiled operations through Mary. |
| `logica/errors.py` | 53 | Error types. `LexError`, `ParseError`, `AxiomViolation`, `RuntimeError_`. |
| `logica.py` | 325 | CLI. File runner, REPL, `--check`, `--tokens`, `--ast`. |
| `logica_demo.py` | 363 | 10 demo programs covering all features. |
| `demo.py` | 356 | Full stack demo: Mary → Helena → Classroom. |
| `classroom_ui.jsx` | — | React interface for Classroom. |

### Examples

| File | Demonstrates |
|------|-------------|
| `examples/hello_world.logica` | Minimal program. One speaker, one statement. |
| `examples/ownership.logica` | Write ownership (Axiom 8). |
| `examples/three_values.logica` | `when`/`otherwise`/`broken` branching. |
| `examples/communication.logica` | Requests, responses, disputes. |
| `examples/loops_and_functions.logica` | Bounded loops, fibonacci, function definitions. |
| `examples/the_demo.logica` | Teacher/Student/Admin end-to-end. |
| `examples/axiom_violations.logica` | Commented violations — uncomment to see them caught. |

---

## Key Concepts

### Speakers

Every operation requires a speaker. Speaker IDs are immutable and never reused. Root (id: 0) exists at boot. Helena (id: 1) is created by root.

### Partitioned Memory

Each speaker owns a memory partition. Reads cross partitions freely. Writes are confined to the owner's partition. This is Axiom 8 — not a permission, not configurable.

### The Ledger

Append-only, hash-chained. Every operation produces an entry. Entries are sequential, gapless, and immutable. `verify ledger` walks the chain and confirms integrity.

### Three-Valued Evaluation

| Status | Meaning |
|--------|---------|
| **active** | Condition met, action fulfilled. |
| **inactive** | Condition not met. Not failure — just not applicable. |
| **broken** | Condition met, action not fulfilled. A broken commitment. |

Silence (no expression issued) is distinct from all three.

### Requests

Speakers communicate through requests, not shared memory. A request is logged for the sender. The target can accept, refuse, or stay silent. All outcomes are in the ledger.

---

## Running the Tests

```bash
# Axiom check all examples
for f in examples/*.logica; do python3 logica.py --check "$f"; done

# Run all examples
for f in examples/*.logica; do python3 logica.py "$f"; done

# Full language demo
python3 logica_demo.py

# Full stack demo
python3 demo.py
```

---

## Extending

### Adding a new Logica keyword

1. Add token type to `TokenType` in `logica/lexer.py`
2. Add keyword string to `KEYWORDS` dict in `logica/lexer.py`
3. Add AST node in `logica/ast_nodes.py`
4. Add parse method in `logica/parser.py`, wire into `_parse_statement`
5. Add compile method in `logica/compiler.py` with axiom checks
6. Add runtime handler in `logica/runtime.py`

### Adding a new Mary system call

1. Add the method to the `Mary` class in `mary.py`
2. First argument must be `speaker_id`
3. Must produce a ledger entry
4. Add a corresponding `OpType` in `logica/compiler.py` if exposing to Logica

### Building a new World (application)

See `classroom.py` for the pattern:
1. Take a `Helena` instance and a creator speaker ID
2. Use `helena.create_world()` for isolation
3. Use `helena.world_write()` / `helena.world_read()` for scoped data
4. Use `helena.mary.request()` / `helena.mary.respond()` for communication
5. Everything goes through Helena → Mary. No shortcuts.

---

## Design Decisions

**Why braces instead of indentation?** Multi-line REPL input is simpler with explicit delimiters. Nesting is unambiguous.

**Why `max` is required on loops?** Axiom 9. The formal model requires every loop to terminate or be bounded. Set `max` to something reasonable for your use case.

**Why `when`/`otherwise`/`broken` instead of just `if`/`else`?** `if`/`else` is supported for convenience, but `when` is the native form. It maps directly to three-valued evaluation. `otherwise` is inactive (condition not met). `broken` is broken (condition met, action failed).

**Why no global variables?** Every variable belongs to a speaker. There is no shared mutable state. Speakers exchange data through reads and requests. This is Axiom 8.

**Why does the compiler reject code outside `as Speaker {}`?** Axiom 1. Every operation requires a speaker. Unattributed code is undefined in Human Logic.

---

## What's Next

- [ ] Persistent ledger (file-backed)
- [ ] Logica standard library (string ops, collections, I/O)
- [ ] Additional worlds: Contract World, Project World
- [ ] Formal verification of axioms (Lean/Coq)
- [ ] Federation protocol (multiple Helena instances)
- [ ] Swift implementation for iOS

---

## About

Created by **Jared Lewis** — CS teacher in Houston, TX, and founder of PARCRI Real Intelligence / Ada Computing Company.

**Patent Status:** Provisional patent filed
