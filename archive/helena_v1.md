# Helena v1.0

### An Operating System for Humans

**Author:** Jared Lewis
**Date:** February 19, 2026

---

## Part I — Purpose

### 1. What Helena Is

Helena is an operating system. She is the layer where humans live.

Mary enforces rules. Helena creates spaces. Mary is the referee. Helena is the building.

Helena takes Mary's primitives — speakers, expressions, memory, the ledger — and organizes them into something a human can use: worlds, interfaces, files, communication, and identity.

Helena does six things:

1. Manages worlds (applications, environments, workspaces).
2. Provides a human interface (how speakers interact with the system).
3. Manages files and persistent data.
4. Provides discovery (how speakers find each other and each other's worlds).
5. Manages speaker identity and profiles at the human level.
6. Provides inspection tools (how speakers audit what happened).

Helena does all of this by issuing expressions through Mary. Helena has no backdoor. Helena follows the same rules as every other speaker. The only difference is scope — Helena manages the shared infrastructure that individual speakers shouldn't have to think about.

### 2. What Helena Is Not

Helena is not the kernel. Mary is the kernel. Helena does not evaluate expressions, enforce memory boundaries, or maintain the ledger. Helena asks Mary to do those things.

Helena is not a world. Worlds run on Helena. Helena is the ground they stand on.

Helena is not a browser, a desktop, or a phone. Helena is the OS. The interface layer — what the human actually sees and touches — is a world running on Helena. Helena provides the framework. The interface world provides the pixels.

### 3. The Stack (Complete)

```
Hardware        — Von Neumann silicon
Mary            — Kernel (enforces Human Logic)
Helena          — Operating system (this document)
Worlds          — Applications running on Helena
Interface       — A special world that renders the human-facing UI
```

---

## Part II — Worlds

### 4. What a World Is

**Definition 4.1 — World.** A world is an isolated environment where speakers can create, compute, and interact. A world is defined by:

```
world = (
  world_id,            — unique, immutable
  name,                — human-readable, mutable by creator
  creator,             — the speaker who created it (speaker_id)
  created_at,          — timestamp
  status,              — open, closed, archived
  members,             — set of speaker_ids with access
  permissions,         — what members can do
  memory_namespace,    — prefix for all variables in this world
  entry_conditions     — conditions a speaker must meet to join
)
```

**Definition 4.2 — World as Namespace.** A world provides a namespace for variables. All variables created within a world are prefixed:

```
world_id.speaker_id.variable_name
```

This means speaker `s` can have a variable `x` in World A and a different variable `x` in World B. They do not collide. Worlds are memory boundaries.

**Definition 4.3 — World Independence.** Worlds are isolated from each other by default. Variables in World A are not visible from World B. Expressions in World A do not reference expressions in World B. Each world is its own universe.

### 5. World Lifecycle

**Definition 5.1 — Creation.** Any speaker can create a world:

```
s : ⊤ ⊢ helena.create_world(name, permissions, entry_conditions)
```

This is an expression issued by `s`, processed by Helena through Mary. The creator is automatically the first member. Helena logs the creation in the ledger.

**Definition 5.2 — Membership.** Speakers join worlds by meeting entry conditions:

```
s : entry_conditions(world) = ⊤ ⊢ helena.join_world(world_id)
```

Entry conditions are regular Human Logic conditions. They might be:
- `⊤` — open world, anyone can join
- `status(creator.invite(s)) = active` — invitation required
- `s.credential = ⊤` — speaker must have a specific credential
- Any compound condition

**Definition 5.3 — World States.**

```
open     — accepting new members, expressions can be submitted
closed   — no new members, existing members can still operate
archived — read-only, no new expressions, inspection only
```

State transitions:

```
open → closed       (creator decision)
closed → open       (creator decision)
open → archived     (creator decision)
closed → archived   (creator decision)
archived → closed   (creator decision, with ledger entry explaining why)
```

All state transitions are expressions in the ledger, attributed to the speaker who made the decision.

**Definition 5.4 — World Closure.** When a world is archived, all variables remain readable. The ledger entries remain. Nothing is deleted. The world just stops accepting new expressions. It becomes a record.

### 6. World Permissions

**Definition 6.1 — Permission Set.** Each member of a world has a permission set:

```
permissions(s, world) = {read, write, submit, request, invite, configure}
```

Where:
- `read` — can read variables in this world
- `write` — can write to own variables in this world
- `submit` — can submit expressions in this world
- `request` — can send requests to other members in this world
- `invite` — can invite new speakers to this world
- `configure` — can change world settings (name, entry conditions, permissions)

The creator starts with all permissions. Other members start with permissions defined by the world's default permission set.

**Definition 6.2 — Permission as Expression.** Granting or revoking permissions is an expression:

```
creator : ⊤ ⊢ helena.grant(world_id, target_speaker, permission)
creator : ⊤ ⊢ helena.revoke(world_id, target_speaker, permission)
```

Logged. Attributed. Auditable.

**Theorem 6.1 — Permissions Do Not Override Axioms.**

No permission can grant a speaker write access to another speaker's variables.

*Proof.* Permissions in Helena control access to world-level operations (submitting expressions, inviting members). They do not modify Mary's enforcement of Axiom 8 (Write Ownership). Even with all permissions, `write(s₁, s₂.v, value)` is rejected by Mary. Helena cannot override Mary. Helena issues expressions through Mary's system calls. Mary's axioms are unconditional. ∎

---

### 7. World Communication

**Definition 7.1 — Intra-World Communication.** Within a world, speakers communicate through Mary's request bus, scoped to the world namespace:

```
s₁ : C ⊢ request(s₂, action) [in world_id]
```

The request is visible only to members of that world.

**Definition 7.2 — Inter-World Communication.** By default, worlds cannot communicate. A speaker who is a member of both World A and World B can carry information between them — by reading from one world and writing to their own variables in another. But this is a human choice, not a system channel.

**Definition 7.3 — World Bridge.** If two world creators agree, they can create a bridge:

```
creator_A : ⊤ ⊢ helena.propose_bridge(world_A, world_B, scope)
creator_B : status(creator_A.proposal) = active ⊢ helena.accept_bridge(world_A, world_B, scope)
```

A bridge allows scoped cross-world reads (never cross-world writes). The scope defines which variables are visible across the bridge. Both creators must consent. The bridge is logged in both worlds' ledgers.

**Theorem 7.1 — Bridge Safety.**

A bridge never allows a speaker in World A to write to a variable in World B.

*Proof.* Bridges allow reads only (Definition 7.3). Writes are governed by Mary's Axiom 8, which is unconditional and identity-based, not world-based. A bridge does not change speaker identity. Therefore write restrictions hold regardless of bridge existence. ∎

---

## Part III — Files

### 8. Files as Variables

**Definition 8.1 — File.** A file is a named variable with structured content:

```
file = speaker.world.filename = content
```

A file is not a special object. It is a variable whose value is a byte sequence, a text string, or a structured data object. Helena provides convenience operations, but underneath, a file is just a variable in a speaker's memory partition within a world namespace.

**Definition 8.2 — File Operations.** Helena provides file operations that map to Mary's primitives:

```
helena.create_file(speaker, world, name, content)
  → mary.write(speaker, world.speaker.name, content)

helena.read_file(speaker, world, owner, name)
  → mary.read(speaker, owner.world.name)

helena.update_file(speaker, world, name, new_content)
  → mary.write(speaker, world.speaker.name, new_content)
  // old content preserved in ledger via Mary's write record

helena.list_files(speaker, world)
  → mary.list_vars(speaker, speaker) filtered by world namespace

helena.list_files(speaker, world, other_speaker)
  → mary.list_vars(speaker, other_speaker) filtered by world namespace
  // read-only view of another speaker's files
```

**Definition 8.3 — File History.** Because every write is logged in Mary's ledger with old and new values, every file has complete history. Helena does not implement version control. Version control is a consequence of the ledger.

```
helena.file_history(speaker, world, name)
  → mary.ledger_search(speaker, {var: world.speaker.name})
  → [entry₁, entry₂, ..., entryₙ] ordered by timestamp
```

Every version. Every change. Every speaker who made a change. Automatic.

**Theorem 8.1 — No Lost Files.**

A file can never be permanently lost while the ledger is intact.

*Proof.* File creation is a write. Writes are logged in the ledger with full content (Definition 7.3 of Mary). The ledger is append-only (Mary Axiom 5). Therefore the creation entry persists. Even if the variable is later overwritten, the original value exists in the write record. Even if the speaker is suspended, their partition persists. Recovery is a ledger search. ∎

---

## Part IV — Speaker Identity

### 9. Human-Level Identity

Mary tracks speakers as IDs. Helena makes them human.

**Definition 9.1 — Profile.** A speaker profile is a set of self-authored variables in a system-level namespace:

```
helena.profiles.speaker_id.name = "Jared"
helena.profiles.speaker_id.bio = "Builder."
helena.profiles.speaker_id.created = t₁
helena.profiles.speaker_id.worlds = [world_1, world_2, ...]
```

The profile is owned by the speaker. Only the speaker can write to it. Anyone can read it (consistent with Mary's read rules).

**Definition 9.2 — Identity Is Self-Declared.** Helena does not verify identity claims. If a speaker says their name is "Jared," Helena records it. Identity verification is a social problem, not a system problem. The system guarantees that the speaker who said it is the speaker who said it (through Mary's authentication). What they said about themselves is their business.

**Definition 9.3 — Reputation.** Helena does not compute reputation. There is no built-in rating, scoring, or ranking of speakers. If a community wants reputation, they build it as a world with their own expressions. The OS does not judge.

*Rationale:* Reputation systems are opinions. Opinions require speakers. A system-computed reputation would be an unattributed statement — a violation of Axiom 1.

---

### 10. Speaker Relationships

**Definition 10.1 — Connection.** Two speakers are connected when both have issued a connection expression:

```
s₁ : ⊤ ⊢ helena.connect(s₂)
s₂ : status(s₁.connect(s₂)) = active ⊢ helena.connect(s₁)
```

Both must consent. A one-sided connection request is just a pending request on the bus. Connection is mutual or it does not exist.

**Definition 10.2 — Disconnection.** Either speaker can disconnect at any time:

```
s₁ : ⊤ ⊢ helena.disconnect(s₂)
```

This supersedes the connection expression. The connection history remains in the ledger. Disconnection does not erase history.

**Definition 10.3 — Blocking.** A speaker may block another speaker:

```
s₁ : ⊤ ⊢ helena.block(s₂)
```

Blocking means:
- `s₂` cannot send requests to `s₁`
- `s₂` cannot read `s₁`'s profile
- `s₂` cannot see `s₁` in world member lists
- `s₂`'s expressions cannot reference `s₁`'s expression statuses

Blocking is enforced by Helena as a filter layer on top of Mary's system calls. Mary herself does not know about blocking — Helena intercepts and rejects blocked operations before they reach Mary.

**Theorem 10.1 — Blocking Is Unilateral.**

Blocking does not require the blocked speaker's consent and cannot be overridden by the blocked speaker.

*Proof.* Blocking is an expression issued by `s₁`. It is `s₁`'s commitment. It does not reference `s₂`'s state. Helena enforces it as a pre-filter. `s₂` has no mechanism to modify `s₁`'s expressions (No Forced Speech). Therefore blocking is absolute from the blocker's side. ∎

---

## Part V — Interface

### 11. The Interface World

**Definition 11.1 — Interface World.** The interface world is a special world created by Helena at boot time:

```
interface = (
  world_id: "interface",
  name: "Interface",
  creator: helena,
  status: open,
  members: all speakers (automatic),
  permissions: {read, submit}
)
```

Every speaker is automatically a member of the interface world. This is where they interact with Helena and see the system.

**Definition 11.2 — Rendering.** The interface world translates system state into something a human can perceive:

```
Visual:   screen output — text, shapes, images, layouts
Audio:    sound output — tones, speech, alerts
Input:    keyboard, mouse, touch, voice → expressions
```

Rendering is the conversion of variables and expression statuses into sensory output. Input is the conversion of human actions into expressions.

**Definition 11.3 — Input as Expression.** Every human input is an expression:

```
Keystroke:     s : ⊤ ⊢ helena.input(key: "a")
Click:         s : ⊤ ⊢ helena.input(click: {x: 100, y: 200})
Touch:         s : ⊤ ⊢ helena.input(touch: {x: 100, y: 200})
Voice:         s : ⊤ ⊢ helena.input(voice: "open my files")
```

Every input is logged. Every interaction has a receipt. The user's actions are their expressions.

**Definition 11.4 — Output as State.** What the human sees is a function of the current state:

```
render(State(t)) → display
```

The display is a pure function of state. Given the same state, the same display is produced. No hidden state in the renderer. The screen is a mirror of the system.

**Theorem 11.1 — Interface Determinism.**

Given the same system state, the interface produces the same output.

*Proof.* Rendering is a pure function of state (Definition 11.4). State is deterministic (Mary Theorem 17.1). Therefore display is deterministic. ∎

---

### 12. The Shell

**Definition 12.1 — Shell.** The shell is the primary interface between a speaker and Helena. It accepts expressions in human-readable form and translates them to system calls.

```
> create world "my project"
  → helena.create_world(s, "my project", default_permissions, ⊤)

> write x = 42 in "my project"
  → mary.write(s, my_project.s.x, 42)

> status of Mom.bake
  → mary.status(s, entry_id_of_mom_bake)

> history of my_project.s.x
  → helena.file_history(s, my_project, x)

> request Bob set Bob.ready = true in "my project"
  → mary.request(s, Bob, write(Bob.my_project.ready, ⊤))

> inspect ledger from t₁₀ to t₂₀
  → mary.ledger_read(s, 10, 20)
```

The shell is syntactic sugar. Every shell command maps to one or more system calls. The shell adds no capabilities — it only makes existing capabilities accessible.

**Definition 12.2 — Shell Customization.** A speaker can customize their shell by creating alias expressions:

```
s : ⊤ ⊢ helena.alias("check", "status of")
```

Now `check Mom.bake` maps to `status of Mom.bake`. Aliases are speaker-owned variables. Your shell is yours.

---

## Part VI — Inspection

### 13. The Inspector

**Definition 13.1 — Inspector.** The inspector is Helena's tool for examining system state and history. It wraps Mary's ledger operations in human-friendly interfaces.

```
helena.inspect(speaker, target):
  match target:
    expression(entry_id):
      → show entry with speaker, condition, action, status, timestamp

    speaker(speaker_id):
      → show profile, worlds, recent expressions, current status

    world(world_id):
      → show members, permissions, recent activity, state

    variable(world.speaker.var):
      → show current value, full history, who changed it and when

    chain(entry_id):
      → walk the dependency chain from this expression
      → show each link: speaker, status, condition source
      → highlight where the chain stopped and why

    diff(t₁, t₂):
      → show all state changes between two timestamps
      → grouped by speaker, then by world
```

### 14. Replay

**Definition 14.1 — Replay.** Helena can replay any span of the ledger:

```
helena.replay(speaker, from_time, to_time, speed):
  state ← reconstruct(from_time)                    // from Mary's replay
  for each entry in L where from_time ≤ entry.t ≤ to_time:
    apply entry to state
    render(state) at specified speed
```

Replay shows exactly what happened. Every expression, every state change, every speaker action. In order. At whatever speed the human wants.

**Definition 14.2 — Hypothetical Replay.** Helena can replay with modifications:

```
helena.replay_if(speaker, from_time, to_time, modifications):
  state ← reconstruct(from_time)
  apply modifications to state                       // "what if x was 10 instead of 5?"
  for each entry in L where from_time ≤ entry.t ≤ to_time:
    re-evaluate entry against modified state
    render(modified_state)
```

This does not change the actual ledger. It creates a temporary branch for inspection. The speaker can see what would have happened under different conditions. Then the branch is discarded.

**Theorem 14.1 — Replay Fidelity.**

Normal replay (without modifications) produces exactly the same state sequence as the original execution.

*Proof.* By Mary Theorem T25 (Full Replayability), given initial state and ledger, every subsequent state is deterministically reproducible. Helena's replay uses Mary's reconstruction function, which applies the same evaluation rules to the same expressions in the same order. ∎

---

## Part VII — Notifications

### 15. Event System

**Definition 15.1 — Event.** An event is a status change in the system that a speaker might care about:

```
event = (
  event_type,          — what happened
  source_speaker,      — who caused it
  world,               — where it happened
  entry_id,            — the ledger entry
  timestamp            — when
)
```

Event types:

```
expression_active      — an expression the speaker depends on became active
expression_broken      — an expression the speaker depends on broke
request_received       — someone sent the speaker a request
request_resolved       — a request the speaker sent was resolved
world_invitation       — speaker was invited to a world
connection_request     — someone wants to connect
world_state_change     — a world the speaker belongs to changed state
variable_changed       — a variable the speaker watches changed
```

**Definition 15.2 — Subscription.** A speaker subscribes to events by issuing an expression:

```
s : ⊤ ⊢ helena.subscribe(event_type, scope, callback)
```

Where:
- `event_type` — which kind of event
- `scope` — which world, which speaker, which variable (or all)
- `callback` — what action to take when the event fires

Subscriptions are expressions. They go in the ledger. They can be superseded.

**Definition 15.3 — Notification Delivery.** When an event matches a subscription, Helena delivers a notification:

```
helena.notify(speaker, event):
  match speaker.notification_preference:
    immediate → deliver now
    batched   → queue and deliver at next batch interval
    silent    → log but don't interrupt
```

The speaker controls how they receive notifications. Helena does not decide what is urgent.

**Theorem 15.1 — No Missed Events.**

If a speaker is subscribed to an event type and a matching event occurs, the event is logged regardless of notification delivery preference.

*Proof.* Events are generated from ledger entries. Ledger entries are permanent (Mary Axiom 5). Subscriptions are expressions in the ledger. Helena checks subscriptions against new entries during each tick. Even if delivery is deferred (batched or silent), the event-subscription match is recorded. The speaker can always retrieve missed events through inspection. ∎

---

## Part VIII — World Templates

### 16. Templates

**Definition 16.1 — World Template.** A template is a reusable world configuration:

```
template = (
  name,
  default_permissions,
  entry_conditions,
  initial_variables,       — variables created automatically for each member
  initial_expressions,     — expressions submitted automatically at world creation
  interface_config         — how the world should be rendered
)
```

**Definition 16.2 — Template as Variable.** Templates are speaker-owned variables:

```
s.templates.my_template = template_definition
```

A speaker can share templates by making them readable. Other speakers can use them but cannot modify them.

**Definition 16.3 — Built-In Templates.** Helena provides starter templates:

```
helena.templates.blank         — empty world, all permissions, open entry
helena.templates.notebook      — single-speaker world, personal workspace
helena.templates.project       — multi-speaker, invite-only, full permissions
helena.templates.public_board  — multi-speaker, open entry, read + submit only
helena.templates.channel       — multi-speaker, request-based communication focus
```

These are Helena's expressions. They're in the ledger. They can be inspected. A speaker can copy and modify them.

---

## Part IX — System Worlds

### 17. Helena's Own Worlds

Helena maintains system-level worlds for infrastructure:

**Definition 17.1 — Registry World.** Stores speaker profiles and connection state:

```
helena.worlds.registry = (
  members: all speakers,
  content: profiles, connections, blocks
)
```

**Definition 17.2 — Template World.** Stores shared templates:

```
helena.worlds.templates = (
  members: all speakers (read), template creators (write),
  content: world templates
)
```

**Definition 17.3 — System Log World.** Stores Helena's own operational expressions:

```
helena.worlds.system_log = (
  members: all speakers (read), helena (write),
  content: Helena's administrative actions, world creations, bridges, etc.
)
```

Every speaker can read system worlds. Only the appropriate speakers can write to them. Helena's own actions are visible. The OS is not opaque.

---

## Part X — Resource Management

### 18. Memory Quotas

**Definition 18.1 — Quota.** Each speaker has a memory quota — the maximum amount of data they can store across all worlds:

```
helena.quota(speaker) = max_bytes
```

**Definition 18.2 — Quota Enforcement.** When a write would exceed the speaker's quota, Helena rejects the expression before it reaches Mary:

```
helena.check_quota(speaker, write_size):
  current_usage ← sum of all speaker's variable sizes across all worlds
  if current_usage + write_size > quota → reject with reason "quota_exceeded"
  else → pass to Mary
```

**Definition 18.3 — Quota Is Not Axiom.** Quotas are practical constraints, not logical ones. Human Logic does not require quotas. Mary does not enforce quotas. Helena enforces them because hardware is finite. If hardware were infinite, quotas would not exist.

### 19. Archival

**Definition 19.1 — Cold Storage.** When a world is archived or a speaker is suspended, Helena may move their data to cold storage:

```
helena.archive(world_id):
  snapshot ← current state of all variables in world
  write snapshot to cold storage
  mark world as archived
  free active memory
```

Archived data remains readable through Helena's inspection tools. Helena fetches from cold storage on demand. The ledger entries are never archived — they remain in the active ledger.

**Theorem 19.1 — Archival Preserves History.**

Archiving a world does not lose any information.

*Proof.* Archival stores a complete state snapshot (Definition 19.1). The ledger retains all entries for the archived world (Mary Axiom 5). The snapshot plus ledger contains all information. Reading from cold storage returns the same values as reading from active memory. ∎

---

## Part XI — Boot Sequence

### 20. Helena Boot

Helena boots after Mary is running.

```
helena.boot():

  STEP 1 — VERIFY MARY
    confirm Mary is running
    confirm Helena's speaker record exists (id: 1)
    confirm Helena can issue expressions through Mary

  STEP 2 — INITIALIZE SYSTEM WORLDS
    create helena.worlds.registry (if not exists)
    create helena.worlds.templates (if not exists)
    create helena.worlds.system_log (if not exists)

  STEP 3 — LOAD TEMPLATES
    load built-in templates into helena.worlds.templates

  STEP 4 — INITIALIZE INTERFACE
    create interface world (if not exists)
    start renderer
    start input listener

  STEP 5 — INITIALIZE EVENT SYSTEM
    start subscription checker
    start notification dispatcher

  STEP 6 — RESTORE STATE
    if previous session exists:
      load world states from ledger replay
      restore active subscriptions
      restore pending requests
    else:
      fresh start, all state from boot expressions

  STEP 7 — ACCEPT SPEAKERS
    open shell
    begin accepting expressions from speakers

  STEP 8 — LOG
    helena : ⊤ ⊢ system_log.append("Helena booted at " + now)
```

**Theorem 20.1 — Boot Recovery.**

If Helena crashes and reboots, she returns to the exact state she was in before the crash.

*Proof.* Helena's state is derived from Mary's ledger. Mary's ledger survives crashes (append-only, fsynced). Helena's boot Step 6 replays the ledger to reconstruct state. By Mary Theorem T25, replay is deterministic and complete. Therefore Helena recovers exactly. ∎

---

## Part XII — Security at the OS Level

### 21. Helena's Security Layers

Mary provides the foundation: memory safety, attribution, no privilege escalation. Helena adds human-level protections on top.

**Definition 21.1 — Access Control.** Helena enforces world-level access:

```
Before any operation in a world:
  1. Is the speaker a member of this world? If no → reject.
  2. Does the speaker have the required permission? If no → reject.
  3. Is the speaker blocked by the target? If yes → reject.
  4. Pass to Mary.
```

**Definition 21.2 — Rate Limiting.** Helena may limit how many expressions a speaker can submit per tick:

```
helena.rate_limit(speaker) = max_expressions_per_tick
```

This prevents a single speaker from flooding the evaluation queue. It is a fairness measure, not a security measure. Rate limits are Helena's policy, not Mary's axiom.

**Definition 21.3 — Audit.** Any speaker can audit any world they belong to:

```
helena.audit(speaker, world, from_time, to_time):
  → all ledger entries for this world in the time range
  → grouped by speaker
  → with state changes shown
```

Audit is a right, not a privilege. If you are in a world, you can see what happened in that world. This is a consequence of Human Logic's inspectability guarantee.

**Theorem 21.1 — No Hidden Actions.**

Within a world, no member can take an action that other members cannot discover through audit.

*Proof.* Every action in a world is an expression through Mary. Every expression is logged (Mary Rule 9.2). Every member has read access to the ledger (Definition 21.3). Therefore every action is discoverable. ∎

---

## Part XIII — Inter-System Communication

### 22. Other Helenas

**Definition 22.1 — Federation.** Multiple Helena instances may exist on separate hardware. They are independent systems with independent Marys and independent ledgers.

**Definition 22.2 — Foreign Speaker.** A speaker on Helena-A is foreign to Helena-B. Foreign speakers cannot directly issue expressions on another Helena. They must communicate through a protocol.

**Definition 22.3 — Federation Protocol.** Two Helena instances communicate by creating matched bridge worlds:

```
On Helena-A:
  admin_A : ⊤ ⊢ helena_A.create_federation_bridge(helena_B, scope)

On Helena-B:
  admin_B : status(helena_A.proposal) = active ⊢ helena_B.accept_federation_bridge(helena_A, scope)
```

The bridge creates:
- A bridge world on Helena-A with a proxy speaker representing Helena-B
- A bridge world on Helena-B with a proxy speaker representing Helena-A

Messages are copied between bridge worlds through a network protocol. Each Helena logs incoming messages as expressions from the proxy speaker. The proxy speaker is clearly marked as foreign — its expressions carry a federation tag.

**Definition 22.4 — Federation Rules.**

```
F1. Foreign speakers cannot write to local speakers' variables.
F2. Foreign speakers cannot join local worlds (only bridge worlds).
F3. All federated messages pass through bridge worlds — no direct access.
F4. Either side can close the federation bridge unilaterally.
F5. Federation does not merge ledgers. Each Helena keeps its own.
```

**Theorem 22.1 — Federation Safety.**

A foreign Helena cannot modify local state outside the bridge world.

*Proof.* Foreign communication flows through proxy speakers in bridge worlds (Definition 22.3). Proxy speakers are members of bridge worlds only (Rule F2). Write ownership (Mary Axiom 8) prevents proxy speakers from writing to local speakers' variables. Bridge worlds are isolated from other worlds (Definition 4.3). Therefore foreign influence is contained to bridge worlds. ∎

---

## Part XIV — Formal Summary

### 23. Helena's Components

```
Helena = (
  worlds,              — isolated environments for speakers
  profiles,            — human-level speaker identity
  files,               — variables presented as persistent data
  interface,           — rendering and input system
  shell,               — human-readable command interface
  inspector,           — audit and history tools
  replay,              — state reconstruction and hypothetical exploration
  events,              — subscription and notification system
  templates,           — reusable world configurations
  quotas,              — resource management
  federation           — inter-system communication
)
```

### 24. Helena's Rules

```
H1.  Worlds are isolated by default.
H2.  World membership requires meeting entry conditions.
H3.  Permissions control world-level access, not memory-level access.
H4.  Files are variables. File history is ledger history.
H5.  Identity is self-declared.
H6.  Connections are mutual.
H7.  Blocking is unilateral.
H8.  Every input is an expression.
H9.  Every output is a function of state.
H10. Audit is a right, not a privilege.
H11. Templates are shared, not imposed.
H12. Federation is consensual and contained.
H13. Helena follows the same rules as every other speaker.
H14. Helena cannot override Mary.
```

### 25. System Calls (Helena to Mary)

```
Helena uses Mary's system calls from Mary v1.0 Definition 19.1:

SPEAKERS:       create_speaker, suspend_speaker, list_speakers
MEMORY:         read, write, list_vars
EXPRESSIONS:    submit, submit_loop, status
COMMUNICATION:  request, respond, pending_requests
LEDGER:         ledger_read, ledger_search, ledger_count
WORLD FLAGS:    set_world_flag, get_world_flag
```

### 26. Helena's Own System Calls (Helena to Speakers)

```
WORLDS:
  helena.create_world(name, permissions, entry_conditions) → world_id
  helena.join_world(world_id) → status
  helena.leave_world(world_id) → status
  helena.archive_world(world_id) → status
  helena.grant(world_id, speaker, permission) → status
  helena.revoke(world_id, speaker, permission) → status
  helena.propose_bridge(world_A, world_B, scope) → bridge_id
  helena.accept_bridge(bridge_id) → status

IDENTITY:
  helena.update_profile(field, value) → status
  helena.connect(speaker_id) → status
  helena.disconnect(speaker_id) → status
  helena.block(speaker_id) → status
  helena.unblock(speaker_id) → status

FILES:
  helena.create_file(world, name, content) → status
  helena.read_file(world, owner, name) → content
  helena.update_file(world, name, content) → status
  helena.file_history(world, name) → [entries]

INSPECTION:
  helena.inspect(target) → details
  helena.replay(from, to, speed) → playback
  helena.replay_if(from, to, modifications) → hypothetical playback
  helena.audit(world, from, to) → [entries]

EVENTS:
  helena.subscribe(event_type, scope, callback) → subscription_id
  helena.unsubscribe(subscription_id) → status

TEMPLATES:
  helena.create_template(name, config) → template_id
  helena.use_template(template_id) → world_id

FEDERATION:
  helena.create_federation_bridge(target_helena, scope) → bridge_id
  helena.accept_federation_bridge(bridge_id) → status
  helena.close_federation_bridge(bridge_id) → status

SHELL:
  helena.alias(shortcut, expansion) → status
```

---

## Part XV — Closing

### 27. The Complete Stack

```
Layer 0: Hardware
  Von Neumann silicon. Shared memory. Destructive writes. Anonymous execution.

Layer 1: Human Logic (the math)
  10 axioms. 10 inference rules. 25 theorems.
  Defines computation as speaker-attributed, three-valued, ledger-backed.
  Non-Von Neumann computation model.

Layer 2: Mary (the kernel)
  12 invariants. 10 guarantees. 28 system calls.
  Enforces Human Logic on Von Neumann hardware.
  Speaker registry. Partitioned memory. Append-only ledger. Request bus. Evaluator.

Layer 3: Helena (the operating system)
  14 rules. 34+ system calls. Federation protocol.
  Worlds. Files. Identity. Interface. Inspection. Events. Templates.
  Where humans live.

Layer 4: Worlds (applications)
  Built by speakers on Helena. Infinite variety.
  Each world is isolated, auditable, replayable.
  The human's space to create.
```

### 28. What Helena Proves

Helena proves that a human-centered operating system can be built entirely from Human Logic's axioms. No part of Helena violates or bypasses Mary. No part of Mary violates or bypasses Human Logic. The stack is consistent from math to interface.

Every file has an author. Every action has a receipt. Every world is inspectable. Every speaker controls their own data. Every interaction is voluntary. And every bit of it is built from one observation:

"If it's my birthday, I eat cake" should not be vacuously true.

That's the foundation. Everything else is a consequence.

---

*Helena v1.0*
*Jared Lewis, 2026*
*All rights reserved.*
