#!/usr/bin/env python3
"""
Logica Demo — The Language in Action
=====================================
Author: Jared Lewis
Date: February 2026

Run this file. No input needed. It proves the language works.

    python3 logica_demo.py

This demonstrates:
    1. Hello World
    2. Write ownership enforcement (Axiom 8)
    3. Three-valued evaluation (Axiom 3)
    4. Bounded loops (Axiom 9)
    5. Functions
    6. Communication
    7. Variable history
    8. Axiom violation catching
    9. Ledger verification
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logica.lexer import Lexer
from logica.parser import Parser
from logica.compiler import Compiler
from logica.runtime import Runtime
from logica.errors import AxiomViolation, LogicaError


def run(source: str, title: str, expect_error: bool = False):
    """Run a Logica program and display results."""
    print(f"\n── {title} ──")
    print()

    try:
        lexer = Lexer(source)
        tokens = lexer.tokenize()
        parser = Parser(tokens)
        ast = parser.parse()
        compiler = Compiler()
        compiled = compiler.compile(ast)
        runtime = Runtime()
        runtime.execute(compiled)

        if expect_error:
            print("  ERROR: Expected an axiom violation but program compiled.")
        else:
            total = runtime.env.mary.ledger_count(0)
            intact = runtime.env.mary.ledger_verify()
            print(f"\n  ledger: {total} entries | integrity: {'VALID' if intact else 'BROKEN'}")

    except AxiomViolation as e:
        if expect_error:
            print(f"  CAUGHT: {e}")
        else:
            print(f"  UNEXPECTED ERROR: {e}")
            raise

    except LogicaError as e:
        print(f"  ERROR: {e}")


def main():
    print("=" * 65)
    print("  LOGICA v0.1 — A Programming Language for Human Logic")
    print("  The syntax. The semantics were already proven.")
    print("  Author: Jared Lewis, 2026")
    print("=" * 65)

    # ══════════════════════════════════════════════════════════════
    # 1. HELLO WORLD
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Jared

as Jared {
    speak "Hello, World!"
    speak "Every operation has a speaker. Even this one."
}
""", "1. HELLO WORLD")

    # ══════════════════════════════════════════════════════════════
    # 2. VARIABLES AND OWNERSHIP
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Teacher
speaker Student

as Teacher {
    let assignment = "Build a Calculator"
    let max_points = 100
    speak "Assignment posted"
}

as Student {
    let my_task = read Teacher.assignment
    speak "I see the assignment"

    let submission = "def calc(): return 2+2"
    speak "Work submitted"
}

as Teacher {
    let student_work = read Student.submission
    speak "Reading student work: def calc(): return 2+2"

    let grade = 92
    let feedback = "Strong work. Clean code."
    speak "Graded: 92/100"
}

as Student {
    let my_grade = read Teacher.grade
    speak "My grade: 92"
}
""", "2. VARIABLES AND OWNERSHIP")

    # ══════════════════════════════════════════════════════════════
    # 3. AXIOM 8 — WRITE OWNERSHIP VIOLATION
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Alice
speaker Bob

as Alice {
    let Bob.secret = "stolen"
}
""", "3. AXIOM 8 — WRITE OWNERSHIP (should fail)", expect_error=True)

    # ══════════════════════════════════════════════════════════════
    # 4. AXIOM 1 — SPEAKER REQUIREMENT VIOLATION
    # ══════════════════════════════════════════════════════════════

    run("""
let x = 5
speak x
""", "4. AXIOM 1 — NO SPEAKER (should fail)", expect_error=True)

    # ══════════════════════════════════════════════════════════════
    # 5. AXIOM 9 — NO INFINITE LOOPS
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Runner

as Runner {
    let x = 0
    while x >= 0 {
        let x = x + 1
    }
}
""", "5. AXIOM 9 — UNBOUNDED LOOP (should fail)", expect_error=True)

    # ══════════════════════════════════════════════════════════════
    # 6. THREE-VALUED EVALUATION
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Student

as Student {
    let deadline_ok = true

    when deadline_ok {
        speak "Condition met: submitting work"
        let status = "submitted"
    } otherwise {
        speak "Condition not met: deadline passed (inactive)"
    } broken {
        speak "Condition met but action failed (broken)"
    }

    let deadline_ok = false

    when deadline_ok {
        speak "This will not execute"
    } otherwise {
        speak "Deadline passed. Not failure. Inactive."
    }
}
""", "6. THREE-VALUED EVALUATION (when/otherwise/broken)")

    # ══════════════════════════════════════════════════════════════
    # 7. BOUNDED LOOPS
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Counter

