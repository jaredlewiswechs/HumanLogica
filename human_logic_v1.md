# Human Logic v1.0

### A Formal Speaker-Scoped Conditional System

**Author:** Jared Lewis
**Date:** February 19, 2026

---

## Part I — Foundations

### 1. Motivation

Classical propositional logic evaluates statements without attribution. The conditional `P → Q` has no speaker, no scope, and no accountability. This produces the paradoxes of material implication:

- If `P` is false, `P → Q` is true regardless of `Q` (vacuous truth).
- If `Q` is true, `P → Q` is true regardless of `P` (irrelevant antecedent).

These are artifacts of a system designed to model abstract truth, not human commitment. Human Logic corrects this by requiring every statement to have an attributed speaker. The result is a three-valued, speaker-scoped conditional system in which silence is not denial, inactivity is not failure, and no expression exists without a human to speak it.

---

### 2. Primitives

The system is built from four primitive sets:

**Definition 2.1 — Speakers.** Let `S` be a non-empty finite set of speakers.

```
S = {s₁, s₂, ..., sₙ}
```

Each element of `S` is a human. `S` must contain at least one element. The empty speaker is not permitted.

**Definition 2.2 — Propositions.** Let `W` be a set of world propositions — facts about the external world that hold or do not hold independent of any speaker.

```
W = {w₁, w₂, ..., wₘ}
```

Each `wᵢ` is either **met** (⊤) or **unmet** (⊥) at any given evaluation.

**Definition 2.3 — Actions.** Let `A` be a set of actions — things a speaker can do.

```
A = {a₁, a₂, ..., aₖ}
```

Each action is a discrete, observable event. An action either **occurred** or **did not occur** at evaluation time.

**Definition 2.4 — Timestamps.** Let `T` be a totally ordered set of discrete time points.

```
T = {t₀, t₁, t₂, ...}, where t₀ < t₁ < t₂ < ...
```

Every expression is issued at some time `t ∈ T`. Time provides ordering for versioning and evaluation.

---

### 3. Expressions

**Definition 3.1 — Human Logic Expression.** An expression `e` is a 4-tuple:

```
e = (s, C, a, t)
```

Written in notation as:

```
s : C ⊢ a     [issued at t]
```

Where:

- `s ∈ S` — the speaker
- `C` — the condition (defined in §4)
- `a ∈ A` — the committed action
- `t ∈ T` — the time of issuance

**Axiom 3.1 — Speaker Requirement.** An expression with no speaker is undefined.

```
If s = ∅, then e is not an expression.
```

This is the foundational axiom of Human Logic. There are no orphan statements.

**Definition 3.2 — Refusal.** A refusal is an expression committing to the non-performance of an action:

```
s : C ⊢ ¬a
```

Refusal is an active commitment. It is not the absence of a statement. It is not silence.

**Definition 3.3 — Choice.** A choice expression commits the speaker to exactly one of several actions:

```
s : C ⊢ (a₁ | a₂ | ... | aⱼ)
```

The speaker selects. The system does not select for the speaker.

---

### 4. Conditions

**Definition 4.1 — Condition.** A condition `C` is a function that returns **met** (⊤) or **unmet** (⊥). Conditions come in three kinds.

**Definition 4.2 — World Flag.** A world flag is a condition drawn from `W`:

```
C = wᵢ, where wᵢ ∈ W
```

It depends on an external fact. No speaker is required for a world flag to resolve.

*Example: "It is my birthday" is a world flag.*

**Definition 4.3 — Speaker Flag.** A speaker flag is a condition that depends on the evaluation status of another speaker's expression:

```
C = status(s', C', a')
```

Where `(s', C', a', t')` is another expression in the system.

*Example: "Mom's commitment to bake is active" is a speaker flag.*

**Definition 4.4 — Self Flag.** A self flag is a speaker flag where the referenced speaker is the same as the current speaker:

```
C = status(s, C', a')
```

The speaker's current commitment depends on their own prior commitment.

*Example: "My commitment to finish school is active" is a self flag.*

**Definition 4.5 — Compound Conditions.** Conditions may be combined:

