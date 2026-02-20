# HumanLogica Guide

**Author:** Jared Lewis
**Date:** February 2026
**License:** All Rights Reserved
**Status:** Working prototype — math, kernel, OS, app, and language all functional

---

## Table of Contents

1. [What Is HumanLogica?](#1-what-is-humanlogica)
2. [The Stack](#2-the-stack)
3. [Quick Start](#3-quick-start)
4. [The 10 Axioms](#4-the-10-axioms)
5. [Core Concepts](#5-core-concepts)
6. [Logica Language Reference](#6-logica-language-reference)
7. [Mary Kernel Reference](#7-mary-kernel-reference)
8. [Helena OS Reference](#8-helena-os-reference)
9. [Classroom World Reference](#9-classroom-world-reference)
10. [Example Walkthroughs](#10-example-walkthroughs)
11. [Architecture](#11-architecture)
12. [File Guide](#12-file-guide)
13. [Extending the System](#13-extending-the-system)
14. [Design Decisions FAQ](#14-design-decisions-faq)
15. [Glossary](#15-glossary)
16. [Roadmap](#16-roadmap)

---

## 1. What Is HumanLogica?

HumanLogica is a complete software stack built on a single idea:

> **Every operation has a speaker.**

That idea — taken to its mathematical conclusion — produces a computation model, a kernel, an operating system, a programming language, and a first application. None of those pieces are ad hoc. They all follow from the axioms.

### Why This Matters

Every other computation model — Turing machines, lambda calculus, Von Neumann architecture — is anonymous. Code runs. Memory changes. Nobody is responsible.

Human Logic flips that. In Human Logic:

- Every operation is attributed to a named speaker.
- Every result is one of three values: **active**, **inactive**, or **broken**.
- Every state change is permanently recorded in an append-only, hash-chained ledger.
- No speaker can write another speaker's data.
- No speaker can force another speaker to act.
- Silence is a valid, distinct state — not a failure.
- Disagreement does not cause contradiction.
- Blame does not propagate.
- Every computation terminates or is explicitly bounded.
- Every state can be replayed from the ledger.

Human Logic is Turing equivalent — it computes exactly the same functions as any other complete model. But it computes *accountably*.

### Who Built It

Created by **Jared Lewis** — CS teacher in Houston, TX, and founder of PARCRI Real Intelligence / Ada Computing Company. The Classroom World is the first application because its designer is a teacher. Every design decision comes from real classroom experience.

---

## 2. The Stack

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

| Layer | What It Does | Source |
|-------|-------------|--------|
| **Human Logic** | Formal model. 10 axioms, 25 theorems, Turing complete. | `human_logic_v2.md` |
| **Mary** | Kernel. Speaker registry, partitioned memory, append-only ledger, evaluator, request bus. | `mary.py` |
| **Helena** | OS. Worlds, files, identity, inspection, audit. | `helena.py` |
| **Classroom** | App. Assignments, submissions, grading, disputes, attendance. | `classroom.py` |
| **Logica** | Language. Lexer, parser, compiler (proof checker), runtime. | `logica/` |

Zero external dependencies. Python 3.10+ standard library only.

---

## 3. Quick Start

### Prerequisites

- Python 3.10 or higher
- No additional packages required

### Running Your First Program

```bash
# Hello World in Logica
python3 logica.py examples/hello_world.logica

# Full language demo — 10 programs, all features
python3 logica_demo.py

# Full stack demo — Mary → Helena → Classroom
python3 demo.py

# Interactive Logica REPL
python3 logica.py

# Interactive Classroom shell
python3 classroom.py
```

### Your First Program

Save this as `my_first.logica`:

```logica
speaker Alice

as Alice {
    let message = "Hello from Human Logic"
    speak message
}
```

Run it:

```bash
python3 logica.py my_first.logica
```

Every program must have at least one speaker, and all code must live inside an `as Speaker {}` block. This is not a convention — it is **Axiom 1**.

### Checking Axioms Without Running

```bash
python3 logica.py --check my_first.logica
```

This validates all axioms at compile time without executing.

---

## 4. The 10 Axioms

The axioms are the foundation. The compiler enforces five of them at compile time. Mary enforces the remaining five at runtime. They cannot be disabled or configured away.

### Plain-Language Summary

| # | Axiom | In Plain English |
|---|-------|-----------------|
| **A1** | Speaker Requirement | Every piece of code must have an owner. You cannot write code that belongs to nobody. |
| **A2** | Condition as Flag | A condition is situational. It applies to this expression, in this context, for this speaker. It is not a universal law. |
| **A3** | Three-Valued Evaluation | Results are not just true/false. They are **active** (condition met, action done), **inactive** (condition not met — not a failure), or **broken** (condition met, action failed — a broken commitment). |
| **A4** | Silence Is Distinct | Saying nothing is not the same as being inactive. Silence means no expression was issued at all. |
| **A5** | Ledger Integrity | The record of events is append-only. Nothing can be deleted or changed after the fact. |
| **A6** | Deterministic Evaluation | Given the same state, the same code always produces the same result. |
| **A7** | No Forced Speech | You cannot write code that runs in someone else's name. Only Alice can issue expressions attributed to Alice. |
| **A8** | Write Ownership | You can read anyone's data. You can only write your own. This is math, not a permission setting. |
| **A9** | No Infinite Loops | Every loop must either have a condition that eventually becomes false, or an explicit `max N` bound. A commitment that never resolves is not a commitment. |
| **A10** | No Orphan State | Every change in memory is traceable to a ledger entry. There is no hidden state. |

### Which Axioms Are Enforced Where

**At compile time (Logica compiler):**

| Axiom | What It Catches |
|-------|----------------|
| A1 | Code outside `as Speaker {}` |
| A3 | Branches that don't handle all three values |
| A7 | Code that tries to run as a different speaker |
| A8 | `let OtherSpeaker.var = x` |
| A9 | `while` loops without a `max` bound |

**At runtime (Mary kernel):**

| Axiom | What It Enforces |
|-------|-----------------|
| A2 | Conditions are scoped to expressions, not global |
| A5 | Ledger is append-only, hash-chained |
| A6 | Same state → same evaluation result |
| A10 | Every memory write produces a ledger entry |
| A4 | Silence is tracked separately from evaluation results |

---

## 5. Core Concepts

### Speakers

A **speaker** is a named identity that can own variables, issue expressions, define functions, and communicate with other speakers.

- Every speaker gets a unique, immutable numeric ID at creation.
- IDs are never reused.
- Root (id: 0) exists at boot.
- Helena (id: 1) is created by root.
- All subsequent speakers are created by Helena or by other authorized speakers.

```logica
speaker Teacher
speaker Student
speaker Admin
```

### Partitioned Memory

Memory in Human Logic is partitioned by speaker. Each speaker owns a memory partition.

- **Reads are universal.** Any speaker can read any other speaker's variables at any time.
- **Writes are owner-only.** A speaker can only write to their own partition. This is Axiom 8. It is not a permission. It is math.

```logica
as Teacher {
    let grade = 95       # Teacher writes to Teacher.grade — OK
}

as Student {
    let seen = read Teacher.grade   # Anyone can read — OK
    # let Teacher.grade = 100       # Won't compile: Axiom 8
}
```

### The Ledger

The ledger is the permanent, immutable record of everything that happened in the system.

- **Append-only.** Entries are never deleted or modified.
- **Hash-chained.** Each entry includes a hash of the previous entry. Tampering breaks the chain.
- **Complete.** Every expression, every write, every request and response has an entry.
- **Verifiable.** Anyone can verify the full chain at any time with `verify ledger`.

```logica
as Teacher {
    verify ledger          # Walks the entire hash chain
    ledger last 10         # View the 10 most recent entries
    history Student.submission  # View all versions of a variable
}
```

### Three-Valued Evaluation

The evaluation of any expression in Human Logic produces exactly one of three values:

| Status | Meaning |
|--------|---------|
| **active** | Condition was met. Action was fulfilled. A kept commitment. |
| **inactive** | Condition was not met. The expression simply didn't apply. Not a failure. |
| **broken** | Condition was met. Action was not fulfilled. A broken commitment. |

Silence — the absence of any expression — is distinct from all three. You cannot observe silence as a status; you can only observe that no expression was issued.

```logica
as Student {
    let deadline_ok = true

    when deadline_ok {
        speak "Submitting..."     # active: condition met, action done
    } otherwise {
        speak "Too late"          # inactive: condition not met
    } broken {
        speak "Upload failed"     # broken: condition met, action failed
    }
}
```

### Requests and Communication

Speakers communicate through requests. No speaker can force another to act (Axiom 7).

```logica
# Student files a dispute — this is a request, not a command
as Student {
    request Teacher "review_grade: I covered all requirements"
}

# Teacher chooses how to respond — their choice
as Teacher {
    respond refuse
    speak "Grade stands. Missing error handling."
}
```

Both the request and the response (or refusal) are permanently recorded in the ledger.

---

## 6. Logica Language Reference

Logica is the programming language of HumanLogica. It compiles to Mary kernel operations. The compiler is a proof checker — programs that violate any axiom fail to compile.

### Program Structure

Every Logica program follows this structure:

```logica
# 1. Declare speakers
speaker SpeakerName1
speaker SpeakerName2

# 2. Write code in speaker contexts
as SpeakerName1 {
    # ... statements
}

as SpeakerName2 {
    # ... statements
}
```

Comments start with `#`.

### Variables

Variables are declared with `let`. Every variable belongs to the speaker in whose `as` block it is declared.

```logica
as Alice {
    let name = "Alice"
    let score = 42
    let passing = true
    let nothing = none
}
```

To read another speaker's variable, use `read`:

```logica
as Bob {
    let alice_score = read Alice.score
}
```

### Expressions and `speak`

`speak` is the fundamental expression in Logica. It issues a statement to the ledger.

```logica
as Alice {
    speak "Hello, World!"
    speak "My score is 42"
}
```

### Conditionals

**Three-valued form (native):**

```logica
when <condition> {
    # active path
} otherwise {
    # inactive path — condition not met
} broken {
    # broken path — condition met, action failed
}
```

**Two-valued form (convenience):**

```logica
if <condition> {
    # condition is true
} elif <other_condition> {
    # elif branch
} else {
    # fallback
}
```

**Explicit pass / fail:**

```logica
if score >= 60 {
    pass
} else {
    fail
}
```

### Loops

Every loop **must** have a `max` bound. This is Axiom 9.

```logica
as Alice {
    let i = 0
    while i < 10, max 1000 {
        let i = i + 1
    }
}
```

If the loop condition is still true after `max` iterations, the loop terminates and its status is **broken** — the speaker committed to finishing within N steps and did not.

```logica
# This won't compile — missing max:
# while true { speak "forever" }
# → Axiom 9 violation: every loop must have a 'max N' bound.
```

### Functions

Functions are owned by the speaker who defines them.

```logica
as Mathematician {
    fn fibonacci(n) {
        if n <= 0 { return 0 }
        if n == 1 { return 1 }

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
```

Function parameters and local variables are scoped to the function call and cleaned up on return.

### Communication

```logica
# Sending a request
as Student {
    request Teacher "review_grade: Covered all requirements"
}

# Responding to a request
as Teacher {
    respond accept     # or: respond refuse
}
```

### Inspection

```logica
as Teacher {
    inspect Student              # View Student's full profile
    history Student.submission   # All versions of a variable
    ledger last 10               # Last 10 ledger entries
    verify ledger                # Verify hash chain integrity
}
```

### Worlds

Worlds are isolated namespaces created within Helena. They are the unit of application.

```logica
world classroom_101 {
    # ... world-scoped statements
}
```

### `seal`

Sealing a world locks it from further modification.

```logica
seal classroom_101
```

### Keywords Reference

| Category | Keywords |
|----------|----------|
| Identity | `speaker`, `as` |
| Variables | `let`, `read` |
| Output | `speak` |
| Conditionals | `when`, `otherwise`, `broken`, `if`, `elif`, `else`, `pass`, `fail` |
| Functions | `fn`, `return` |
| Loops | `while`, `max` |
| Communication | `request`, `respond`, `accept`, `refuse` |
| Inspection | `inspect`, `history`, `ledger`, `verify` |
| Worlds | `world`, `seal` |
| Values | `active`, `inactive`, `true`, `false`, `none` |
| Logic | `not`, `and`, `or` |

### Operators

| Operator | Meaning |
|----------|---------|
| `+` `-` `*` `/` `%` | Arithmetic |
| `==` `!=` `<` `>` `<=` `>=` | Comparison |
| `and` `or` `not` | Logical |

### CLI Reference

```bash
python3 logica.py <file.logica>        # Run a program
python3 logica.py --check <file>       # Check axioms without running
python3 logica.py --tokens <file>      # Show tokenization
python3 logica.py --ast <file>         # Show parsed AST
python3 logica.py                      # Launch interactive REPL
```

### REPL

The REPL lets you write and run Logica interactively. Use `{` and `}` to open and close blocks. Type `exit` or `quit` to leave.

```
$ python3 logica.py
Logica REPL v1.0
Type 'exit' or 'quit' to exit.

>>> speaker Alice
>>> as Alice {
...     speak "Hello from REPL"
... }
[Alice] Hello from REPL
```

---

## 7. Mary Kernel Reference

Mary is the kernel. She enforces Human Logic on standard hardware. Every layer above her — Helena, Classroom, Logica — goes through Mary.

### What Mary Does

1. **Manages speakers** — Identity creation, registration, lookup.
2. **Partitions and protects memory** — Each speaker owns a partition. Reads are universal. Writes are owner-only.
3. **Maintains the ledger** — Append-only, hash-chained log of every operation.
4. **Evaluates expressions** — Returns active, inactive, or broken.
5. **Routes communication** — FIFO request bus between speakers. No bypass.

### Mary Does Not…

- Render interfaces (that's Helena's job)
- Manage traditional files (that's Helena's job)
- Schedule processes (she evaluates expressions, not processes)

### Core API

```python
from mary import Mary

kernel = Mary()
```

#### Speaker Management

```python
# Create a speaker
# Returns a Speaker object
speaker = kernel.create_speaker(caller_id, name)

# Get speaker by ID
speaker = kernel.get_speaker(speaker_id)

# Get speaker by name
speaker = kernel.get_speaker_by_name(name)

# List all speakers
speakers = kernel.list_speakers(caller_id)
```

#### Memory Operations

```python
# Read any speaker's variable (unrestricted)
value = kernel.read(caller_id, owner_id, var_name)

# Write to your own variable (owner-only)
# Returns True on success, raises on Axiom 8 violation
success = kernel.write(caller_id, var_name, value)
```

#### Ledger Operations

```python
# Submit an expression (condition + action)
entry = kernel.submit(speaker_id, condition, action)

# Verify the entire hash chain
# Returns True if intact, False if tampered
valid = kernel.ledger_verify()

# Get the full ledger
entries = kernel.get_ledger(caller_id)

# Get a specific entry
entry = kernel.get_entry(caller_id, entry_id)
```

#### Communication

```python
# Send a request from one speaker to another
request = kernel.request(from_id, to_id, action)

# Respond to a request
# accept=True to accept, accept=False to refuse
success = kernel.respond(speaker_id, request_id, accept)

# Get pending requests for a speaker
pending = kernel.get_requests(speaker_id)
```

#### Inspection

```python
# Get full profile of a speaker (anyone can inspect anyone)
profile = kernel.inspect_speaker(caller_id, target_id)
# Returns: {id, name, created_at, memory, expression_count, ...}

# Get variable history (all versions)
history = kernel.inspect_variable(caller_id, owner_id, var_name)
# Returns: list of {value, timestamp, entry_id}
```

### Ledger Entry Structure

Each ledger entry contains:

```python
{
    "id":         int,       # Sequential, gapless
    "speaker_id": int,       # Who authored this
    "action":     str,       # What was done
    "condition":  any,       # What condition was evaluated
    "status":     str,       # "active", "inactive", or "broken"
    "timestamp":  float,     # Unix timestamp
    "hash":       str,       # SHA-256 of (prev_hash + this entry data)
}
```

### Speaker Record Structure

```python
{
    "id":         int,    # Immutable, never reused
    "name":       str,    # Human-readable label
    "created_at": float,  # Unix timestamp
    "status":     str,    # "active" or "inactive"
}
```

---

## 8. Helena OS Reference

Helena is the operating system. She sits on top of Mary and provides the human-facing layer: worlds, files, identity management, inspection, and audit.

Helena is herself a speaker (id: 1). She follows all the same rules as any other speaker. She is not above the system — she is in the system.

### What Helena Adds Over Mary

| Concern | Mary Handles | Helena Adds |
|---------|-------------|-------------|
| Identity | Speaker IDs | Named worlds, roles |
| Storage | Partitioned variables | World-scoped files |
| Visibility | Universal reads | World membership |
| Audit | Raw ledger | Human-readable audit trails |
| Structure | Flat speakers | Hierarchical worlds |

### Core API

```python
from helena import Helena

os = Helena()
```

#### Speaker Management

```python
# Create a speaker (wrapper around Mary)
speaker_id = os.create_speaker(name)
```

#### World Management

```python
# Create an isolated world (application namespace)
world_id = os.create_world(creator_id, name)

# Join a world
success = os.join_world(speaker_id, world_id)

# Inspect a world
info = os.inspect_world(caller_id, world_id)
# Returns: {id, name, creator, members, created_at, ...}
```

#### World-Scoped Data

```python
# Write a variable in world scope
success = os.world_write(speaker_id, world_id, var_name, value)

# Read a variable from a world
value = os.world_read(caller_id, world_id, owner_id, var_name)
```

#### Audit

```python
# Get human-readable audit log for a world
audit_log = os.audit(caller_id, world_id)
# Returns: list of {timestamp, speaker, action, status}
```

---

## 9. Classroom World Reference

The Classroom World is the first application built on HumanLogica. It demonstrates that the complete stack — Human Logic → Mary → Helena — can run a real-world application with strong integrity guarantees.

### The Problem It Solves

Every common classroom integrity issue is a Human Logic axiom violation:

| Problem | Axiom Violated |
|---------|---------------|
| Student claims they submitted; system says no | Ledger Integrity (A5) |
| System lost submitted work | Ledger Integrity (A5) |
| Grade changed without explanation | Write Ownership (A8) + Ledger (A5) |
| Plagiarism with no proof of who wrote what, when | Speaker Requirement (A1) |
| Admin overriding teacher's grade | Write Ownership (A8) + No Forced Speech (A7) |

### Speakers in the Classroom

| Role | Can Write | Can Read |
|------|-----------|---------|
| **Teacher** | Their own partition (grades, feedback, assignments) | Everything |
| **Student** | Their own partition (submissions, requests) | Everything |
| **Admin** | Their own partition (observations, notes) | Everything |

Admin cannot modify teacher or student data. Not by policy — by math (Axiom 8).

### Interactive Shell

```bash
python3 classroom.py
```

Available commands in the shell:

```
enroll <name>                               — Add a student
assignment <title> <description> <points>   — Post an assignment
submit <student_id> <assignment_id> <work>  — Submit work
grade <student_id> <assignment_id> <score>  — Grade a submission
dispute <student_id> <assignment_id>        — File a grade dispute
gradebook                                   — View all grades
transcript <student_id>                     — View a student's record
audit                                       — View full audit trail
verify                                      — Verify ledger integrity
help                                        — List all commands
```

### Python API

```python
from helena import Helena
from classroom import Classroom

os_layer = Helena()
teacher_id = os_layer.create_speaker("Teacher")
classroom = Classroom(os_layer, teacher_id)
```

#### Enrollment

```python
student_id = os_layer.create_speaker("Maria")
classroom.enroll_student(student_id)
```

#### Assignments

```python
assignment_id = classroom.create_assignment(
    title="Build a Calculator",
    description="Implement a four-function calculator",
    max_points=100
)
```

#### Submissions

```python
receipt = classroom.submit_work(
    student_id=student_id,
    assignment_id=assignment_id,
    content="def calc(a, op, b): ..."
)
# receipt contains: {student_id, assignment_id, timestamp, ledger_entry_id}
```

#### Grading

```python
receipt = classroom.grade(
    student_id=student_id,
    assignment_id=assignment_id,
    score=92,
    feedback="Clean code. Handles edge cases."
)
```

#### Disputes

```python
classroom.dispute_grade(
    student_id=student_id,
    assignment_id=assignment_id,
    reason="I covered all requirements in section 3"
)
```

#### Reports

```python
# All grades
gradebook = classroom.gradebook()
# [{"student": "Maria", "assignment": "...", "score": 92, ...}, ...]

# One student's complete record
transcript = classroom.transcript(student_id)
# {"student": "Maria", "assignments": [...], "gpa": 3.8, ...}
```

---

## 10. Example Walkthroughs

The `examples/` directory contains seven programs that demonstrate all major features of Logica. Run any of them with `python3 logica.py examples/<name>.logica`.

### `hello_world.logica` — The Minimum

```logica
speaker Jared

as Jared {
    speak "Hello, World!"
}
```

**What it shows:** The absolute minimum. One speaker. One statement. Every operation has a speaker. Even "Hello World."

### `ownership.logica` — Axiom 8 in Action

Two speakers. A teacher posts an assignment and grades a student. The student reads the assignment, submits work, and reads their grade. At the end, a commented-out block shows what happens if a student tries to modify their own grade — the compiler rejects it before the program ever runs.

```bash
python3 logica.py --check examples/ownership.logica   # All axioms OK
# Uncomment the violation, then:
python3 logica.py --check examples/ownership.logica   # Axiom 8 violation
```

### `three_values.logica` — Active / Inactive / Broken

Demonstrates the three evaluation states using deadline conditions.

- `deadline_ok = true` → submission path is **active**
- `deadline_ok = false` → submission path is **inactive** (not failure, just not applicable)
- `broken` branch handles the case where the condition is met but the action fails

### `communication.logica` — Requests and Refusals

A student submits work, gets a low grade, and files a dispute. The teacher refuses the dispute. Both the dispute and the refusal are permanently in the ledger. Neither speaker was coerced. Both spoke freely.

```bash
python3 logica.py examples/communication.logica
```

### `loops_and_functions.logica` — Bounded Computation

Defines a `fibonacci` function and demonstrates bounded `while` loops. Includes a commented-out unbounded loop to show the Axiom 9 violation.

```bash
python3 logica.py examples/loops_and_functions.logica
python3 logica.py --check examples/loops_and_functions.logica
```

### `the_demo.logica` — Everything Together

A teacher (Jared), a student (Maria), and an admin. The complete workflow: post assignment, submit work, grade, read grade, admin observes. Ends with `verify ledger` and `history Maria.submission` to show the append-only record.

```bash
python3 logica.py examples/the_demo.logica
```

### `axiom_violations.logica` — See All Violations

Every axiom violation commented out, with explanation of what happens when you uncomment each one. A learning tool.

```bash
# Axiom check without running:
python3 logica.py --check examples/axiom_violations.logica
```

### Running All Examples

```bash
# Check all examples
for f in examples/*.logica; do
    echo "Checking $f..."
    python3 logica.py --check "$f"
done

# Run all examples
for f in examples/*.logica; do
    echo "Running $f..."
    python3 logica.py "$f"
done
```

---

## 11. Architecture

### The Logica Compilation Pipeline

```
Source (.logica)
    ↓
Lexer (logica/lexer.py)
    Tokenizes the source. 25 keywords, all operators, string/number/bool literals.
    Output: stream of tokens with line/column information.
    ↓
Parser (logica/parser.py)
    Recursive descent parser. Builds the Abstract Syntax Tree (AST).
    Output: AST where every node carries line/col for error reporting.
    ↓
Compiler (logica/compiler.py)
    Proof checker. Walks the AST and validates all 5 compile-time axioms.
    A1: enforces speaker context for all statements.
    A3: enforces when/otherwise/broken structure.
    A7: prevents code from running in a different speaker's name.
    A8: catches writes to another speaker's variables.
    A9: catches loops without a max bound.
    Output: list of compiled operations (OpType instances).
    ↓
Runtime (logica/runtime.py)
    Executes compiled operations through the Mary kernel.
    Every operation calls Mary. Mary records everything.
    Output: side effects (speak output, ledger entries, memory writes).
```

### Mary's Internal Components

```
Mary
├── Speaker Registry    — Dict[id → Speaker]. IDs sequential from 0. Never reused.
├── Partitioned Memory  — Dict[speaker_id → Dict[var_name → value]]
├── Append-Only Ledger  — List[Entry]. Each entry hashes the previous.
├── Evaluator           — Maps (condition, action) → {active, inactive, broken}
└── Request Bus         — Dict[to_speaker_id → List[Request]]. FIFO. No bypass.
```

### Helena's Layer on Mary

Helena wraps Mary and adds:

```
Helena
├── World Registry      — Dict[world_id → World]. Isolation namespaces.
├── Membership          — Dict[world_id → Set[speaker_id]]
├── World Memory        — World-scoped variables (still enforced by Mary)
├── Audit Layer         — Human-readable event log per world
└── File Abstraction    — Named data within worlds
```

### Error Types

Defined in `logica/errors.py`:

| Error | When It Occurs |
|-------|---------------|
| `LexError` | Invalid token in source (unrecognized character, malformed string) |
| `ParseError` | Syntactically invalid program (unmatched braces, unexpected token) |
| `AxiomViolation` | Any of the 5 compile-time axioms is broken |
| `RuntimeError_` | Runtime failure (division by zero, undefined variable, broken ledger) |

Each error includes:
- The specific axiom violated (for `AxiomViolation`)
- Line and column number
- A plain-English explanation of why the code is invalid

---

## 12. File Guide

### Specification Documents

| File | What It Contains |
|------|-----------------|
| `human_logic_v2.md` | The full computation model. 10 axioms, 25 theorems, formal grammar, Turing completeness proof. |
| `mary_v1.md` | Kernel specification. Speaker registry, memory model, ledger, evaluator, request bus. 12 invariants. |
| `helena_v1.md` | OS specification. Worlds, files, identity, inspection, events. 14 rules. |
| `classroom_world_v1.md` | Application specification. Assignments, submissions, grades, disputes, attendance. 12 rules. |

### Implementation Files

| File | Lines | What It Does |
|------|-------|-------------|
| `mary.py` | 1,238 | Kernel. Zero external dependencies. |
| `helena.py` | 485 | OS. Imports `mary.py`. |
| `classroom.py` | 1,069 | Application + interactive shell. Imports `helena.py`. |
| `logica/lexer.py` | 357 | Tokenizer. 25 keywords, operators, literals. |
| `logica/ast_nodes.py` | 360 | AST node definitions. Every node tracks line/col. |
| `logica/parser.py` | 600 | Recursive descent parser. |
| `logica/compiler.py` | 524 | Proof checker. Validates 5 compile-time axioms. |
| `logica/runtime.py` | 862 | Executes compiled operations through Mary. |
| `logica/errors.py` | 53 | Error types. |
| `logica/transpiler.py` | 475 | JS transpiler. Emits JavaScript from the Logica AST. |
| `logica/c_transpiler.py` | 936 | C transpiler. Emits C code from the Logica AST. |
| `logica/js_runtime.js` | — | JavaScript runtime support for the JS transpiler target. |
| `logica/wasm_build.py` | 189 | WebAssembly build pipeline. Logica → C → WASM. |
| `logica.py` | 325 | CLI entrypoint. File runner, REPL, `--check`, `--tokens`, `--ast`. |
| `logica_demo.py` | 363 | 10 demo programs covering all language features. |
| `demo.py` | 356 | Full stack demo: Mary → Helena → Classroom. |
| `classroom_ui.jsx` | 1,161 | React interface for Classroom World. |

### Example Programs

| File | What It Demonstrates |
|------|---------------------|
| `examples/hello_world.logica` | Minimal program. One speaker, one statement. |
| `examples/ownership.logica` | Write ownership (Axiom 8). Shows the violation. |
| `examples/three_values.logica` | `when`/`otherwise`/`broken` three-valued branching. |
| `examples/communication.logica` | Requests, responses, disputes. |
| `examples/loops_and_functions.logica` | Bounded loops, fibonacci, function definitions. |
| `examples/the_demo.logica` | Teacher/Student/Admin end-to-end. |
| `examples/axiom_violations.logica` | Every violation, commented out, ready to test. |

---

## 13. Extending the System

### Adding a New Logica Keyword

1. Add the `TokenType` to `logica/lexer.py`
2. Add the keyword string to the `KEYWORDS` dict in `logica/lexer.py`
3. Add an AST node class in `logica/ast_nodes.py`
4. Add a `_parse_<keyword>` method in `logica/parser.py`, wire it into `_parse_statement`
5. Add a `_compile_<keyword>` method in `logica/compiler.py` with appropriate axiom checks
6. Add a runtime handler in `logica/runtime.py`

### Adding a New Mary System Call

1. Add the method to the `Mary` class in `mary.py`
   - First parameter must be `speaker_id` (who is making the call)
   - Must produce a ledger entry
   - Must return a meaningful result
2. Add a corresponding `OpType` in `logica/compiler.py` if exposing the call to Logica
3. Add runtime dispatch in `logica/runtime.py`

### Building a New World (Application)

See `classroom.py` for the complete pattern. The steps are:

1. Take a `Helena` instance and a creator speaker ID
2. Call `helena.create_world(creator_id, name)` to create an isolated namespace
3. Have participants call `helena.join_world(speaker_id, world_id)` to join
4. Use `helena.world_write()` / `helena.world_read()` for world-scoped data
5. Use `helena.mary.request()` / `helena.mary.respond()` for inter-speaker communication
6. Use `helena.audit()` for human-readable event logs

**Rule:** Everything goes through Helena → Mary. No shortcuts.

### Formal Verification

The specification documents (`human_logic_v2.md`, `mary_v1.md`, `helena_v1.md`) are written to support formal verification in Lean or Coq. The axiom numbering and theorem numbering are stable identifiers.

---

## 14. Design Decisions FAQ

**Q: Why braces instead of indentation?**

Multi-line REPL input is unambiguous with explicit delimiters. Nesting depth is always clear. Indentation-based parsing in an interactive context requires the interpreter to guess when a block is complete — braces remove that guessing.

---

**Q: Why is `max` required on loops?**

Axiom 9. The formal model requires every loop to terminate or be bounded. A commitment that never resolves is not a commitment. If you genuinely need more iterations, set a higher bound. If your loop needs to run forever, Human Logic rejects that as a design premise.

---

**Q: Why `when`/`otherwise`/`broken` instead of just `if`/`else`?**

`if`/`else` is supported as a convenience form, but `when` is the native form. It maps directly to three-valued evaluation. `otherwise` captures the inactive state (condition not met). `broken` captures a failed commitment. The two-valued `if`/`else` hides the broken case, which is valid for simple comparisons but loses expressiveness for commitment-based logic.

---

**Q: Why no global variables?**

Every variable belongs to a speaker. There is no shared mutable state. Speakers exchange data through reads (observation) and requests (communication). This is Axiom 8. Without this, you lose attribution — a shared variable has no owner, and Human Logic requires every operation to have a speaker.

---

**Q: Why does the compiler reject code outside `as Speaker {}`?**

Axiom 1. Every operation requires a speaker. Unattributed code is undefined in Human Logic. It cannot be evaluated, it cannot appear in the ledger, it cannot have a status. The compiler rejects it not because it might cause errors, but because it has no meaning in the model.

---

**Q: Why is read unrestricted?**

Observation is not action. Reading a variable does not change state, does not appear in the ledger as a write, and does not grant ownership. Information in Human Logic flows freely. Action is restricted to the actor's own domain.

---

**Q: Can two speakers have the same name?**

No. Names are unique identifiers within the system. Speaker IDs are numeric and never reused, but names must also be unique at creation time.

---

**Q: What is Helena's relationship to Mary?**

Helena is a speaker (id: 1) running on Mary, just like any other speaker. She follows all the same axioms. She cannot write to your variables. She cannot force you to act. She has elevated capabilities only in the sense that she was created first and the system grants her world-management authority by convention — not by exception to the rules.

---

## 15. Glossary

| Term | Definition |
|------|-----------|
| **Speaker** | A named identity that can own variables, issue expressions, define functions, and communicate. Every operation requires a speaker. |
| **Expression** | A 4-tuple `(speaker, condition, action, time)`. The fundamental unit of computation. |
| **Active** | Evaluation status. Condition was met; action was fulfilled. |
| **Inactive** | Evaluation status. Condition was not met. Not a failure — the expression simply didn't apply. |
| **Broken** | Evaluation status. Condition was met; action was not fulfilled. A broken commitment. |
| **Silent** | Position state (not an evaluation status). No expression was issued at all. Distinct from inactive. |
| **Ledger** | The append-only, hash-chained record of all expressions. Nothing can be removed or modified. |
| **Partition** | A speaker's personal memory space. Reads are universal; writes are owner-only. |
| **Mary** | The kernel. Enforces all 10 axioms on standard hardware. |
| **Helena** | The operating system. Lives on Mary. Provides worlds, files, audit, and identity. |
| **World** | An isolated application namespace managed by Helena. |
| **Logica** | The programming language. Compiles to Mary operations. The compiler is a proof checker. |
| **Axiom** | One of the 10 fundamental rules of Human Logic. Cannot be disabled or bypassed. |
| **Proof checker** | What the Logica compiler is. It validates that the program obeys all axioms before running. |
| **Axiom violation** | A compile-time or runtime error that occurs when code violates one of the 10 axioms. |
| **Request** | A message from one speaker asking another speaker to act. The target may accept, refuse, or stay silent. |
| **Hash chain** | The ledger's integrity mechanism. Each entry includes a hash of all prior entries. Tampering breaks the chain. |
| **Root** | The initial speaker (id: 0). Exists at boot. Creates Helena. |
| **Turing equivalent** | Capable of computing exactly the same functions as a Turing machine — neither more nor less. |

---

## 16. Roadmap

The following features are planned or under consideration:

- [ ] **Persistent ledger** — File-backed ledger that survives process restarts
- [ ] **Logica standard library** — String operations, collections, I/O
- [ ] **Additional worlds** — Contract World, Project World, Voting World
- [ ] **Formal verification** — Mechanized proof of axioms in Lean or Coq
- [ ] **Federation protocol** — Multiple Helena instances communicating across machines
- [ ] **Swift implementation** — Native iOS stack
- [ ] **Visual ledger browser** — Timeline view of the ledger for auditing

---

## About

HumanLogica was created by **Jared Lewis** — CS teacher in Houston, TX, and founder of PARCRI Real Intelligence / Ada Computing Company.

The Classroom World is the first application because the classroom was the origin of the entire idea. Every axiom was motivated by a real problem in education. Lost submissions. Changed grades. Disputed credit. All of them are data integrity failures. All of them are solved by math.

**Patent Status:** Provisional patent filed.

---

*HumanLogica Guide — Jared Lewis, 2026. All rights reserved.*
