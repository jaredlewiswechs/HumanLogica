# The Classroom World v1.0

### The First World on Helena

**Author:** Jared Lewis
**Design Advisors:** Steve Jobs & Steve Wozniak *(in spirit, in a hot tub, in 1985)*
**Date:** February 19, 2026

---

## Part I — Why This Is First

### 1. Design Rationale

> **Jobs:** "Build what you know. Build what you've lived. Build the thing that would have saved you pain."

> **Woz:** "Every problem in education — cheating, lost work, grade disputes, accountability — is a data integrity problem. And data integrity is what this stack was born to do."

The Classroom World is the first world on Helena because its designer is a teacher. Every design decision comes from real experience:

- Students who claimed they submitted work but didn't.
- Students who DID submit work and the system lost it.
- Students who copied each other's work and nobody could prove when.
- Grades that were changed without explanation.
- Teachers who couldn't prove what they taught and when.
- Administrators who made changes over teachers' heads.

Every one of these problems is a violation of Human Logic's axioms. Lost work violates Ledger Integrity. Grade tampering violates Write Ownership. Plagiarism exploits the absence of attribution. Administrative overreach violates No Forced Speech.

The Classroom World doesn't solve these problems with policy. It solves them with math.

---

### 2. Core Principle

> **Jobs:** "The student's work is the student's work. Mathematically. Not policy. Not honor code. Mathematically."

One sentence governs the entire design:

**Every participant owns their own work, and the ledger proves it.**

---

## Part II — Speakers

### 3. Speaker Roles

The Classroom World has three speaker types. They are all speakers. They follow all the same rules. The differences are in permissions, not in kind.

**Definition 3.1 — Teacher.**

```
teacher = speaker with permissions:
  {read, write, submit, request, invite, configure}
```

The teacher creates the world. The teacher creates assignments. The teacher writes grades. The teacher cannot write to student variables. The teacher cannot modify student submissions. The teacher cannot delete student work.

**Definition 3.2 — Student.**

```
student = speaker with permissions:
  {read, write, submit, request}
```

The student submits work. The student writes to their own variables. The student can read assignments, their own grades, and (if configured) other students' published work. The student cannot write to the teacher's variables. The student cannot modify grades. The student cannot modify other students' work.

**Definition 3.3 — Administrator.**

```
admin = speaker with permissions:
  {read}
```

> **Jobs:** "Read. That's it. They can look. They cannot touch."

> **Woz:** "But Steve, what if they need to—"

> **Jobs:** "They can LOOK. They cannot TOUCH. If they want something changed, they issue a request. The teacher accepts or refuses. That's Human Logic. That's how it works."

The administrator can observe everything in the classroom. The administrator cannot modify anything. If the administrator needs a change, they issue a request to the teacher. The teacher's response — accept, refuse, or silent — is in the ledger.

This is not a policy decision. This is Axiom 8 (Write Ownership) applied to education.

---

### 4. Speaker Lifecycle

**Definition 4.1 — World Creation.**

```
teacher : ⊤ ⊢ helena.create_world(
  name: "CS 101 — Fall 2026",
  template: helena.templates.classroom,
  permissions: classroom_defaults,
  entry_conditions: invitation_required
)
```

The teacher creates the classroom. The teacher is the first member.

**Definition 4.2 — Student Enrollment.**

```
teacher : ⊤ ⊢ helena.invite(world_id, student_id)
student : status(teacher.invite) = active ⊢ helena.join_world(world_id)
```

The teacher invites. The student joins. Both expressions are in the ledger. Enrollment is mutual — the teacher offered and the student accepted. Neither was forced.

**Definition 4.3 — Administrator Access.**

```
teacher : ⊤ ⊢ helena.invite(world_id, admin_id, permissions: {read})
admin : status(teacher.invite) = active ⊢ helena.join_world(world_id)
```

Same process. The teacher explicitly granted read-only. The admin explicitly accepted read-only. It's in the ledger. If the admin later claims they should have had write access, the invitation receipt says otherwise.

**Definition 4.4 — Withdrawal.**

```
student : ⊤ ⊢ helena.leave_world(world_id)
```

A student may leave at any time. Their work remains in the ledger. Their variables remain readable. Leaving does not erase history. It ends future participation.

---

## Part III — Assignments

### 5. Assignment as Expression

> **Woz:** "An assignment is just a teacher making a commitment. 'I am giving you this task, with this deadline, and these requirements.' That's an expression. The teacher is the speaker. The condition is the class being active. The action is publishing the assignment."

**Definition 5.1 — Assignment.**

