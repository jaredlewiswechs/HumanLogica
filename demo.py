"""
Full Stack Demo — Human Logic → Mary → Helena → Classroom
==========================================================
Author: Jared Lewis
Date: February 19, 2026

Run this file. No input needed. It proves the entire stack works.

    python3 demo.py

After this runs, you can use classroom.py for the interactive shell.
"""

from mary import Mary, Status
from helena import Helena, WorldPermissions
from classroom import Classroom
import time


def divider(title):
    print()
    print(f"── {title} ──")


def main():
    print("=" * 65)
    print("  THE FULL STACK")
    print("  Human Logic → Mary → Helena → Classroom World")
    print("  Author: Jared Lewis, 2026")
    print("=" * 65)

    # ================================================================
    # LAYER 1: Boot Helena (which boots Mary inside)
    # ================================================================
    divider("BOOT")
    helena = Helena()
    print(f"  Helena booted: {helena}")
    print(f"  Mary inside:   {helena.mary}")
    print(f"  Ledger intact: {helena.mary.ledger_verify()}")

    # ================================================================
    # LAYER 2: Create Speakers
    # ================================================================
    divider("SPEAKERS")
    teacher_id = helena.create_speaker("Jared")
    maria_id   = helena.create_speaker("Maria")
    james_id   = helena.create_speaker("James")
    aisha_id   = helena.create_speaker("Aisha")
    admin_id   = helena.create_speaker("Dr. Principal")

    print(f"  Teacher:  Jared         (speaker #{teacher_id})")
    print(f"  Student:  Maria         (speaker #{maria_id})")
    print(f"  Student:  James         (speaker #{james_id})")
    print(f"  Student:  Aisha         (speaker #{aisha_id})")
    print(f"  Admin:    Dr. Principal (speaker #{admin_id})")

    # ================================================================
    # LAYER 3: Create Classroom World
    # ================================================================
    divider("CREATE CLASSROOM")
    classroom = Classroom(helena, teacher_id, "CS 101 — Spring 2026")
    print(f"  World created: {classroom.world_id}")
    print(f"  Course: {classroom.course_name}")

    # Enroll students
    classroom.enroll_student(maria_id)
    classroom.enroll_student(james_id)
    classroom.enroll_student(aisha_id)
    classroom.add_admin(admin_id)
    print(f"  Enrolled: Maria, James, Aisha")
    print(f"  Admin added: Dr. Principal (READ-ONLY)")

    students = classroom.get_students()
    print(f"  Total students: {len(students)}")

    # ================================================================
    # LAYER 4: Create Assignments
    # ================================================================
    divider("ASSIGNMENTS")
    a1 = classroom.create_assignment(
        "Build a Calculator",
        "Build a four-function calculator in Python. Handle division by zero.",
        max_points=100,
        allow_resubmit=True,
    )
    a2 = classroom.create_assignment(
        "Linked List Lab",
        "Implement a singly linked list with insert, delete, and search.",
        max_points=100,
    )
    print(f"  {a1}: Build a Calculator (100 pts)")
    print(f"  {a2}: Linked List Lab (100 pts)")

    # ================================================================
    # LAYER 5: Student Submissions
    # ================================================================
    divider("SUBMISSIONS")

    # Maria submits calculator — good work
    r1 = classroom.submit_work(maria_id, a1,
        "def calc(a, op, b):\n"
        "    if op == '+': return a + b\n"
        "    if op == '-': return a - b\n"
        "    if op == '*': return a * b\n"
        "    if op == '/': return 'Error: div/0' if b == 0 else a / b\n"
    )
    print(f"  Maria submitted {a1}: v{r1['version']}, hash={r1['content_hash']}")

    # James submits calculator — lazy work
    r2 = classroom.submit_work(james_id, a1, "print(2+2)")
    print(f"  James submitted {a1}: v{r2['version']}, hash={r2['content_hash']}")

    # Aisha submits calculator — then resubmits (improved version)
    r3 = classroom.submit_work(aisha_id, a1, "# first attempt\nresult = input() + input()")
    print(f"  Aisha submitted {a1}: v{r3['version']}, hash={r3['content_hash']}")

    r3b = classroom.submit_work(aisha_id, a1,
        "def calculator():\n"
        "    while True:\n"
        "        a = float(input('First number: '))\n"
        "        op = input('Operator: ')\n"
        "        b = float(input('Second number: '))\n"
        "        if op == '/' and b == 0: print('Cannot divide by zero')\n"
        "        else: print(eval(f'{a}{op}{b}'))\n"
    )
    print(f"  Aisha RESUBMITTED {a1}: v{r3b['version']}, hash={r3b['content_hash']}")
    print(f"    ↑ Old version preserved in ledger. Both versions exist.")

    # Maria submits linked list
    r4 = classroom.submit_work(maria_id, a2,
        "class Node:\n"
        "    def __init__(self, val): self.val = val; self.next = None\n"
        "class LinkedList:\n"
        "    def __init__(self): self.head = None\n"
        "    def insert(self, val): ...\n"
        "    def delete(self, val): ...\n"
        "    def search(self, val): ...\n"
    )
    print(f"  Maria submitted {a2}: v{r4['version']}, hash={r4['content_hash']}")

    # James does NOT submit linked list (will be broken)
    print(f"  James did NOT submit {a2}. ← This will show as missing.")

    # ================================================================
    # LAYER 6: Write Ownership Proof
    # ================================================================
    divider("AXIOM 8: WRITE OWNERSHIP")

    # Teacher tries to modify Maria's submission
    target_var = f"{classroom.world_id}.{maria_id}.sub.{a1}.content"
    tamper1 = helena.mary.write_to(teacher_id, maria_id, target_var, "TAMPERED")
    print(f"  Teacher → Maria's submission:  {'BLOCKED ✗' if not tamper1 else '!! ERROR !!'}")

    # Admin tries to modify teacher's assignment
    target_var2 = f"{classroom.world_id}.{teacher_id}.{a1}.max_points"
    tamper2 = helena.mary.write_to(admin_id, teacher_id, target_var2, 50)
    print(f"  Admin → Teacher's assignment:  {'BLOCKED ✗' if not tamper2 else '!! ERROR !!'}")

    # James tries to modify Maria's submission
    tamper3 = helena.mary.write_to(james_id, maria_id, target_var, "COPIED FROM JAMES")
    print(f"  James → Maria's submission:    {'BLOCKED ✗' if not tamper3 else '!! ERROR !!'}")

    # But READING is fine
    maria_work = helena.world_read(teacher_id, classroom.world_id, maria_id, f"sub.{a1}.content")
    print(f"  Teacher reads Maria's work:    ✓ ({len(maria_work)} chars)")

    # ================================================================
    # LAYER 7: Grading
    # ================================================================
    divider("GRADING")

    g1 = classroom.grade(maria_id, a1, 95, "Excellent. Clean code, handles edge cases.")
    print(f"  Maria  — {a1}: {g1['score']}/{g1['max']} (based on v{g1['submission_version']})")

    g2 = classroom.grade(james_id, a1, 45, "Incomplete. No functions, no error handling, no loop.")
    print(f"  James  — {a1}: {g2['score']}/{g2['max']} (based on v{g2['submission_version']})")

    g3 = classroom.grade(aisha_id, a1, 88, "Good improvement from v1 to v2. Minor eval() concern.")
    print(f"  Aisha  — {a1}: {g3['score']}/{g3['max']} (based on v{g3['submission_version']})")

    g4 = classroom.grade(maria_id, a2, 91, "Solid implementation. Search could be O(1) with hash.")
    print(f"  Maria  — {a2}: {g4['score']}/{g4['max']} (based on v{g4['submission_version']})")

    # Student tries to change their own grade — can they?
    grade_var = f"{classroom.world_id}.{teacher_id}.grade.{maria_id}.{a1}.score"
    tamper4 = helena.mary.write_to(maria_id, teacher_id, grade_var, 100)
    print(f"\n  Maria tries to change her grade: {'BLOCKED ✗' if not tamper4 else '!! ERROR !!'}")
    print(f"  Grades are teacher variables. Math prevents this.")

    # ================================================================
    # LAYER 8: Gradebook
    # ================================================================
    divider("GRADEBOOK")
    gradebook = classroom.gradebook()

    # Header
    assignments = classroom.list_assignments()
    header = f"  {'STUDENT':<15}"
    for a in assignments:
        header += f" {a['title'][:12]:>12}"
    header += f" {'TOTAL':>8}"
    print(header)
    print("  " + "─" * (len(header) - 2))

    for row in gradebook:
        line = f"  {row['student']:<15}"
        for a in assignments:
            g = row['grades'].get(a['id'], {})
            score = g.get('score', '—')
            mx = g.get('max', '')
            if isinstance(score, int):
                line += f" {score:>5}/{mx:<5}"
            else:
                line += f" {str(score):>12}"
        line += f" {row['percentage']:>6.1f}%"
        print(line)

    # ================================================================
    # LAYER 9: Grade Dispute
    # ================================================================
    divider("GRADE DISPUTE")

    # James disputes his grade
    dispute_id = classroom.dispute_grade(james_id, a1, "I think print(2+2) covers the basic requirement.")
    print(f"  James filed dispute: request #{dispute_id}")
    print(f"    Reason: 'I think print(2+2) covers the basic requirement.'")

    # Teacher sees it and refuses
    pending = helena.mary.pending_requests(teacher_id)
    print(f"  Teacher sees {len(pending)} pending request(s)")

    helena.mary.respond(teacher_id, dispute_id, accept=False,
                        response_data="Assignment requires functions, error handling, and a loop. print(2+2) is one line.")
    print(f"  Teacher refused dispute with explanation.")
    print(f"  Both the dispute and refusal are in the ledger. Permanently.")

    # ================================================================
    # LAYER 10: Admin Pressure
    # ================================================================
    divider("ADMIN PRESSURE SCENARIO")

    # Admin asks teacher to change James's grade
    admin_req = helena.mary.request(admin_id, teacher_id,
                                     f"change_grade:{james_id}:{a1}:to:70",
                                     data={"reason": "His parents called."})
    print(f"  Admin requested grade change for James: request #{admin_req.request_id}")
    print(f"    Reason: 'His parents called.'")

    # Teacher refuses
    helena.mary.respond(teacher_id, admin_req.request_id, accept=False,
                        response_data="Grade reflects demonstrated competency. Student submitted one line of code.")
    print(f"  Teacher refused: 'Grade reflects demonstrated competency.'")
    print()
    print(f"  ⚠  Both the admin's request and the teacher's refusal")
    print(f"     are in the ledger. Permanently. The pressure is documented.")
    print(f"     The teacher has a mathematical receipt of what happened.")

    # ================================================================
    # LAYER 11: Attendance
    # ================================================================
    divider("ATTENDANCE")

    session = classroom.open_session("Lecture 3: Trees and Graphs", duration_minutes=60)
    print(f"  Session opened: {session}")

    c1 = classroom.check_in(maria_id, session)
    print(f"  Maria checked in:  {c1['status']}")
    c2 = classroom.check_in(aisha_id, session)
    print(f"  Aisha checked in:  {c2['status']}")
    # James didn't check in
    print(f"  James:             (absent — no check-in expression)")

    # ================================================================
    # LAYER 12: Transcript
    # ================================================================
    divider("TRANSCRIPT")

    for sid, name in [(maria_id, "Maria"), (james_id, "James"), (aisha_id, "Aisha")]:
        t = classroom.transcript(sid)
        print(f"  {name}: {t['final_score']} ({t['percentage']}%) | "
              f"submitted: {t['assignments_submitted']} | "
              f"missed: {t['assignments_missed']} | "
              f"ledger: {t['ledger_hash']}")

    # ================================================================
    # LAYER 13: Plagiarism Evidence
    # ================================================================
    divider("PLAGIARISM CHECK (Version History)")

    print(f"  Maria — {a1}:")
    maria_sub = classroom.get_submission(teacher_id, maria_id, a1)
    print(f"    Version: {maria_sub['version']}, submitted at creation")
    print(f"    Content hash: {maria_sub['content_hash']}")
    print()

    print(f"  Aisha — {a1}:")
    aisha_sub = classroom.get_submission(teacher_id, aisha_id, a1)
    print(f"    Version: {aisha_sub['version']} (resubmitted — has v1 AND v2 in ledger)")
    print(f"    Content hash: {aisha_sub['content_hash']}")
    print(f"    → Process evidence: v1 was rough, v2 was improved. Organic work.")
    print()

    print(f"  James — {a1}:")
    james_sub = classroom.get_submission(teacher_id, james_id, a1)
    print(f"    Version: {james_sub['version']} (single submission, no process)")
    print(f"    Content hash: {james_sub['content_hash']}")
    print(f"    → If this matched another student's hash, the timestamps would tell the story.")

    # ================================================================
    # LAYER 14: Full Audit
    # ================================================================
    divider("AUDIT (last 25 entries)")

    entries = helena.audit(teacher_id, classroom.world_id)
    for e in entries[-25:]:
        status = e['status'] or "—"
        print(f"  #{e['entry_id']:>3} [{status:>8}] {e['speaker']:<16} {e['action']}")

    # ================================================================
    # LAYER 15: Final State
    # ================================================================
    divider("SYSTEM STATE")
    print(f"  {helena}")
    print(f"  Ledger entries:  {helena.mary.ledger_count(teacher_id)}")
    print(f"  Hash chain:      {'VALID ✓' if helena.mary.ledger_verify() else 'BROKEN ✗'}")
    print(f"  Speakers:        {len(helena.mary.list_speakers(teacher_id))}")
    print(f"  Worlds:          {len(helena.list_worlds(teacher_id))}")
    print()

    # Tamper check log
    violations = helena.mary.ledger_search(teacher_id, operation="write_violation")
    print(f"  Write violations caught: {len(violations)}")
    for v in violations:
        name = helena.get_speaker_name(v.speaker_id)
        print(f"    #{v.entry_id} {name}: {v.action} → {v.break_reason}")

    print()
    print("=" * 65)
    print("  Every student owns their work.")
    print("  Every grade has a receipt.")
    print("  Every action is in the ledger.")
    print("  Every tamper attempt was caught and recorded.")
    print()
    print("  The stack holds:")
    print("    Human Logic (10 axioms)  →  proven")
    print("    Mary (12 invariants)     →  enforced")
    print("    Helena (14 rules)        →  operational")
    print("    Classroom (12 rules)     →  running")
    print()
    print("  From birthday cake to a working system.")
    print("  — Jared Lewis, 2026")
    print("=" * 65)


if __name__ == "__main__":
    main()
