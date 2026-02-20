# Human Logic

### A computation model where every statement has a speaker.

---

**Author:** Jared Lewis
**Date:** February 2026
**License:** All Rights Reserved
**Status:** Working prototype

---

## What is this?

Human Logic is a new way to build software where **every operation is attributed to a person**.

In every computer system you've ever used — your phone, your laptop, Google Docs, Canvas, Blackboard — the software does things and nobody signs for it. Files get modified. Data gets changed. Records get updated. But there's no built-in concept of *who did it* or *when* or *why*. Identity and accountability are bolted on after the fact with passwords, permissions, and audit logs that can be tampered with.

Human Logic starts from the opposite assumption: **nothing happens without a speaker.**

Every variable has an owner. Every change has a receipt. Every receipt is permanent. And the math prevents anyone from modifying anyone else's data — not as a policy, not as a permission setting, but as a mathematical axiom that the system cannot violate.

---

## Why does it matter?

Because every problem caused by "I didn't do that" or "the system lost it" or "someone changed my work" is a problem Human Logic solves by design.

**In education:**
- A student's submission belongs to the student. Mathematically. The teacher can read it but cannot modify it.
- Every grade is traceable to the teacher who gave it, the submission it was based on, and the assignment it came from.
- If an administrator pressures a teacher to change a grade, the pressure itself is recorded permanently.
- Plagiarism evidence comes from timestamps and version history in the ledger, not from algorithms.

**In business:**
- Contracts become computation. "If I deliver, you pay" is an expression with two speakers, conditions, and a permanent record of who followed through.
- No one can claim "I never agreed to that" because every commitment is in the ledger with a hash chain.

**In healthcare, law, government — anywhere accountability matters:**
- Every action has a name on it.
- Every record has a history.
- History cannot be modified.

---

## The Stack

Human Logic is a complete system from math to interface:

```
┌─────────────────────────────────────────┐
│  Classroom World    — the first app     │
├─────────────────────────────────────────┤
│  Helena             — operating system  │
├─────────────────────────────────────────┤
│  Mary               — kernel            │
├─────────────────────────────────────────┤
│  Human Logic        — computation model │
└─────────────────────────────────────────┘
```

| Layer | What it does | Key property |
|-------|-------------|--------------|
| **Human Logic** | The math. Defines how computation works when every statement has a speaker. | 10 axioms, 25 theorems, Turing complete |
| **Mary** | The kernel. Enforces Human Logic on real hardware. | 12 invariants, append-only ledger, hash chain |
| **Helena** | The operating system. Worlds, files, identity, inspection. | 14 rules, 34 system calls, federation |
| **Classroom World** | The first application. Teacher, students, assignments, grades. | Ownership by axiom, not by policy |

---

## Key Properties

**Three-valued evaluation.** Expressions aren't true or false. They're *active* (condition met, action fulfilled), *inactive* (condition not met), or *broken* (condition met, action not fulfilled). "Inactive" isn't failure — it's silence. "Broken" isn't false — it's a broken commitment.

**Write ownership.** You can only write to your own variables. This is enforced at the mathematical level, not the permission level. No setting can override it. No administrator can bypass it.

**Append-only ledger.** Every operation is logged permanently with a cryptographic hash chain. History cannot be modified. Every entry links to the previous one. Tampering breaks the chain and is detectable.

**No anonymous operations.** Every read, write, expression, and request has a speaker identity attached. The system cannot execute an operation without knowing who is executing it.

**Deterministic replay.** Given the ledger, you can replay the entire history of the system and arrive at the exact same state. This is not a feature — it's a mathematical consequence of the axioms.

---

## Try It

### Python (terminal)

```bash
# Clone the repo
git clone https://github.com/[your-username]/human-logic.git
cd human-logic

# Run the full stack demo (no dependencies needed)
python3 demo.py

# Run the interactive classroom shell
python3 classroom.py
```

### React (browser)

```bash
cd human-logic
npm create vite@latest classroom-ui -- --template react
cd classroom-ui
npm install
cp ../classroom_ui.jsx src/App.jsx
npm run dev
```