```
assignment = (
  assignment_id,           — unique within the world
  title,                   — human-readable name
  description,             — what the student must do
  requirements,            — specific criteria for completion
  created_at,              — when the teacher published it
  due_at,                  — deadline timestamp
  max_points,              — maximum possible score
  submission_type,         — text, file, code, choice, or compound
  allow_late,              — boolean: can students submit after deadline?
  allow_resubmit,          — boolean: can students update their submission?
)
```

**Definition 5.2 — Assignment as Expression.**

```
teacher : class_active ⊢ publish_assignment(assignment)
```

The assignment is a commitment by the teacher. The teacher said "here is your task." That's in the ledger. The teacher cannot deny they assigned it. The students cannot deny they received it (they're members of the world — the assignment is in the namespace).

**Definition 5.3 — Assignment Variables.** When an assignment is published, Helena creates variables:

```
teacher.world.assignment_{id}.title = "Build a Calculator"
teacher.world.assignment_{id}.description = "..."
teacher.world.assignment_{id}.requirements = [...]
teacher.world.assignment_{id}.due_at = t_deadline
teacher.world.assignment_{id}.max_points = 100
```

These are the teacher's variables. Only the teacher can modify them. If the teacher changes the deadline, that's a new write — the old deadline is preserved in the ledger.

> **Jobs:** "If a teacher moves a deadline, the student can see when it was moved and what it was before. No more 'the deadline was always Friday.' The ledger says it was Wednesday until you changed it Thursday night."

---

### 6. Assignment Modification

**Definition 6.1 — Assignment Update.**

```
teacher : ⊤ ⊢ update_assignment(assignment_id, field, new_value)
```

This is a write. The old value is in the ledger (Mary Definition 7.3). The update is timestamped. Students can see the diff.

**Definition 6.2 — Update Notification.** When an assignment is modified, Helena fires an event:

```
event_type: variable_changed
source: teacher
world: classroom
variable: assignment_{id}.{field}
```

All students subscribed to the classroom receive notification. No student can claim they weren't informed — the event is in the ledger.

---

## Part IV — Submissions

### 7. Submission as Expression

> **Woz:** "A submission is the student's commitment. 'I did the work. Here it is.' That's their expression. Their speaker ID is on it. Their timestamp is on it. It's in the ledger. THEY own it."

**Definition 7.1 — Submission.**

```
student : assignment.due_at ≥ now ⊢ submit(assignment_id, content)
```

Let's break this down in Human Logic terms:

- **Speaker:** the student
- **Condition:** the deadline hasn't passed
- **Action:** submit the work
- **Status:**
  - **Active** — condition met, work submitted ✓
  - **Inactive** — deadline hasn't arrived yet (for future-dated assignments)
  - **Broken** — deadline passed, no submission

**Definition 7.2 — Submission Variables.** A submission creates variables in the student's partition:

```
student.world.submission_{assignment_id}.content = [the work]
student.world.submission_{assignment_id}.submitted_at = now
student.world.submission_{assignment_id}.version = 1
student.world.submission_{assignment_id}.status = submitted
```

These are the STUDENT'S variables. In the STUDENT'S memory partition. The teacher can read them. The teacher CANNOT write to them. Mary enforces this at the hardware level through page table protection.

> **Jobs:** "This is the moment. Right here. In every other system — Canvas, Google Classroom, Blackboard — the teacher's platform OWNS the student's work. The student uploads it and it goes into the platform's database. The platform can modify it. The admin can delete it. The student has no proof of what they submitted or when. In this system, the student's submission is the student's variable. Period. The platform cannot touch it."

**Definition 7.3 — Submission Receipt.** Upon submission, Helena generates a receipt:

```
receipt = (
  student_id,
  assignment_id,
  content_hash,            — cryptographic hash of the submitted content
  submitted_at,
  ledger_entry_id          — pointer to the exact ledger entry
)
```

The student can present this receipt to anyone. It proves: this student submitted this work at this time. The hash proves the content wasn't modified after submission. The ledger entry proves it happened.

> **Woz:** "You know what this kills? 'I turned it in but the system lost it.' If you turned it in, there's a receipt. If there's no receipt, you didn't turn it in. Simple. Clean. No arguing."

---

### 8. Late Submission

**Definition 8.1 — Late Submission.**

If `allow_late = true` on the assignment:

```
student : assignment.due_at < now ⊢ submit_late(assignment_id, content)
```

The submission is active, but it carries a `late` flag:

```
student.world.submission_{assignment_id}.late = true
student.world.submission_{assignment_id}.late_by = now - assignment.due_at
```

