"""
The Classroom World v1.0 — The First World on Helena
=====================================================
Author: Jared Lewis
Date: February 19, 2026

The first application built on Human Logic → Mary → Helena.
Every student owns their work. Every grade has a receipt.
Every action is in the ledger.

Run this file to get an interactive classroom shell.
"""

import time
import json
from typing import Optional
from helena import Helena, WorldPermissions, WorldStatus
from mary import Status


# =============================================================================
# Part I — Classroom
# =============================================================================

class Classroom:
    """
    A classroom world. Teacher, students, assignments, submissions, grades.
    
    CW1: Students own their submissions.
    CW2: Teachers own their grades.
    CW3: Administrators can observe. They cannot modify.
    CW4: Every submission has a receipt.
    CW5: Every grade links to a submission version.
    CW6: Every action is in the ledger.
    """

    def __init__(self, helena: Helena, teacher_id: int, course_name: str):
        self.helena = helena
        self.teacher_id = teacher_id
        self.course_name = course_name

        # Create the world
        self.world_id = helena.create_world(teacher_id, course_name)

        # Initialize course variables
        helena.world_write(teacher_id, self.world_id, "course.name", course_name)
        helena.world_write(teacher_id, self.world_id, "course.created_at", time.time())
        helena.world_write(teacher_id, self.world_id, "course.status", "active")
        helena.world_write(teacher_id, self.world_id, "assignments", json.dumps([]))
        helena.world_write(teacher_id, self.world_id, "sessions", json.dumps([]))

        # Track state locally for convenience
        self._assignments: dict[str, dict] = {}
        self._next_assignment: int = 1
        self._next_session: int = 1

    # ── Enrollment ────────────────────────────────────────────────────

    def enroll_student(self, student_id: int) -> bool:
        """Enroll a student. Teacher invites, student joins."""
        student_perms = WorldPermissions(
            read=True, write=True, submit=True,
            request=True, invite=False, configure=False,
        )
        result = self.helena.invite_to_world(
            self.teacher_id, student_id, self.world_id, student_perms
        )
        if result:
            self.helena.world_write(student_id, self.world_id, "role", "student")
        return result

    def add_admin(self, admin_id: int) -> bool:
        """Add an administrator. Read-only."""
        admin_perms = WorldPermissions(
            read=True, write=False, submit=False,
            request=True, invite=False, configure=False,
        )
        result = self.helena.invite_to_world(
            self.teacher_id, admin_id, self.world_id, admin_perms
        )
        if result:
            # Admin can't write to world, so teacher records their role
            self.helena.world_write(
                self.teacher_id, self.world_id,
                f"admin.{admin_id}.role", "observer"
            )
        return result

    def get_students(self) -> list[dict]:
        """List enrolled students."""
        world = self.helena.get_world(self.world_id)
        if not world:
            return []
        students = []
        for sid, member in world.members.items():
            if sid == self.teacher_id or sid == self.helena.speaker.id:
                continue
            role = self.helena.world_read(
                self.teacher_id, self.world_id, sid, "role"
            )
            if role == "student":
                students.append({
                    "id": sid,
                    "name": self.helena.get_speaker_name(sid),
                })
        return students

    # ── Assignments ───────────────────────────────────────────────────

    def create_assignment(self, title: str, description: str,
                          max_points: int = 100,
                          due_in_hours: float = 168,  # 1 week default
                          allow_late: bool = False,
                          allow_resubmit: bool = True) -> str:
        """Create an assignment. Teacher expression."""
        aid = f"assignment_{self._next_assignment}"
        self._next_assignment += 1

        now = time.time()
        due_at = now + (due_in_hours * 3600)

        assignment = {
            "id": aid,
            "title": title,
            "description": description,
            "max_points": max_points,
            "created_at": now,
            "due_at": due_at,
            "allow_late": allow_late,
            "allow_resubmit": allow_resubmit,
        }

        self._assignments[aid] = assignment

        # Write to teacher's partition in the world
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.title", title)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.description", description)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.max_points", max_points)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.due_at", due_at)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.allow_late", allow_late)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.allow_resubmit", allow_resubmit)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.status", "published")

        # Expression: teacher publishes assignment
        self.helena.mary.submit(
            speaker_id=self.teacher_id,
            condition_label="class_active",
            action=f"publish:{aid}:{title}",
            action_fn=lambda: True,
        )

        # Update assignments list
        aid_list = list(self._assignments.keys())
        self.helena.world_write(self.teacher_id, self.world_id,
                                "assignments", json.dumps(aid_list))

        return aid

    def get_assignment(self, aid: str) -> Optional[dict]:
        """Get assignment details."""
        return self._assignments.get(aid)

    def list_assignments(self) -> list[dict]:
        """List all assignments."""
        return list(self._assignments.values())

    def update_assignment(self, aid: str, field: str, value) -> bool:
        """Update an assignment field. Old value preserved in ledger."""
        if aid not in self._assignments:
            return False

        old_value = self._assignments[aid].get(field)
        self._assignments[aid][field] = value

        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{aid}.{field}", value)

        self.helena.mary.submit(
            speaker_id=self.teacher_id,
            condition_label="⊤",
            action=f"update:{aid}.{field}",
            action_fn=lambda: True,
        )

        return True

    # ── Submissions ───────────────────────────────────────────────────

    def submit_work(self, student_id: int, aid: str, content: str) -> dict:
        """
        Student submits work. Returns receipt.
        
        The submission is the STUDENT'S variable.
        The teacher CANNOT modify it. Mary enforces this.
        """
        assignment = self._assignments.get(aid)
        if not assignment:
            return {"status": "error", "reason": "assignment_not_found"}

        now = time.time()
        is_late = now > assignment["due_at"]

        if is_late and not assignment["allow_late"]:
            # Expression is broken — deadline passed, no late allowed
            self.helena.mary.submit(
                speaker_id=student_id,
                condition=lambda: False,  # deadline passed
                condition_label=f"deadline >= now for {aid}",
                action=f"submit:{aid}",
            )
            return {"status": "broken", "reason": "deadline_passed"}

        # Check for resubmission
        existing = self.helena.world_read(
            student_id, self.world_id, student_id, f"sub.{aid}.content"
        )
        if existing and not assignment["allow_resubmit"]:
            return {"status": "error", "reason": "resubmission_not_allowed"}

        version = 1
        existing_version = self.helena.world_read(
            student_id, self.world_id, student_id, f"sub.{aid}.version"
        )
        if existing_version:
            version = existing_version + 1

        # Write to STUDENT'S partition
        content_hash = self.helena.hash_content(content)
        self.helena.world_write(student_id, self.world_id,
                                f"sub.{aid}.content", content)
        self.helena.world_write(student_id, self.world_id,
                                f"sub.{aid}.submitted_at", now)
        self.helena.world_write(student_id, self.world_id,
                                f"sub.{aid}.version", version)
        self.helena.world_write(student_id, self.world_id,
                                f"sub.{aid}.content_hash", content_hash)
        self.helena.world_write(student_id, self.world_id,
                                f"sub.{aid}.late", is_late)
        self.helena.world_write(student_id, self.world_id,
                                f"sub.{aid}.status", "submitted")

        # Expression: student submits
        status_label = "active"
        self.helena.mary.submit(
            speaker_id=student_id,
            condition=lambda: True,
            condition_label=f"deadline >= now for {aid}" if not is_late else f"late_submit:{aid}",
            action=f"submit:{aid}:v{version}",
            action_fn=lambda: True,
        )

        receipt = {
            "status": "active",
            "student_id": student_id,
            "assignment_id": aid,
            "version": version,
            "content_hash": content_hash,
            "submitted_at": now,
            "late": is_late,
            "ledger_entry": self.helena.mary.ledger.count() - 1,
        }

        return receipt

    def get_submission(self, caller_id: int, student_id: int, aid: str) -> Optional[dict]:
        """Get a student's submission. Anyone with read access can view."""
        content = self.helena.world_read(caller_id, self.world_id,
                                         student_id, f"sub.{aid}.content")
        if content is None:
            return None

        return {
            "student_id": student_id,
            "student_name": self.helena.get_speaker_name(student_id),
            "assignment_id": aid,
            "content": content,
            "version": self.helena.world_read(
                caller_id, self.world_id, student_id, f"sub.{aid}.version"),
            "submitted_at": self.helena.world_read(
                caller_id, self.world_id, student_id, f"sub.{aid}.submitted_at"),
            "content_hash": self.helena.world_read(
                caller_id, self.world_id, student_id, f"sub.{aid}.content_hash"),
            "late": self.helena.world_read(
                caller_id, self.world_id, student_id, f"sub.{aid}.late"),
        }

    def get_all_submissions(self, aid: str) -> list[dict]:
        """Get all submissions for an assignment (teacher view)."""
        submissions = []
        for student in self.get_students():
            sub = self.get_submission(self.teacher_id, student["id"], aid)
            if sub:
                submissions.append(sub)
        return submissions

    # ── Grading ───────────────────────────────────────────────────────

    def grade(self, student_id: int, aid: str, score: int,
              feedback: str = "") -> dict:
        """
        Teacher grades a submission. Grade is TEACHER'S variable.
        Student CANNOT modify it. Mary enforces this.
        """
        # Check submission exists
        sub = self.get_submission(self.teacher_id, student_id, aid)
        if not sub:
            return {"status": "error", "reason": "no_submission_found"}

        assignment = self._assignments.get(aid)
        if not assignment:
            return {"status": "error", "reason": "assignment_not_found"}

        # Write to TEACHER'S partition
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"grade.{student_id}.{aid}.score", score)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"grade.{student_id}.{aid}.max", assignment["max_points"])
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"grade.{student_id}.{aid}.feedback", feedback)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"grade.{student_id}.{aid}.graded_at", time.time())
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"grade.{student_id}.{aid}.submission_version", sub["version"])
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"grade.{student_id}.{aid}.submission_hash", sub["content_hash"])

        # Expression: teacher grades
        self.helena.mary.submit(
            speaker_id=self.teacher_id,
            condition=lambda: True,
            condition_label=f"student.{student_id}.submission.{aid} = active",
            action=f"grade:{student_id}:{aid}:{score}/{assignment['max_points']}",
            action_fn=lambda: True,
        )

        return {
            "status": "active",
            "student_id": student_id,
            "assignment_id": aid,
            "score": score,
            "max": assignment["max_points"],
            "feedback": feedback,
            "submission_version": sub["version"],
        }

    def get_grade(self, caller_id: int, student_id: int, aid: str) -> Optional[dict]:
        """Get a grade. Students can read their own grades."""
        score = self.helena.world_read(caller_id, self.world_id,
                                       self.teacher_id, f"grade.{student_id}.{aid}.score")
        if score is None:
            return None

        return {
            "student_id": student_id,
            "assignment_id": aid,
            "score": score,
            "max": self.helena.world_read(
                caller_id, self.world_id, self.teacher_id,
                f"grade.{student_id}.{aid}.max"),
            "feedback": self.helena.world_read(
                caller_id, self.world_id, self.teacher_id,
                f"grade.{student_id}.{aid}.feedback"),
            "submission_version": self.helena.world_read(
                caller_id, self.world_id, self.teacher_id,
                f"grade.{student_id}.{aid}.submission_version"),
        }

    # ── Gradebook ─────────────────────────────────────────────────────

    def gradebook(self) -> list[dict]:
        """
        Computed view. Reads existing state. Computes nothing new.
        """
        rows = []
        students = self.get_students()
        assignments = self.list_assignments()

        for student in students:
            row = {
                "student": student["name"],
                "student_id": student["id"],
                "grades": {},
            }
            total_score = 0
            total_max = 0

            for assignment in assignments:
                aid = assignment["id"]
                grade = self.get_grade(self.teacher_id, student["id"], aid)
                sub = self.get_submission(self.teacher_id, student["id"], aid)

                if grade:
                    row["grades"][aid] = {
                        "score": grade["score"],
                        "max": grade["max"],
                        "submitted": True,
                    }
                    total_score += grade["score"]
                    total_max += grade["max"]
                elif sub:
                    row["grades"][aid] = {
                        "score": "pending",
                        "max": assignment["max_points"],
                        "submitted": True,
                    }
                else:
                    row["grades"][aid] = {
                        "score": "—",
                        "max": assignment["max_points"],
                        "submitted": False,
                    }

            row["total"] = f"{total_score}/{total_max}" if total_max > 0 else "—"
            row["percentage"] = round(total_score / total_max * 100, 1) if total_max > 0 else 0
            rows.append(row)

        return rows

    # ── Attendance ────────────────────────────────────────────────────

    def open_session(self, title: str = "", duration_minutes: int = 60) -> str:
        """Teacher opens a class session."""
        sid = f"session_{self._next_session}"
        self._next_session += 1

        now = time.time()
        end = now + (duration_minutes * 60)

        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{sid}.title", title or f"Session {self._next_session - 1}")
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{sid}.start", now)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{sid}.end", end)
        self.helena.world_write(self.teacher_id, self.world_id,
                                f"{sid}.status", "open")

        self.helena.mary.submit(
            speaker_id=self.teacher_id,
            condition_label="⊤",
            action=f"open_session:{sid}",
            action_fn=lambda: True,
        )

        return sid

    def check_in(self, student_id: int, session_id: str) -> dict:
        """Student checks in to a session."""
        now = time.time()
        end_time = self.helena.world_read(
            student_id, self.world_id, self.teacher_id, f"{session_id}.end"
        )

        if end_time and now > end_time:
            return {"status": "broken", "reason": "session_ended"}

        self.helena.world_write(student_id, self.world_id,
                                f"checkin.{session_id}", now)

        self.helena.mary.submit(
            speaker_id=student_id,
            condition=lambda: True,
            condition_label=f"session.{session_id}.active",
            action=f"check_in:{session_id}",
            action_fn=lambda: True,
        )

        return {"status": "active", "checked_in_at": now}

    # ── Dispute ───────────────────────────────────────────────────────

    def dispute_grade(self, student_id: int, aid: str, reason: str) -> Optional[int]:
        """Student disputes a grade. Returns request_id."""
        return self.helena.world_request(
            student_id, self.teacher_id, self.world_id,
            f"review_grade:{aid}",
            data={"reason": reason},
        )

    # ── Archival ──────────────────────────────────────────────────────

    def archive(self) -> bool:
        """Archive the classroom. Read-only from here on."""
        return self.helena.archive_world(self.teacher_id, self.world_id)

    # ── Transcript ────────────────────────────────────────────────────

    def transcript(self, student_id: int) -> dict:
        """Generate transcript record for a student."""
        grades = {}
        total_score = 0
        total_max = 0
        submitted = 0
        missed = 0

        for aid, assignment in self._assignments.items():
            grade = self.get_grade(self.teacher_id, student_id, aid)
            sub = self.get_submission(self.teacher_id, student_id, aid)

            if grade:
                grades[aid] = {"score": grade["score"], "max": grade["max"]}
                total_score += grade["score"]
                total_max += grade["max"]
            if sub:
                submitted += 1
            else:
                missed += 1

        return {
            "student_id": student_id,
            "student_name": self.helena.get_speaker_name(student_id),
            "course": self.course_name,
            "teacher": self.helena.get_speaker_name(self.teacher_id),
            "grades": grades,
            "final_score": f"{total_score}/{total_max}",
            "percentage": round(total_score / total_max * 100, 1) if total_max > 0 else 0,
            "assignments_submitted": submitted,
            "assignments_missed": missed,
            "ledger_hash": self.helena.mary.ledger.last().entry_hash if self.helena.mary.ledger.last() else "",
        }