Open `http://localhost:5173` in your browser.

---

## File Guide

### Specifications (the math)

| File | Description |
|------|-------------|
| `human_logic_v1.md` | Propositional system. Speaker-scoped conditionals. 7 axioms, 15 theorems. |
| `human_logic_v2.md` | Full computation model. Variables, loops, functions, communication. Turing completeness proof. 10 axioms, 25 theorems. |
| `mary_v1.md` | Kernel specification. Speaker registry, partitioned memory, ledger, evaluator, request bus. 12 invariants, 10 guarantees. |
| `helena_v1.md` | Operating system specification. Worlds, files, identity, inspection, events, federation. 14 rules, 34 system calls. |
| `classroom_world_v1.md` | First application specification. Assignments, submissions, grades, attendance, disputes. 12 rules, 4 theorems. |

### Code (the implementation)

| File | Description |
|------|-------------|
| `mary.py` | Mary kernel in Python. Speaker registry, partitioned memory, append-only ledger with hash chain, expression evaluator, request bus. Zero dependencies. |
| `helena.py` | Helena OS in Python. World management, files, identity, inspection, audit. Imports `mary.py`. |
| `classroom.py` | Classroom World + interactive shell. Assignments, submissions, grading, disputes, attendance, transcripts. Imports `helena.py`. |
| `demo.py` | Non-interactive full stack demo. Run this first. Proves everything works. |
| `classroom_ui.jsx` | React interface. Mary and the Classroom embedded in the browser. Dashboard, gradebook, ledger inspector, tamper test. |

---

## The Origin Story

This project started with a question about birthday cake.

Classical logic says: "If it's my birthday, I eat cake." If you eat cake on a Tuesday — not your birthday — classical logic says the statement is *valid*. The condition is false, so the whole thing is vacuously true.

That's stupid.

If I said "if it's my birthday I eat cake," and it's not my birthday, the statement isn't *true*. It's just not participating right now. It's silent. It's waiting.

That observation — that statements should be *inactive* when their conditions aren't met, not vacuously true — led to three-valued evaluation. Three-valued evaluation required knowing *who* made the statement, which led to speaker attribution. Speaker attribution led to write ownership. Write ownership led to the ledger. The ledger led to a kernel. The kernel led to an operating system. The operating system led to the Classroom World.

One question about cake became a complete computation model.

---

## Technical Lineage

Human Logic draws on cybernetics (1940s-90s), the actor model, and relevance logic (Anderson & Belnap), but is none of these. It is a new computation model — non-Von Neumann in three specific ways:

1. **Von Neumann uses shared memory.** Human Logic uses speaker-partitioned memory.
2. **Von Neumann uses destructive writes.** Human Logic uses an append-only ledger.
3. **Von Neumann uses anonymous execution.** Human Logic attributes every operation.

Human Logic is **Turing complete** — it computes exactly what Turing machines compute (proven in Human Logic v2.0, Theorem 17). It adds structural properties that Turing machines lack: attribution, three-valued evaluation, audit trails, write ownership, native disagreement, silence as a distinct state, and no forced speech.

---

## What's Next

- [ ] Helena implementation (Python)
- [ ] Federation protocol (multiple Helena instances communicating)
- [ ] Additional worlds: Contract World, Project World, Medical Record World
- [ ] Swift implementation for iOS
- [ ] Persistent ledger (file-backed instead of in-memory)
- [ ] Academic paper for peer review
- [ ] Formal verification of axioms using proof assistant (Lean/Coq)

---

## About

Human Logic was created by **Jared Lewis** — a computer science teacher in Houston, Texas, and founder of PARCRI Real Intelligence / Ada Computing Company.

This project crystallized from real classroom experience: students who lost work, grades that were disputed without evidence, administrators who made changes without accountability. The solution wasn't better software. It was better math.

**Contact:** [your email]
**Patent Status:** Provisional patent filed

---

*Every operation has a speaker. Every state change has a receipt. The ledger is intact. Human Logic holds.*