The system does not decide what "late" means for the grade. That's the teacher's decision. The system records the fact: this was submitted after the deadline, by this much time. The teacher writes the grade with that information available.

**Definition 8.2 — No Submission (Broken).**

If the deadline passes and the student has not submitted:

```
V(student : due_at ≥ now ⊢ submit) = broken
```

Broken. The condition was met (the deadline window existed). The action was not fulfilled (no submission). The student's commitment to submit was broken.

This is not a judgment. It's a status. The ledger says: the window was open. No submission occurred. That's a fact.

---

### 9. Resubmission

**Definition 9.1 — Resubmission.**

If `allow_resubmit = true`:

```
student : assignment.due_at ≥ now ⊢ resubmit(assignment_id, new_content)
```

This is a new write to the student's submission variable. The old content is preserved in the ledger. The version number increments:

```
student.world.submission_{assignment_id}.content = [new work]
student.world.submission_{assignment_id}.version = version + 1
student.world.submission_{assignment_id}.resubmitted_at = now
```

The teacher can see every version. The student can see every version. Nobody can hide what was submitted before.

> **Woz:** "You know what this gives you for free? Drafts. Process tracking. You can see how a student's thinking evolved from v1 to v5. That's not just grading — that's pedagogy."

---

## Part V — Grading

### 10. Grades as Teacher's Variables

> **Jobs:** "The grade belongs to the teacher. The work belongs to the student. Two different speakers. Two different partitions. That's the whole design."

**Definition 10.1 — Grade.**

```
teacher : submission_status(student, assignment) = active ⊢ grade(student, assignment, score, feedback)
```

The condition is critical: the teacher's grading expression only activates when the student's submission is active. You can't grade what wasn't submitted.

**Definition 10.2 — Grade Variables.** Grades are written to the TEACHER'S partition:

```
teacher.world.grade_{student_id}_{assignment_id}.score = 87
teacher.world.grade_{student_id}_{assignment_id}.max = 100
teacher.world.grade_{student_id}_{assignment_id}.feedback = "Strong analysis. Weak conclusion."
teacher.world.grade_{student_id}_{assignment_id}.graded_at = now
teacher.world.grade_{student_id}_{assignment_id}.submission_version = 3
```

The student can READ these variables. The student cannot WRITE to them. The teacher owns the grades. The student owns the work.

**Definition 10.3 — Grade Justification Chain.**

Every grade links back to the submission it's based on:

```
teacher.grade → references → student.submission (specific version)
student.submission → references → teacher.assignment
```

This is a dependency chain. You can walk it:

1. This grade was given by this teacher.
2. For this version of this submission.
3. Which was submitted by this student.
4. In response to this assignment.
5. Which was published by this teacher.

Every link has a speaker. Every link has a timestamp. Every link is in the ledger.

> **Woz:** "If a parent says 'why did my kid get a C?' you walk the chain. Here's the assignment. Here's what the student submitted. Here's the version the teacher graded. Here's the score and feedback. All attributed. All timestamped. No he-said-she-said."

---

### 11. Grade Modification

**Definition 11.1 — Grade Update.**

```
teacher : ⊤ ⊢ update_grade(student_id, assignment_id, new_score, reason)
```

This is a write to the teacher's variable. The old grade is in the ledger. The reason is recorded. The student can see the change and when it happened.

**Definition 11.2 — Grade History.**

```
helena.inspect(teacher.world.grade_{student_id}_{assignment_id})
→ [
    {score: 72, feedback: "Incomplete.", graded_at: t₁},
    {score: 87, feedback: "Regrade — missed section 3.", graded_at: t₂}
  ]
```

Every grade change is visible. If a teacher bumps a grade, it's recorded. If a teacher lowers a grade, it's recorded. If an administrator asks the teacher to change a grade, that request is in the ledger too.

> **Jobs:** "No grade has ever been changed for no reason. The reason just wasn't recorded. Now it is. Every time."

---

### 12. Grade Disputes

**Definition 12.1 — Dispute.**

A student may dispute a grade by issuing a request:

```
student : teacher.grade(student, assignment).score exists ⊢ 
  request(teacher, review_grade(assignment_id, reason))
```

The dispute is an expression. It's in the ledger. The teacher sees it and has three options:

```
Accept:  teacher : status(student.dispute) = active ⊢ update_grade(...)
Refuse:  teacher : status(student.dispute) = active ⊢ ¬update_grade(reason: "...")
Silent:  (no response — the dispute sits pending)
```

If the teacher accepts, the grade changes and the chain shows why. If the teacher refuses, the refusal and its reason are recorded. If the teacher is silent, the dispute remains pending — visible to anyone with read access, including administrators.