- `C₁ ∧ C₂` — both must be met
- `C₁ ∨ C₂` — at least one must be met

Compound conditions evaluate left to right. If `C₁` in a conjunction is unmet, `C₂` is not evaluated.

---

### 5. Evaluation

**Definition 5.1 — Status.** The status of an expression is one of three values:

```
Σ = {active, inactive, broken}
```

There is no "true" or "false" in Human Logic. There is active, inactive, and broken.

**Definition 5.2 — Evaluation Function.** Let `V` be the evaluation function:

```
V(s, C, a, t) → Σ
```

Defined by the following rules, applied in order:

```
Rule 1: If s is undefined       → not an expression (rejected)
Rule 2: If C = ⊥                → inactive
Rule 3: If C = ⊤ and a occurred → active
Rule 4: If C = ⊤ and a did not occur → broken
```

**Definition 5.3 — Choice Evaluation.** For a choice expression `s : C ⊢ (a₁ | a₂ | ... | aⱼ)`:

```
Rule 3c: If C = ⊤ and any one aᵢ occurred → active
Rule 4c: If C = ⊤ and no aᵢ occurred      → broken
```

If more than one `aᵢ` occurred, the expression is still active. The commitment was to do at least one.

**Definition 5.4 — Refusal Evaluation.** For a refusal `s : C ⊢ ¬a`:

```
Rule 3r: If C = ⊤ and a did not occur → active
Rule 4r: If C = ⊤ and a occurred      → broken
```

Refusal inverts the action check. The speaker committed to *not* doing the thing. Doing it breaks the refusal.

---

### 6. Speaker Position

**Definition 6.1 — Speaker Position Function.** For a given speaker `s`, condition `C`, and action `a`, the speaker's position `P` is:

```
P(s, C, a) ∈ {committed, refused, silent}
```

Where:

- **Committed**: there exists a current expression `s : C ⊢ a`
- **Refused**: there exists a current expression `s : C ⊢ ¬a`
- **Silent**: no current expression exists for this speaker, condition, and action

**Theorem 6.1 — Silence Is Not Refusal.**

```
silent ≠ refused
```

*Proof.* A refusal is an expression `(s, C, ¬a, t)` with a defined speaker, condition, and timestamp. Silence is the absence of any such expression. An expression exists or it does not. The presence of a refusal is an active commitment; the absence of an expression is no commitment at all. Therefore they are distinct. ∎

**Theorem 6.2 — Silence Cannot Be Evaluated.**

```
If P(s, C, a) = silent, then V is undefined for (s, C, a).
```

*Proof.* The evaluation function `V` requires an expression as input. If no expression exists, `V` has no input and produces no output. Silence has no status. ∎

---

### 7. Versioning

**Definition 7.1 — Ledger.** The ledger `L` is the ordered set of all expressions ever issued:

```
L = {e₁, e₂, ..., eₙ}, ordered by t
```

No expression is ever deleted from `L`.

**Definition 7.2 — Supersession.** When a speaker issues a new expression with the same condition and action as a prior expression, the prior expression is marked **superseded**:

```
If e₁ = (s, C, a, t₁) and e₂ = (s, C, a, t₂) where t₂ > t₁,
then e₁.version = superseded, e₂.version = current
```

**Definition 7.3 — Current Expression.** Only current expressions are evaluated. Superseded expressions remain in the ledger but do not participate in evaluation.

```
V is defined only for expressions where e.version = current
```

**Theorem 7.1 — Supersession Is Not Failure.**

```
superseded ≠ broken
```

*Proof.* An expression is broken when its condition is met and its action is not fulfilled. An expression is superseded when a newer expression from the same speaker with the same condition and action exists. Supersession is a property of versioning, not of evaluation. A superseded expression is never evaluated, so it can never be broken. ∎

**Definition 7.4 — Reversal.** A speaker may supersede a commitment with a refusal, or a refusal with a commitment:

```
e₁ = (Jared, birthday, cake, t₁)        → current at t₁
e₂ = (Jared, birthday, ¬cake, t₂)       → current at t₂, e₁ superseded
```

The ledger records both. The speaker changed their mind. That is a human action, not a logical failure.