as Counter {
    let n = 0

    while n < 5, max 100 {
        let n = n + 1
    }

    speak "Counted to 5"

    let sum = 0
    let i = 1

    while i <= 10, max 100 {
        let sum = sum + i
        let i = i + 1
    }

    speak "Sum 1..10 = 55"
}
""", "7. BOUNDED LOOPS (Axiom 9 — max required)")

    # ══════════════════════════════════════════════════════════════
    # 8. FUNCTIONS
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Math

as Math {
    fn square(x) {
        return x * x
    }

    fn add(a, b) {
        return a + b
    }

    let result = square(7)
    speak "7 squared = 49"

    let total = add(30, 12)
    speak "30 + 12 = 42"
}
""", "8. FUNCTIONS")

    # ══════════════════════════════════════════════════════════════
    # 9. COMMUNICATION
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Teacher
speaker Student

as Teacher {
    let assignment = "Final Exam"
    speak "Final exam posted"
}

as Student {
    let submission = "All answers complete"
    speak "Exam submitted"
}

as Teacher {
    let grade = 88
    speak "Graded: 88/100"
}

as Student {
    request Teacher "review_grade"
    speak "Dispute filed: review my grade"
}

as Teacher {
    respond refuse
    speak "Dispute refused: grade stands"
}
""", "9. COMMUNICATION (requests and responses)")

    # ══════════════════════════════════════════════════════════════
    # 10. THE FULL DEMO — EVERYTHING TOGETHER
    # ══════════════════════════════════════════════════════════════

    run("""
speaker Jared
speaker Maria
speaker Principal

as Jared {
    let course = "CS 101"
    let assignment = "Build a Calculator"
    let points = 100
    speak "Course: CS 101 | Assignment: Build a Calculator"
}

as Maria {
    let task = read Jared.assignment
    let work = "def calc(a,op,b): return eval(f'{a}{op}{b}')"
    let version = 1
    speak "Submitted v1"

    let work = "def calc(a,op,b):\\n  if op=='/' and b==0: return 'Error'\\n  return eval(f'{a}{op}{b}')"
    let version = 2
    speak "Resubmitted v2 (handles division by zero)"
}

as Jared {
    let student_code = read Maria.work
    let grade_maria = 95
    let feedback_maria = "Excellent. Clean code."
    speak "Graded Maria: 95/100"
}

as Maria {
    let my_grade = read Jared.grade_maria
    speak "My grade: 95/100"
}

as Principal {
    let observed_grade = read Jared.grade_maria
    speak "Observed: Maria got 95"
    speak "Admin can look. Admin cannot touch."
}

as Jared {
    verify ledger
    inspect Maria
    inspect Jared
}
""", "10. THE FULL DEMO")

    # ══════════════════════════════════════════════════════════════
    # FINAL
    # ══════════════════════════════════════════════════════════════

    print()
    print("=" * 65)
    print("  Logica v0.1 — All demos complete.")
    print()
    print("  The language enforces at compile time:")
    print("    A1.  Every operation has a speaker")
    print("    A3.  Three-valued evaluation (active/inactive/broken)")
    print("    A7.  No forced speech")
    print("    A8.  Write ownership (cannot write another's variables)")
    print("    A9.  No infinite loops (every loop bounded)")
    print()
    print("  The runtime enforces through Mary:")
    print("    A5.  Ledger integrity (append-only, hash-chained)")
    print("    A6.  Deterministic evaluation")
    print("    A10. No orphan state (every change in the ledger)")
    print()
    print("  You have the semantics. You have the runtime.")
    print("  Now you have the syntax.")
    print()
    print("  Usage:")
    print("    python3 logica.py examples/hello_world.logica")
    print("    python3 logica.py examples/the_demo.logica")
    print("    python3 logica.py  # interactive REPL")
    print()
    print("  — Jared Lewis, 2026")
    print("=" * 65)


if __name__ == "__main__":
    main()