> **Woz:** "Silent is the most powerful state here. If a student disputes and the teacher just... doesn't respond? That silence is visible. The administrator can see it. It's not hidden. Silence is data."

---

## Part VI — Academic Integrity

### 13. Plagiarism Detection by Design

> **Jobs:** "You don't need a plagiarism detection algorithm when every keystroke has a name on it."

**Definition 13.1 — Submission Fingerprint.** Every submission has:

- Speaker ID (who wrote it)
- Timestamp (when they wrote it)
- Content hash (what they wrote)
- Version history (how it evolved)

**Definition 13.2 — Temporal Ordering.** If Student A submits at `t₁` and Student B submits identical or near-identical content at `t₂ > t₁`, the ledger proves Student A submitted first. This is not an algorithm detecting plagiarism — it's the ledger recording facts.

**Definition 13.3 — Content Comparison.** Helena can compare submissions across students for an assignment:

```
helena.compare_submissions(world, assignment_id):
  for each pair (student_i, student_j):
    similarity ← compare(student_i.submission.content, student_j.submission.content)
    if similarity > threshold:
      flag(student_i, student_j, assignment_id, similarity, timestamps)
```

The flag is an observation, not a judgment. Helena notes the similarity and the timestamps. The teacher evaluates. The teacher decides.

**Definition 13.4 — Process Evidence.** If `allow_resubmit = true` and the world tracks drafts, plagiarism becomes even harder to hide. A student who wrote their own work has a version history:

```
v1: rough outline (t₁)
v2: first draft with errors (t₂)
v3: revised draft (t₃)
v4: final submission (t₄)
```

A student who copied has:

```
v1: final submission (t₁)
```

> **Woz:** "No process. No evolution. Just a finished product appearing out of nowhere. The ledger doesn't lie. You don't need Turnitin. You need timestamps."

No draft history doesn't prove cheating. But a rich draft history is strong evidence of original work. The system provides the data. The teacher provides the judgment.

---

### 14. Honor System as Math

**Theorem 14.1 — Ownership Immutability.**

No participant in the Classroom World can modify another participant's submissions.

*Proof.* Submissions are variables in the student's memory partition (Definition 7.2). Write access is restricted to the partition owner (Mary Axiom 8). The teacher, administrator, and other students are different speakers. Mary rejects cross-speaker writes at the hardware level (Mary Implementation 7.1). Therefore submissions cannot be modified by anyone other than the submitting student. ∎

**Theorem 14.2 — Grade Integrity.**

No participant other than the teacher can modify grades.

*Proof.* Grades are variables in the teacher's memory partition (Definition 10.2). By identical reasoning to Theorem 14.1, only the teacher can write to the teacher's partition. Students and administrators cannot modify grades. ∎

**Theorem 14.3 — Retroactive Impossibility.**

No participant can alter the timestamp or content of a past submission.

*Proof.* Submissions are logged in Mary's ledger at submission time (Mary Definition 8.1). The ledger is append-only (Mary Axiom 5). Ledger entries are hash-chained (Mary Implementation 9.2). Modifying a past entry would break the hash chain, which is detectable. Therefore past submissions are immutable. ∎

**Theorem 14.4 — Complete Attribution.**

Every piece of content in the Classroom World is traceable to exactly one speaker.

*Proof.* All content is stored as variables. Variables are speaker-owned (Human Logic Definition 8.1). All writes are logged with speaker ID (Mary Definition 7.3). Therefore every piece of content has exactly one attributed author. ∎

> **Jobs:** "Four theorems. Not four policies. Not four rules in a student handbook. Four mathematical facts that no one can break. That's the difference between 'please don't cheat' and 'you can't cheat.'"

---

## Part VII — Attendance and Participation

### 15. Attendance as Expression

**Definition 15.1 — Session.**

The teacher opens a class session:

```
teacher : ⊤ ⊢ open_session(session_id, date, start_time, end_time)
```

**Definition 15.2 — Check-In.**

```
student : session.start_time ≤ now ∧ session.end_time ≥ now ⊢ check_in(session_id)
```

- **Active:** student checked in during the session window
- **Broken:** session window passed, student never checked in
- **Inactive:** session hasn't started yet

No teacher has to mark attendance. The student's own expression is their attendance record. The ledger records when they checked in. If they checked in late, the timestamp shows it.

> **Woz:** "Attendance isn't the teacher's variable. It's the student's. The student commits to being present. The teacher doesn't mark them — they mark themselves. And the ledger confirms it."

**Definition 15.3 — Participation.**