---

### 8. Independence

**Definition 8.1 — Speaker Independence.** Two expressions from different speakers are always independent, even if they share conditions and actions:

```
e₁ = (s₁, C, a, t₁)
e₂ = (s₂, C, a, t₂)
where s₁ ≠ s₂
```

`V(e₁)` and `V(e₂)` are computed independently. The status of one does not affect the status of the other.

**Theorem 8.1 — Disagreement Without Contradiction.**

Two speakers may hold opposing commitments on the same condition and action without producing a contradiction:

```
e₁ = (Jared, birthday, cake, t₁)     → may be active
e₂ = (Mom, birthday, ¬cake, t₂)      → may be active
```

*Proof.* In classical logic, `P` and `¬P` cannot both be true — this is a contradiction. In Human Logic, `e₁` and `e₂` are different expressions with different speakers. They are evaluated independently per Definition 8.1. Both may be active simultaneously because activation is scoped to the speaker. No contradiction arises because no universal claim is made. Each expression is a personal commitment, not a law. ∎

**Definition 8.2 — Same-Speaker Conflict.** If the same speaker holds both a commitment and a refusal for the same condition and action at the same time:

```
e₁ = (s, C, a, t₁), e₁.version = current
e₂ = (s, C, ¬a, t₂), e₂.version = current
```

This is a **conflict**. The system flags it but does not resolve it. The speaker must resolve their own conflict by superseding one expression. Until resolved, both expressions are evaluated independently, and the speaker may be simultaneously active on one and broken on the other.

---

### 9. Dependency Chains

**Definition 9.1 — Chain.** A dependency chain is an ordered sequence of expressions where each expression's condition is a speaker flag referencing the previous expression:

```
e₁ = (s₁, C₁, a₁, t₁)
e₂ = (s₂, status(e₁) = active, a₂, t₂)
e₃ = (s₃, status(e₂) = active, a₃, t₃)
```

**Definition 9.2 — Chain Evaluation.** Chains evaluate left to right. Each expression checks only its immediate condition.

**Theorem 9.1 — Chain Silence (No Downstream Guilt).**

If any expression in a chain is inactive or broken, all downstream expressions are inactive.

```
If V(eᵢ) ∈ {inactive, broken}, then for all j > i: V(eⱼ) = inactive
```

*Proof.* Let `V(eᵢ) = inactive`. Then `eᵢ`'s action did not occur (the condition was never met, so the action was never triggered). Therefore `status(eᵢ) ≠ active`. Expression `eᵢ₊₁` has condition `status(eᵢ) = active`, which is unmet. By Rule 2, `V(eᵢ₊₁) = inactive`. By induction, all subsequent expressions in the chain are inactive.

Now let `V(eᵢ) = broken`. Then `eᵢ`'s condition was met but the action did not occur. Therefore `status(eᵢ) = broken ≠ active`. Expression `eᵢ₊₁` has condition `status(eᵢ) = active`, which is unmet. By Rule 2, `V(eᵢ₊₁) = inactive`. By induction, all subsequent expressions are inactive. ∎

*Consequence: No speaker downstream of a failure is guilty. They are silent, not broken. Human Logic does not propagate blame.*

**Definition 9.3 — Chain Inspection.** Determining *why* a chain stopped is not part of evaluation. It is a separate operation: walk the chain from the first inactive expression backward until you find the cause. This is an inspection task, not a logic task.

---

### 10. Scope and Expiration

**Definition 10.1 — Scope.** Every expression has a scope — the temporal or situational boundary within which it can be evaluated.

**Definition 10.2 — Bounded Expression.** An expression may include an expiration:

```
s : C ⊢ a [until t_end]
```