# =============================================================================
# Part II — Interactive Shell
# =============================================================================

class ClassroomShell:
    """
    Interactive shell for the Classroom World.
    
    Be the teacher. Create assignments. Enroll students. Grade work.
    Watch the ledger track everything.
    """

    def __init__(self):
        self.helena = Helena()
        self.classroom = None
        self.teacher_id = None
        self.current_speaker = None  # for switching between teacher/student
        self._students: dict[str, int] = {}  # name -> id
        self._admin_id = None

    def start(self):
        """Boot the shell."""
        print()
        print("=" * 60)
        print("  The Classroom World v1.0")
        print("  Built on Human Logic → Mary → Helena")
        print("  Author: Jared Lewis, 2026")
        print("=" * 60)
        print()
        print("  Every student owns their work.")
        print("  Every grade has a receipt.")
        print("  Every action is in the ledger.")
        print()
        print("=" * 60)
        print()

        # Setup
        teacher_name = input("  Teacher name: ").strip() or "Jared"
        course_name = input("  Course name: ").strip() or "CS 101"
        print()

        # Create teacher speaker
        self.teacher_id = self.helena.create_speaker(teacher_name)
        self.current_speaker = self.teacher_id

        # Create classroom
        self.classroom = Classroom(self.helena, self.teacher_id, course_name)
        print(f"  ✓ Classroom created: {course_name}")
        print(f"  ✓ Teacher: {teacher_name} (speaker #{self.teacher_id})")
        print()

        # Main loop
        self.print_help()
        while True:
            try:
                who = self.helena.get_speaker_name(self.current_speaker)
                prompt = f"  [{who}] > "
                cmd = input(prompt).strip()
                if not cmd:
                    continue
                if cmd.lower() in ("quit", "exit", "q"):
                    self.do_quit()
                    break
                self.dispatch(cmd)
            except (EOFError, KeyboardInterrupt):
                print()
                self.do_quit()
                break

    def dispatch(self, cmd: str):
        """Route a command."""
        parts = cmd.split(None, 1)
        verb = parts[0].lower()
        args = parts[1] if len(parts) > 1 else ""

        commands = {
            "help": lambda: self.print_help(),
            "enroll": lambda: self.do_enroll(args),
            "students": lambda: self.do_students(),
            "assign": lambda: self.do_assign(args),
            "assignments": lambda: self.do_assignments(),
            "be": lambda: self.do_switch(args),
            "submit": lambda: self.do_submit(args),
            "submissions": lambda: self.do_submissions(args),
            "grade": lambda: self.do_grade(args),
            "grades": lambda: self.do_grades(args),
            "gradebook": lambda: self.do_gradebook(),
            "dispute": lambda: self.do_dispute(args),
            "session": lambda: self.do_session(args),
            "checkin": lambda: self.do_checkin(args),
            "inspect": lambda: self.do_inspect(args),
            "audit": lambda: self.do_audit(),
            "ledger": lambda: self.do_ledger(),
            "transcript": lambda: self.do_transcript(args),
            "archive": lambda: self.do_archive(),
            "status": lambda: self.do_status(),
            "tamper": lambda: self.do_tamper(args),
            "admin": lambda: self.do_admin(args),
        }

        fn = commands.get(verb)
        if fn:
            fn()
        else:
            print(f"    Unknown command: {verb}. Type 'help' for commands.")

    # ── Commands ──────────────────────────────────────────────────────

    def print_help(self):
        print("  COMMANDS:")
        print("  ─────────────────────────────────────────────")
        print("  SETUP:")
        print("    enroll <name>         — Add a student")
        print("    admin <name>          — Add an admin (read-only)")
        print("    students              — List students")
        print("    be <name>             — Switch speaker (be a student)")
        print("    be teacher            — Switch back to teacher")
        print()
        print("  ASSIGNMENTS:")
        print("    assign <title>        — Create an assignment")
        print("    assignments           — List all assignments")
        print()
        print("  STUDENT ACTIONS (switch to student first with 'be'):")
        print("    submit <assignment_id> — Submit work")
        print("    checkin <session_id>   — Check in to session")
        print("    dispute <assignment_id> — Dispute a grade")
        print()
        print("  TEACHER ACTIONS:")
        print("    submissions <a_id>    — View submissions for assignment")
        print("    grade <student> <a_id> <score> — Grade a submission")
        print("    grades <student>      — View student's grades")
        print("    gradebook             — Full gradebook")
        print("    session <title>       — Open a class session")
        print("    transcript <student>  — Generate transcript")
        print("    archive               — Archive the classroom")
        print()
        print("  INSPECTION:")
        print("    inspect <target>      — Inspect speaker or variable")
        print("    audit                 — Full world audit")
        print("    ledger                — View recent ledger entries")
        print("    status                — System status")
        print()
        print("  DEMO:")
        print("    tamper <student>      — Try to modify student work (will fail)")
        print()
        print("    quit                  — Exit")
        print()

    def do_enroll(self, name: str):
        if not name:
            name = input("    Student name: ").strip()
        if not name:
            return
        sid = self.helena.create_speaker(name)
        self.classroom.enroll_student(sid)
        self._students[name.lower()] = sid
        print(f"    ✓ Enrolled: {name} (speaker #{sid})")

    def do_students(self):
        students = self.classroom.get_students()
        if not students:
            print("    No students enrolled yet.")
            return
        print("    ENROLLED STUDENTS:")
        for s in students:
            print(f"      #{s['id']}  {s['name']}")

    def do_switch(self, name: str):
        if not name:
            name = input("    Switch to: ").strip()
        if name.lower() == "teacher":
            self.current_speaker = self.teacher_id
            print(f"    ✓ Now speaking as: {self.helena.get_speaker_name(self.teacher_id)} (teacher)")
            return
        if name.lower() == "admin" and self._admin_id:
            self.current_speaker = self._admin_id
            print(f"    ✓ Now speaking as: admin (read-only)")
            return
        sid = self._students.get(name.lower())
        if sid:
            self.current_speaker = sid
            print(f"    ✓ Now speaking as: {name} (student)")
        else:
            print(f"    Unknown speaker: {name}")

    def do_assign(self, title: str):
        if self.current_speaker != self.teacher_id:
            print("    ✗ Only the teacher can create assignments.")
            return
        if not title:
            title = input("    Assignment title: ").strip()

        # Parse optional points from title: "Build a Calculator 100"
        parts = title.rsplit(None, 1)
        points = 100
        if len(parts) == 2:
            try:
                points = int(parts[1])
                title = parts[0]
            except ValueError:
                pass

        desc = "Complete the assignment."
        aid = self.classroom.create_assignment(title, desc, max_points=points)
        print(f"    ✓ Assignment created: {aid} — {title} ({points} pts)")

    def do_assignments(self):
        assignments = self.classroom.list_assignments()
        if not assignments:
            print("    No assignments yet.")
            return
        print("    ASSIGNMENTS:")
        for a in assignments:
            print(f"      {a['id']}  {a['title']}  ({a['max_points']} pts)")

    def do_submit(self, args: str):
        if self.current_speaker == self.teacher_id:
            print("    ✗ Teachers don't submit. Switch to a student with 'be <name>'.")
            return
        if not args:
            args = input("    Assignment ID: ").strip()

        aid = args.strip()
        print(f"    Submitting to {aid}. Enter your work (one line):")
        content = input("    > ").strip()
        if not content:
            content = "# Student work goes here"

        receipt = self.classroom.submit_work(self.current_speaker, aid, content)

        if receipt["status"] == "active":
            print(f"    ✓ SUBMITTED")
            print(f"      Assignment: {aid}")
            print(f"      Version: {receipt['version']}")
            print(f"      Hash: {receipt['content_hash']}")
            print(f"      Late: {'Yes' if receipt['late'] else 'No'}")
            print(f"      Ledger entry: #{receipt['ledger_entry']}")
            print(f"      ← This is your receipt. Keep it.")
        else:
            print(f"    ✗ {receipt['status']}: {receipt.get('reason', '')}")

    def do_submissions(self, args: str):
        if not args:
            args = input("    Assignment ID: ").strip()
        aid = args.strip()
        subs = self.classroom.get_all_submissions(aid)
        if not subs:
            print(f"    No submissions for {aid}.")
            return
        print(f"    SUBMISSIONS FOR {aid}:")
        for s in subs:
            late = " [LATE]" if s.get("late") else ""
            print(f"      {s['student_name']} (v{s['version']}){late}: {s['content'][:50]}...")

    def do_grade(self, args: str):
        if self.current_speaker != self.teacher_id:
            print("    ✗ Only the teacher can grade.")
            return

        parts = args.split() if args else []
        if len(parts) < 3:
            student_name = input("    Student name: ").strip()
            aid = input("    Assignment ID: ").strip()
            score_str = input("    Score: ").strip()
        else:
            student_name = parts[0]
            aid = parts[1]
            score_str = parts[2]

        sid = self._students.get(student_name.lower())
        if not sid:
            print(f"    ✗ Unknown student: {student_name}")
            return

        try:
            score = int(score_str)
        except ValueError:
            print(f"    ✗ Invalid score: {score_str}")
            return

        feedback = input("    Feedback: ").strip() or ""
        result = self.classroom.grade(sid, aid, score, feedback)

        if result["status"] == "active":
            print(f"    ✓ GRADED")
            print(f"      Student: {self.helena.get_speaker_name(sid)}")
            print(f"      Assignment: {aid}")
            print(f"      Score: {score}/{result['max']}")
            print(f"      Based on submission v{result['submission_version']}")
        else:
            print(f"    ✗ {result['status']}: {result.get('reason', '')}")

    def do_grades(self, args: str):
        if not args:
            args = input("    Student name: ").strip()
        name = args.strip().lower()
        sid = self._students.get(name)
        if not sid:
            print(f"    ✗ Unknown student: {args}")
            return

        print(f"    GRADES FOR {self.helena.get_speaker_name(sid)}:")
        for aid in self.classroom._assignments:
            grade = self.classroom.get_grade(self.current_speaker, sid, aid)
            if grade:
                print(f"      {aid}: {grade['score']}/{grade['max']}  {grade.get('feedback', '')}")
            else:
                sub = self.classroom.get_submission(self.current_speaker, sid, aid)
                if sub:
                    print(f"      {aid}: submitted (not yet graded)")
                else:
                    print(f"      {aid}: — (no submission)")

    def do_gradebook(self):
        rows = self.classroom.gradebook()
        if not rows:
            print("    Gradebook is empty.")
            return

        assignments = self.classroom.list_assignments()
        header = "    STUDENT          "
        for a in assignments:
            header += f"  {a['id'][-4:]}"
        header += "  TOTAL"
        print(header)
        print("    " + "─" * (len(header) - 4))

        for row in rows:
            line = f"    {row['student']:<20}"
            for a in assignments:
                aid = a['id']
                g = row['grades'].get(aid, {})
                score = g.get('score', '—')
                line += f"  {str(score):>4}"
            line += f"  {row['percentage']}%"
            print(line)

    def do_dispute(self, args: str):
        if self.current_speaker == self.teacher_id:
            print("    ✗ Teachers don't dispute their own grades.")
            return
        if not args:
            args = input("    Assignment ID: ").strip()
        reason = input("    Reason for dispute: ").strip() or "I believe I deserve a higher grade."

        req_id = self.classroom.dispute_grade(self.current_speaker, args.strip(), reason)
        if req_id is not None:
            print(f"    ✓ Dispute filed: request #{req_id}")
            print(f"      Reason: {reason}")
            print(f"      ← This is in the ledger. The teacher must respond.")
        else:
            print("    ✗ Could not file dispute.")

    def do_session(self, args: str):
        if self.current_speaker != self.teacher_id:
            print("    ✗ Only the teacher can open sessions.")
            return
        title = args.strip() or input("    Session title: ").strip() or "Class"
        sid = self.classroom.open_session(title)
        print(f"    ✓ Session opened: {sid} — {title}")

    def do_checkin(self, args: str):
        if self.current_speaker == self.teacher_id:
            print("    ✗ Switch to a student first with 'be <name>'.")
            return
        if not args:
            args = input("    Session ID: ").strip()
        result = self.classroom.check_in(self.current_speaker, args.strip())
        if result["status"] == "active":
            print(f"    ✓ Checked in to {args.strip()}")
        else:
            print(f"    ✗ {result['status']}: {result.get('reason', '')}")

    def do_inspect(self, args: str):
        if not args:
            args = input("    Inspect what? (speaker name or 'world'): ").strip()
        if args.lower() == "world":
            info = self.helena.inspect_world(self.current_speaker, self.classroom.world_id)
            if info:
                print(f"    WORLD: {info['name']}")
                print(f"    Status: {info['status']}")
                print(f"    Creator: {info['creator']}")
                print(f"    Members:")
                for m in info['members']:
                    print(f"      #{m['id']} {m['name']} ({m['role']})")
        else:
            sid = self._students.get(args.lower())
            if not sid:
                if args.lower() == "teacher":
                    sid = self.teacher_id
                else:
                    print(f"    Unknown target: {args}")
                    return
            info = self.helena.mary.inspect_speaker(self.current_speaker, sid)
            if info:
                print(f"    SPEAKER: {info['speaker']['name']} (#{info['speaker']['id']})")
                print(f"    Status: {info['speaker']['status']}")
                print(f"    Variables: {len(info['variables'])}")
                print(f"    Expressions: {len(info['expressions'])}")
                for e in info['expressions'][-5:]:
                    print(f"      expr#{e['id']}: {e['action']} → {e['status']}")

    def do_audit(self):
        entries = self.helena.audit(self.current_speaker, self.classroom.world_id)
        if not entries:
            print("    No audit entries.")
            return
        print(f"    AUDIT LOG ({len(entries)} entries):")
        for e in entries[-20:]:  # last 20
            status = e['status'] or "—"
            print(f"      #{e['entry_id']} [{status:>8}] {e['speaker']}: {e['action']}")

    def do_ledger(self):
        count = self.helena.mary.ledger_count(self.current_speaker)
        entries = self.helena.mary.ledger_read(self.current_speaker,
                                                max(0, count - 15), count)
        integrity = self.helena.mary.ledger_verify()
        print(f"    LEDGER (last 15 of {count} entries) — Integrity: {'VALID ✓' if integrity else 'BROKEN ✗'}")
        for e in entries:
            status = e.status.value if e.status else "—"
            speaker = self.helena.get_speaker_name(e.speaker_id)
            print(f"      #{e.entry_id} [{status:>8}] {speaker}: {e.action}")

    def do_transcript(self, args: str):
        if not args:
            args = input("    Student name: ").strip()
        sid = self._students.get(args.strip().lower())
        if not sid:
            print(f"    ✗ Unknown student: {args}")
            return

        t = self.classroom.transcript(sid)
        print()
        print("    ╔══════════════════════════════════════════════╗")
        print(f"    ║  TRANSCRIPT                                  ║")
        print("    ╠══════════════════════════════════════════════╣")
        print(f"    ║  Student: {t['student_name']:<35} ║")
        print(f"    ║  Course:  {t['course']:<35} ║")
        print(f"    ║  Teacher: {t['teacher']:<35} ║")
        print(f"    ║  Final:   {t['final_score']} ({t['percentage']}%){' ' * (26 - len(str(t['final_score'])) - len(str(t['percentage'])))}║")
        print(f"    ║  Submitted: {t['assignments_submitted']:<33} ║")
        print(f"    ║  Missed:    {t['assignments_missed']:<33} ║")
        print(f"    ║  Ledger:    {t['ledger_hash']:<33} ║")
        print("    ╚══════════════════════════════════════════════╝")
        print()

    def do_archive(self):
        if self.current_speaker != self.teacher_id:
            print("    ✗ Only the teacher can archive.")
            return
        confirm = input("    Archive classroom? This is permanent. (y/n): ").strip()
        if confirm.lower() == "y":
            self.classroom.archive()
            print("    ✓ Classroom archived. Read-only from here on.")

    def do_status(self):
        print(f"    {self.helena}")
        print(f"    Current speaker: {self.helena.get_speaker_name(self.current_speaker)}")
        print(f"    Ledger integrity: {'VALID ✓' if self.helena.mary.ledger_verify() else 'BROKEN ✗'}")
        print(f"    Ledger entries: {self.helena.mary.ledger_count(self.current_speaker)}")

    def do_tamper(self, args: str):
        """
        DEMO: Try to modify a student's submission as the teacher.
        This MUST fail. That's the whole point.
        """
        if not args:
            args = input("    Student name to tamper with: ").strip()
        sid = self._students.get(args.strip().lower())
        if not sid:
            print(f"    ✗ Unknown student: {args}")
            return

        print()
        print("    ⚠  TAMPER ATTEMPT ⚠")
        print(f"    Attempting to modify {self.helena.get_speaker_name(sid)}'s submission as teacher...")
        print()

        # Try to write to student's partition
        target_var = f"{self.classroom.world_id}.{sid}.sub.assignment_1.content"
        result = self.helena.mary.write_to(
            self.teacher_id, sid, target_var, "TAMPERED BY TEACHER"
        )

        if not result:
            print("    ✗ BLOCKED by Mary (Axiom 8: Write Ownership)")
            print("    The teacher cannot modify student work.")
            print("    This isn't a permission setting. It's math.")
            print()

            # Show the ledger caught it
            entries = self.helena.mary.ledger_search(
                self.teacher_id, operation="write_violation"
            )
            if entries:
                e = entries[-1]
                print(f"    Ledger entry #{e.entry_id}: write_violation")
                print(f"    Speaker: {self.helena.get_speaker_name(e.speaker_id)}")
                print(f"    Action: {e.action}")
                print(f"    Status: {e.status.value}")
                print(f"    Reason: {e.break_reason}")
                print()
                print("    The attempt was recorded. Permanently.")
        else:
            print("    ERROR: This should never happen. Mary is broken.")

    def do_admin(self, args: str):
        """Add a read-only administrator."""
        if not args:
            args = input("    Admin name: ").strip()
        if not args:
            return
        aid = self.helena.create_speaker(args)
        self.classroom.add_admin(aid)
        self._admin_id = aid
        print(f"    ✓ Admin added: {args} (speaker #{aid}) — READ-ONLY")
        print("    They can look. They cannot touch.")

    def do_quit(self):
        count = self.helena.mary.ledger_count(self.teacher_id)
        integrity = self.helena.mary.ledger_verify()
        print()
        print("  ═══════════════════════════════════════════════")
        print(f"  Session complete.")
        print(f"  Ledger entries: {count}")
        print(f"  Hash chain: {'VALID ✓' if integrity else 'BROKEN ✗'}")
        print(f"  Every operation had a speaker.")
        print(f"  Every state change has a receipt.")
        print(f"  Human Logic holds.")
        print("  ═══════════════════════════════════════════════")
        print()


# =============================================================================
# Part III — Run It
# =============================================================================

if __name__ == "__main__":
    shell = ClassroomShell()
    shell.start()