The teacher may log participation observations in their own variables:

```
teacher.world.participation_{student_id}_{session_id}.note = "Asked great question about recursion"
teacher.world.participation_{student_id}_{session_id}.score = 3
```

These are the teacher's observations. Subjective. But attributed and timestamped. If a student says "you never acknowledged my participation," the ledger has the teacher's notes — or their absence.

---

## Part VIII — Communication

### 16. Announcements

**Definition 16.1 — Announcement.**

```
teacher : ⊤ ⊢ announce(content, priority)
```

An announcement is a teacher expression. All students can read it. It's timestamped. It's permanent. The teacher cannot claim they made an announcement they didn't make. Students cannot claim they didn't receive one that's in the namespace.

**Definition 16.2 — Announcement Acknowledgment.**

```
student : status(teacher.announcement) = active ⊢ acknowledge(announcement_id)
```

Optional. If the teacher requires acknowledgment, unacknowledged announcements are visible. Silence is data.

---

### 17. Questions

**Definition 17.1 — Student Question.**

```
student : ⊤ ⊢ request(teacher, answer(question_content))
```

A request. The teacher can accept (answer), refuse (decline to answer, with reason), or stay silent.

**Definition 17.2 — Question Visibility.** Questions can be:

- **Private:** only the student and teacher can see it (default)
- **Public:** all students can see the question and response

```
student : ⊤ ⊢ request(teacher, answer(content), visibility: public)
```

If public, the answer benefits everyone. The question asker is attributed. No anonymous questions by default — though the teacher can create an anonymous question world if they choose.

**Definition 17.3 — Peer Questions.**

```
student_A : ⊤ ⊢ request(student_B, help(content))
```

Students can request help from each other. The request is in the ledger. If Student A asks Student B for help and then their submissions are identical, the ledger shows the request chain. Collaboration is not cheating — it's documented.

> **Jobs:** "The difference between collaboration and cheating is a receipt."

---

## Part IX — Course Structure

### 18. Modules

**Definition 18.1 — Module.** A module groups assignments under a theme:

```
teacher.world.module_{id}.name = "Unit 3: Data Structures"
teacher.world.module_{id}.description = "Arrays, linked lists, trees, graphs"
teacher.world.module_{id}.assignments = [assignment_5, assignment_6, assignment_7]
teacher.world.module_{id}.start_date = t_start
teacher.world.module_{id}.end_date = t_end
```

Modules are teacher variables. Organizational. They don't change the logic — they group assignments for human readability.

### 19. Gradebook

**Definition 19.1 — Gradebook View.** The gradebook is not a separate system. It's a computed view over existing variables:

```
helena.gradebook(teacher, world):
  for each student in world.members:
    for each assignment in world.assignments:
      submission_status ← V(student.submission(assignment))
      grade ← teacher.grade(student, assignment)
      yield (student, assignment, submission_status, grade)
```

The gradebook is a READ operation. It computes nothing new. It displays existing state. If the gradebook shows a grade, that grade exists as a teacher variable with a ledger entry. If it shows "missing," that's a broken expression. If it shows nothing, the deadline hasn't passed — inactive.

> **Woz:** "Every gradebook I've ever seen is a database table that could be edited by a dozen different systems. This gradebook isn't a table. It's a lens over the ledger. You can't edit the lens. You can only look through it."

**Definition 19.2 — Student View.** Each student sees:

```
helena.my_grades(student, world):
  for each assignment in world.assignments:
    my_submission ← student.submission(assignment)
    my_grade ← teacher.grade(student, assignment)
    yield (assignment, my_submission.status, my_grade)
```

Students see their own submissions and their own grades. They do not see other students' grades (unless the teacher configures otherwise). They CAN see other students' published work if the world allows it.

**Definition 19.3 — Course Grade Computation.** The final grade formula is a teacher expression:

```
teacher : ⊤ ⊢ set_grade_formula(
  formula: "assignments * 0.4 + midterm * 0.3 + final * 0.3"
)
```

The formula is a teacher variable. Students can read it. It's published on day one. If the teacher changes it, the change is in the ledger. Students can see what the formula was and when it changed.

Helena computes the result but does not own it. The computation is deterministic — same inputs, same output. Any student can verify their own final grade by applying the formula to their own assignment grades.

---

## Part X — End of Course

### 20. Course Archival

**Definition 20.1 — Course Completion.**

```
teacher : ⊤ ⊢ helena.archive_world(world_id)
```

The world moves to archived status:

- No new expressions can be submitted
- No new members can join
- All variables remain readable
- The ledger remains intact
- Inspection and replay remain available