After `t_end`, the expression is no longer current. It is not superseded (no new expression replaced it) and not broken (the speaker didn't fail). It is **expired**.

**Definition 10.3 — Expiration Status.** An expired expression cannot be evaluated.

```
If t_now > t_end, then V(e) is undefined.
```

Expiration is a fourth version state alongside current and superseded:

```
Version ∈ {current, superseded, expired}
```

The ledger keeps all three. Only current expressions are evaluated.

**Definition 10.4 — Unbounded Expression.** If no expiration is specified, the expression is unbounded. It remains current until superseded by the speaker.

---

## Part II — Theorems

### 11. Resolution of Classical Paradoxes

**Theorem 11.1 — No Vacuous Truth (The Birthday Cake Theorem).**

In Human Logic, a false condition does not make a statement true. It makes it inactive.

*Classical form:* `P → Q` where `P = ⊥` yields `P → Q = ⊤` (vacuous truth).

*Human Logic form:* `Jared : birthday ⊢ cake` where `birthday = ⊥` yields `V = inactive`.

*Proof.* By Rule 2 of the evaluation function, if `C = ⊥`, the expression is inactive. Inactive is not active. Inactive is not true. The expression is silent. No truth value is assigned to a silent statement. Therefore vacuous truth cannot arise. ∎

**Theorem 11.2 — No Irrelevant Antecedent.**

In Human Logic, a true consequent does not validate an unrelated antecedent.

*Classical form:* If `Q = ⊤`, then `P → Q = ⊤` for any `P`.

*Human Logic form:* The action occurring is necessary but not sufficient for active status. The condition must also be met, AND the expression must have a speaker.

*Proof.* Suppose `a` occurred but `C = ⊥`. By Rule 2, the expression is inactive. The action happening independently does not activate an expression whose flag is not raised. Eating cake on a Tuesday does not activate a birthday commitment. ∎

**Theorem 11.3 — No Explosion (Ex Falso Nihil).**

In classical logic, a contradiction entails everything: `(P ∧ ¬P) → Q` for any `Q`. In Human Logic, contradictions are scoped to speakers and do not propagate.

*Proof.* Suppose `V(e₁) = active` and `V(e₂) = active` where `e₁ = (s₁, C, a, t₁)` and `e₂ = (s₂, C, ¬a, t₂)` with `s₁ ≠ s₂`. By Theorem 8.1, this is disagreement, not contradiction. No inference rule in Human Logic derives arbitrary expressions from disagreement. The system does not explode. ∎

*For same-speaker conflict:* By Definition 8.2, the system flags the conflict. It does not resolve it and does not derive anything from it. The speaker must act. Until then, both expressions are evaluated independently. No arbitrary conclusions are drawn.

---

### 12. Properties of the System

**Theorem 12.1 — Locality.**

Every expression is evaluated using only local information: its own speaker, its own condition, and its own action.

*Proof.* The evaluation function `V(s, C, a, t)` takes only the components of the expression as input. When `C` is a speaker flag, `V` checks the status of the referenced expression — but that referenced expression was also evaluated locally. No global state is consulted. ∎

**Theorem 12.2 — Determinism.**

Given a fixed state of the world (all world flags resolved), a fixed ledger, and a fixed time, every expression has exactly one status.

*Proof.* The evaluation rules are applied in order and are mutually exclusive:
- Rule 1 eliminates non-expressions.
- Rule 2 applies if and only if `C = ⊥`.
- Rule 3 applies if and only if `C = ⊤` and `a` occurred.
- Rule 4 applies if and only if `C = ⊤` and `a` did not occur.

No two rules can apply simultaneously. Exactly one rule applies to every valid expression. Therefore evaluation is deterministic. ∎

**Theorem 12.3 — Non-Interference.**

The evaluation of one expression never changes the evaluation of another expression (unless the second expression's condition is a speaker flag referencing the first).

*Proof.* By Definition 8.1, expressions from different speakers are independent. Expressions from the same speaker with different conditions or actions are independent. The only coupling is through speaker flags, which is explicit and declared in the condition. No hidden dependencies exist. ∎

**Theorem 12.4 — Ledger Integrity.**

No operation in Human Logic deletes, modifies, or reorders entries in the ledger.

*Proof.* By Definition 7.1, the ledger is append-only. Supersession adds a new expression and changes a version tag; it does not remove or alter the original expression's content, speaker, condition, action, or timestamp. Expiration changes a version tag by time passage. No operation in the system mutates ledger content. ∎

**Theorem 12.5 — Finite Evaluation.**

Every expression evaluates in finite steps.

*Proof.* For world flags: one check (⊤ or ⊥), then one action check. Two steps.

For speaker flags: the referenced expression must be evaluated first. In the worst case, this creates a chain of length `n` (the number of expressions in the ledger). Each chain link evaluates in constant time. The chain is bounded by `|L|`. No cycles can form because each expression's condition references a *prior* expression (issued at an earlier time). The time ordering of `T` prevents circular dependency. Therefore evaluation terminates in at most `|L|` steps. ∎

---

### 13. Composition

**Definition 13.1 — Agreement.** Two expressions are in agreement if they share a condition and action from different speakers, and both are active:

```
e₁ = (s₁, C, a, t₁), V(e₁) = active
e₂ = (s₂, C, a, t₂), V(e₂) = active
where s₁ ≠ s₂
```

Agreement is an observation, not an operation. The system notes it but does nothing special with it.

**Definition 13.2 — Disagreement.** Two expressions are in disagreement if one commits and the other refuses on the same condition and action:

```
e₁ = (s₁, C, a, t₁)
e₂ = (s₂, C, ¬a, t₂)
where s₁ ≠ s₂
```

Disagreement is a natural state. It is not a contradiction. It is not an error. It does not trigger resolution. Both expressions are evaluated independently.

**Definition 13.3 — Delegation.** A speaker may issue an expression whose action is another speaker's commitment:

```
s₁ : C ⊢ request(s₂, C', a)
```

This is a **request**, not a command. It creates an expression for `s₁` but does not create an expression for `s₂`. Only `s₂` can create expressions for `s₂`. A delegation is active when `s₁` made the request. Whether `s₂` responds is determined by `s₂`'s own expressions (or silence).

**Theorem 13.1 — No Forced Speech.**

No operation in Human Logic can create an expression on behalf of another speaker.

*Proof.* By Axiom 3.1, every expression requires a speaker. By construction, only the speaker themselves can issue an expression with their identity. Delegation creates an expression for the requester, not the requestee. There is no function in the system that takes `s₁` as input and produces an expression attributed to `s₂`. ∎

*Consequence: Human Logic cannot compel. It can only commit, refuse, request, and observe.*

---

### 14. Observation

**Definition 14.1 — Observer.** Any speaker may observe the status of any expression in the system:

```
observe(s_observer, e_target) → Σ ∪ {silent, superseded, expired}
```

Observation does not change the target's status. It is read-only.

**Definition 14.2 — System State.** The complete state of Human Logic at time `t` is:

```
State(t) = (S, L, W(t))
```

Where `S` is the set of speakers, `L` is the ledger, and `W(t)` is the state of all world flags at time `t`. From this, every expression's status can be computed deterministically.

**Theorem 14.1 — Full Inspectability.**

Given `State(t)`, any observer can compute the status of every expression and reconstruct the full history of every speaker's commitments.

*Proof.* The ledger `L` contains every expression ever issued with timestamps. The evaluation function `V` is deterministic (Theorem 12.2). World flags `W(t)` are given. Therefore every expression's status is computable, and the ledger provides complete history. ∎

---

## Part III — Formal Language Summary

### 15. Syntax

```
Expression  :=  Speaker : Condition ⊢ Action [Scope]
Speaker     :=  s ∈ S, s ≠ ∅
Condition   :=  WorldFlag | SpeakerFlag | SelfFlag | Condition ∧ Condition | Condition ∨ Condition
WorldFlag   :=  w ∈ W
SpeakerFlag :=  status(Expression) = σ, where σ ∈ Σ
SelfFlag    :=  SpeakerFlag where referenced speaker = current speaker
Action      :=  a ∈ A | ¬a | (a₁ | a₂ | ... | aⱼ)
Scope       :=  [until t_end] | ∅ (unbounded)
```

### 16. Semantics

```
Σ = {active, inactive, broken}
Version = {current, superseded, expired}

V(s, C, a, t):
  if s = ∅           → reject
  if e.version ≠ current → undefined
  if C = ⊥           → inactive
  if C = ⊤ ∧ a occurred    → active
  if C = ⊤ ∧ a not occurred → broken

P(s, C, a):
  if ∃ current (s, C, a, t)   → committed
  if ∃ current (s, C, ¬a, t)  → refused
  otherwise                    → silent
```

### 17. Axioms

```
A1. Speaker Requirement:     ∀e: e.speaker ≠ ∅
A2. Condition as Flag:       A condition is a marker with scope, not a universal law.
A3. Three-Valued Evaluation: Σ = {active, inactive, broken}. No other values.
A4. Silence Is Distinct:     silent ∉ Σ. Silence is the absence of evaluation.
A5. No Forced Speech:        Only speaker s can issue expressions attributed to s.
A6. Ledger Integrity:        L is append-only. No deletions. No mutations.
A7. Deterministic Evaluation: Given State(t), V(e) has exactly one result.
```

### 18. Inference Rules

```
R1. Activation:
    s : C ⊢ a,  C = ⊤,  a occurred
    ————————————————————————————————
    V(e) = active

R2. Inactivation:
    s : C ⊢ a,  C = ⊥
    ——————————————————
    V(e) = inactive

R3. Breaking:
    s : C ⊢ a,  C = ⊤,  a not occurred
    ————————————————————————————————————
    V(e) = broken

R4. Chain Propagation:
    V(eᵢ) ∈ {inactive, broken}
    eᵢ₊₁.condition = status(eᵢ) = active
    ————————————————————————————————————
    V(eᵢ₊₁) = inactive

R5. Supersession:
    (s, C, a, t₁) ∈ L,  (s, C, a, t₂) ∈ L,  t₂ > t₁
    ——————————————————————————————————————————————————
    e₁.version = superseded

R6. Observation:
    observe(s_obs, e_target) = V(e_target)
    ————————————————————————————————————————
    No change to e_target
```

---

## Part IV — Comparison to Classical Logic

### 19. What Human Logic Rejects

| Classical Principle | Status in Human Logic | Reason |
|---|---|---|
| Vacuous truth (`⊥ → Q = ⊤`) | **Rejected.** | False condition yields inactive, not true. |
| Irrelevant antecedent (`Q → (P → Q)`) | **Rejected.** | Action occurring independently does not activate an unrelated commitment. |
| Ex falso quodlibet (`(P ∧ ¬P) → Q`) | **Rejected.** | Conflict does not propagate. Disagreement is natural. |
| Law of excluded middle (`P ∨ ¬P`) | **Modified.** | A speaker may be committed, refused, or silent. The third option exists. |
| Principle of explosion | **Rejected.** | No inference rule derives arbitrary expressions from conflict. |
| Unattributed statements | **Rejected.** | No speaker, no expression. |

### 20. What Human Logic Preserves

| Classical Principle | Status in Human Logic | Form |
|---|---|---|
| Modus ponens | **Preserved (locally).** | If `s : C ⊢ a` is current, `C = ⊤`, and `a` occurred, then `V = active`. The commitment holds. |
| Non-contradiction (per speaker) | **Preserved.** | A single speaker's conflict is flagged. The system does not permit a single expression to be simultaneously active and broken. |
| Identity | **Preserved.** | `active = active`, `inactive = inactive`, `broken = broken`. Status values are self-identical. |
| Determinism | **Preserved.** | Same inputs, same outputs. Always. |

---

## Part V — Closing

### 21. Summary of Human Logic

Human Logic is a formal system in which:

1. Every statement has a speaker.
2. Conditions are flags, not laws.
3. Evaluation yields active, inactive, or broken — never vacuous truth.
4. Silence is distinct from refusal.
5. Disagreement between speakers is natural, not contradictory.
6. No speaker can be compelled to commit.
7. All commitments are versioned in an append-only ledger.
8. Evaluation is deterministic, local, and finite.
9. The system does not propagate blame.
10. Everything is inspectable.

Human Logic does not replace classical logic. Classical logic models abstract truth in a world without speakers. Human Logic models commitment in a world of humans. They answer different questions.

Classical logic asks: "Is this true?"
Human Logic asks: "Who said it, when does it apply, and did they follow through?"

---

*Human Logic v1.0*
*Jared Lewis, 2026*
*All rights reserved.*