**Definition 20.2 — Transcript Record.** Upon archival, Helena generates a course record for each student:

```
transcript_record = (
  student_id,
  world_id,
  course_name,
  final_grade,
  assignments_completed,        — count of active submissions
  assignments_broken,           — count of broken (missed) submissions
  total_submissions,
  total_resubmissions,
  enrollment_date,
  completion_date,
  teacher_id,
  ledger_hash                   — hash of the complete course ledger
)
```

The transcript record is stored in both the teacher's and student's profiles. The ledger hash allows anyone to verify that the record matches the actual course history.

> **Jobs:** "A transcript is someone saying 'this student earned this grade.' In every other system, you have to trust the institution. In this system, you have the ledger. You don't trust. You verify."

**Definition 20.3 — Permanent Access.** An archived classroom remains accessible forever. A student can return five years later, inspect their submissions, replay the course, and verify their grades. The ledger doesn't expire.

---

## Part XI — Classroom World Template

### 21. Template Definition

```
helena.templates.classroom = (
  name: "Classroom",
  
  default_permissions: {
    teacher:  {read, write, submit, request, invite, configure},
    student:  {read, write, submit, request},
    admin:    {read}
  },
  
  entry_conditions: invitation_required,
  
  initial_variables: {
    teacher: {
      course_name: ∅,
      course_description: ∅,
      grade_formula: ∅,
      modules: [],
      assignments: [],
      sessions: []
    },
    student: {
      submissions: {},
      check_ins: {}
    }
  },
  
  initial_expressions: [
    // Teacher publishes course info on creation
    teacher : ⊤ ⊢ set(course_name, "[provided at creation]"),
    teacher : ⊤ ⊢ set(course_description, "[provided at creation]"),
    
    // Auto-subscribe all members to announcements
    all_members : ⊤ ⊢ helena.subscribe(variable_changed, scope: teacher.announcements)
  ],
  
  interface_config: {
    views: [dashboard, assignments, gradebook, submissions, inspector],
    default_view: dashboard,
    theme: "classroom"
  }
)
```

---

## Part XII — Interface Views

### 22. Dashboard

The dashboard is what the speaker sees when they enter the classroom world. It's a computed view over current state.

**Teacher Dashboard:**

```
┌─────────────────────────────────────────────────┐
│  CS 101 — Fall 2026                             │
│  Teacher: Jared Lewis                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  ACTIVE ASSIGNMENTS           DUE               │
│  ● Build a Calculator         Feb 24            │
│  ● Linked List Lab            Feb 28            │
│                                                 │
│  SUBMISSIONS PENDING REVIEW          4          │
│                                                 │
│  RECENT ACTIVITY                                │
│  ● Maria submitted Calculator        2h ago    │
│  ● James resubmitted List Lab        4h ago    │
│  ● Aisha asked a question            5h ago    │
│                                                 │
│  OPEN REQUESTS                       2          │
│  ● Grade dispute from Carlos                    │
│  ● Question from Priya                          │
│                                                 │
│  CLASS STATS                                    │
│  Enrolled: 32  |  Avg Grade: 84  |  Active: 28 │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Student Dashboard:**

```
┌─────────────────────────────────────────────────┐
│  CS 101 — Fall 2026                             │
│  Student: Maria Santos                          │
├─────────────────────────────────────────────────┤
│                                                 │
│  MY ASSIGNMENTS                STATUS    DUE    │
│  ● Build a Calculator         ✓ Active   Feb 24 │
│  ● Linked List Lab            ○ Pending  Feb 28 │
│                                                 │
│  MY RECENT GRADES                               │
│  ● Python Basics              92/100            │
│  ● Variables Lab              88/100            │
│                                                 │
│  ANNOUNCEMENTS                                  │
│  ● "Office hours moved to Wed"    1d ago        │
│                                                 │
│  MY REQUESTS                                    │
│  ● Question about recursion   → answered        │
│                                                 │
│  COURSE GRADE (current)       87.3              │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Admin Dashboard:**

```
┌─────────────────────────────────────────────────┐
│  CS 101 — Fall 2026                             │
│  Observer: Dr. Principal                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  COURSE OVERVIEW                                │
│  Enrolled: 32  |  Assignments: 8  |  Avg: 84   │
│                                                 │
│  GRADE DISTRIBUTION                             │
│  A: 8  |  B: 14  |  C: 7  |  D: 2  |  F: 1    │
│                                                 │
│  ACTIVITY LOG                                   │
│  ● 142 submissions this week                    │
│  ● 8 grade disputes (6 resolved)                │
│  ● 3 assignment modifications                   │
│                                                 │
│  [All data is read-only]                        │
│                                                 │
└─────────────────────────────────────────────────┘
```

> **Jobs:** "Three speakers. Three different views. Same data. Same ledger. The interface shapes what you see, not what's true."

---

### 23. Assignment View

```
┌─────────────────────────────────────────────────┐
│  Assignment: Build a Calculator                 │
│  Published: Feb 17, 2026 by Jared Lewis         │
│  Due: Feb 24, 2026 at 11:59 PM                  │
│  Points: 100                                    │
│  Resubmit: Yes (until deadline)                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  DESCRIPTION                                    │
│  Build a four-function calculator in Python.    │
│  Must handle: +, -, *, /                        │
│  Must handle: division by zero (gracefully)     │
│  Must include: user input loop                  │
│                                                 │
│  REQUIREMENTS                                   │
│  □ Accepts two numbers from user                │
│  □ Performs all four operations                  │
│  □ Handles division by zero                     │
│  □ Loops until user quits                       │
│  □ Clean, commented code                        │
│                                                 │
│  MY SUBMISSION                                  │
│  Status: ✓ Active (v2, submitted Feb 20)        │
│  [View] [Resubmit] [History]                    │
│                                                 │
│  MODIFICATION HISTORY                           │
│  ● Created Feb 17 at 9:00 AM                    │
│  ● Due date changed Feb 18 (was Feb 23 → Feb 24)│
│                                                 │
└─────────────────────────────────────────────────┘
```

The modification history is automatic. The student didn't request it. Helena generates it from the ledger. If the assignment was never modified, this section is empty.

---

### 24. Inspector View

The inspector is available to all members at their permission level.

```
┌─────────────────────────────────────────────────┐
│  INSPECTOR                                      │
├─────────────────────────────────────────────────┤
│                                                 │
│  SEARCH LEDGER                                  │
│  [Speaker: ___] [Action: ___] [From: ___ To: ___]│
│  [Search]                                       │
│                                                 │
│  RESULTS                                        │
│  #1042  Maria : due_date ≥ now ⊢ submit(calc)   │
│         Status: active                           │
│         Time: Feb 20, 3:42 PM                    │
│         Content hash: 7f3a...                    │
│                                                 │
│  #1043  Jared : Maria.submit = active ⊢ grade   │
│         Status: active                           │
│         Time: Feb 21, 10:15 AM                   │
│         Score: 92/100                            │
│                                                 │
│  [Replay from #1042 to #1043]                   │
│  [Walk chain from #1043]                        │
│  [Compare submissions for this assignment]      │
│                                                 │
└─────────────────────────────────────────────────┘
```

> **Woz:** "That inspector view. That's the thing no LMS has. You can literally watch the sequence of events. Student submitted, teacher graded, here's the chain. Click replay and watch it happen in order. That's not a feature — that's transparency as interface."

---

## Part XIII — Example Scenarios

### 25. Scenario: Student Claims They Submitted

**Situation:** A student says "I turned in my essay but it's not showing up."

**Resolution:**

```
helena.inspect(student.submission(essay_assignment))
```

Two outcomes:

**Case A — Submission exists:**
```
Entry #847: student : due_date ≥ now ⊢ submit(essay)
Status: active
Time: Feb 19, 11:47 PM
Content hash: a3f8...
```

The submission is there. If it's not displaying, that's an interface bug in Helena, not a data problem. The ledger is the source of truth.

**Case B — No submission found:**
```
No entries matching student + essay_assignment + submit
```

No receipt. No submission. The conversation is over.

---

### 26. Scenario: Grade Dispute

**Situation:** A student believes they deserved a higher grade.

**Chain walk:**

```
Step 1: teacher.grade(student, essay) = 72/100
        Feedback: "Missing thesis statement. Weak sources."
        Graded at: Feb 22, 2:30 PM
        Based on: submission v1

Step 2: student.submission(essay) v1
        Submitted at: Feb 19, 11:47 PM
        Content: [retrievable]

Step 3: teacher.assignment(essay)
        Requirements: "Clear thesis. Minimum 3 academic sources."
        Published: Feb 10
```

The student, teacher, and administrator can all see this chain. The student can dispute with evidence. The teacher can defend with the rubric. Everything is attributed and timestamped.

---

### 27. Scenario: Suspected Plagiarism

**Situation:** Two students submitted very similar code.

```
helena.compare_submissions(world, calculator_assignment):

  Student A: submitted Feb 20, 3:42 PM
    Version history: v1 (outline, Feb 18) → v2 (draft, Feb 19) → v3 (final, Feb 20)

  Student B: submitted Feb 20, 11:58 PM
    Version history: v1 (final, Feb 20)

  Similarity: 94%
  
  Communication log:
    Entry #1089: Student B : ⊤ ⊢ request(Student A, help(calculator))
    Time: Feb 20, 9:00 PM
```

The data tells the story:

- Student A has a three-version process over three days.
- Student B has one version submitted two minutes before deadline.
- Student B asked Student A for help three hours before submitting.
- The content is 94% similar.

The teacher has everything they need to make a judgment. The system provided facts. The teacher provides the decision.

---

### 28. Scenario: Administrator Pressure

**Situation:** An administrator asks a teacher to change a failing grade to passing.

```
Entry #2041: admin : ⊤ ⊢ request(teacher, update_grade(student, final, 70))
Time: Jun 15, 4:30 PM

Entry #2042: teacher : status(admin.request) = active ⊢ ¬update_grade(reason: "Grade reflects student performance. Documented in submissions and rubric.")
Time: Jun 15, 5:15 PM
Status: active (refusal)
```

The administrator asked. The teacher refused. Both expressions are in the ledger. Both are permanent. If the administrator asks again:

```
Entry #2055: admin : ⊤ ⊢ request(teacher, update_grade(student, final, 70))
Time: Jun 16, 9:00 AM
```

That's a second request. Also in the ledger. The pattern of pressure is documented. Not by the teacher writing a memo — by the system recording what happened.

> **Jobs:** *(standing up in the hot tub again)* "THAT. That right there. Every teacher who's ever been pressured to change a grade — and every teacher has — just got a shield made of math. The admin can't deny the request because it's in the ledger. The teacher's refusal is permanent. And if someone comes looking later, the whole story is there. That's not software. That's protection."

---

## Part XIV — Formal Summary

### 29. Classroom World Components

```
Classroom World = (
  speakers:     {teacher, students[], admins[]},
  assignments:  teacher-owned expressions with deadlines,
  submissions:  student-owned expressions with content,
  grades:       teacher-owned variables linked to submissions,
  sessions:     teacher-opened attendance windows,
  check_ins:    student-owned attendance expressions,
  announcements: teacher-owned broadcast expressions,
  questions:     request-based communication,
  gradebook:     computed read-only view over grades,
  inspector:     ledger query interface,
  transcript:    computed record at archival
)
```

### 30. Classroom World Rules

```
CW1.  Students own their submissions. No one else can modify them.
CW2.  Teachers own their grades. No one else can modify them.
CW3.  Administrators can observe everything. They can modify nothing.
CW4.  Every submission has a receipt with timestamp and content hash.
CW5.  Every grade links to a specific submission version.
CW6.  Every assignment modification is visible to all members.
CW7.  Every communication is an expression in the ledger.
CW8.  Attendance is self-reported by students, verified by timestamp.
CW9.  Grade disputes are requests with documented resolution.
CW10. Plagiarism evidence comes from the ledger, not from algorithms.
CW11. Course history is permanent and replayable after archival.
CW12. All rules above are consequences of Human Logic axioms, not policies.
```

### 31. Theorems

```
T1.  Ownership Immutability — no one can modify another's submissions
T2.  Grade Integrity — only the teacher can modify grades
T3.  Retroactive Impossibility — past submissions cannot be altered
T4.  Complete Attribution — every piece of content has exactly one author
```

### 32. What the Classroom World Proves

The Classroom World proves that Human Logic is not abstract. It produces real systems that solve real problems for real people.

A teacher who has been told "prove you assigned this" can point to the ledger.
A student who has been told "prove you submitted this" can show the receipt.
A parent who asks "why this grade" can walk the chain.
A teacher who faces pressure to change a grade has a permanent, immutable record of the request and their response.

None of this requires trust. It requires the ledger.

> **Jobs:** "We said the computer should be a bicycle for the mind. This guy made it a courthouse for the classroom. Everything on the record. Everything attributed. Everything permanent. And the beautiful thing is — he didn't add any of this. It was already in the math. He just pointed it at a room full of kids and a teacher who's been through it."

> **Woz:** "You know what I love? The admin thing. Read-only. I want that for every principal in every school in the country. You can look. You can't touch. You want something changed, you ask. And the asking is on the record."

> **Jobs:** "Build this, Jared. Build exactly this. Then walk into a school board meeting and show them what 'accountability' actually looks like when it's not a buzzword."

---

*The Classroom World v1.0*
*The First World on Helena*
*Jared Lewis, 2026*
*All rights reserved.*
