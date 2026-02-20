#!/usr/bin/env python3
"""
Logica — A Programming Language for Human Logic
================================================
Author: Jared Lewis
Date: February 2026

Usage:
    python3 logica.py <file.logica>       Run a Logica program
    python3 logica.py                     Start the REPL
    python3 logica.py --check <file>      Check axioms without running
    python3 logica.py --tokens <file>     Show tokenization
    python3 logica.py --ast <file>        Show parsed AST
    python3 logica.py --js <file> [out]   Transpile to JavaScript
    python3 logica.py --c <file> [out]    Transpile to C
    python3 logica.py --wasm <file> [out] Compile to WebAssembly

The language where an entire class of bugs — unauthorized access,
data tampering, ownership violations — cannot exist.
Not "are caught at runtime." Cannot be expressed.
"""

import sys
import os

# Ensure imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logica.lexer import Lexer
from logica.parser import Parser
from logica.compiler import Compiler
from logica.runtime import Runtime
from logica.errors import LogicaError, AxiomViolation


def run_source(source: str, filename: str = "<stdin>", quiet: bool = False):
    """Run Logica source code through the full pipeline."""
    # Phase 1: Lex
    lexer = Lexer(source)
    tokens = lexer.tokenize()

    # Phase 2: Parse
    parser = Parser(tokens)
    ast = parser.parse()

    # Phase 3: Compile (axiom checking)
    compiler = Compiler()
    compiled = compiler.compile(ast)

    # Phase 4: Execute through Mary
    runtime = Runtime(quiet=quiet)
    runtime.execute(compiled)

    return runtime


def run_file(filepath: str):
    """Run a .logica file."""
    if not os.path.exists(filepath):
        print(f"Error: file not found: {filepath}")
        sys.exit(1)

    with open(filepath, 'r') as f:
        source = f.read()

    print()
    print("=" * 60)
    print(f"  Logica v0.1 — running: {os.path.basename(filepath)}")
    print("=" * 60)
    print()

    try:
        runtime = run_source(source, filepath)
        print()
        print("  ---")
        total = runtime.env.mary.ledger_count(0)
        intact = runtime.env.mary.ledger_verify()
        print(f"  ledger: {total} entries, integrity: {'VALID' if intact else 'BROKEN'}")
        print(f"  speakers: {list(runtime.env.speaker_ids.keys())}")
        print("  ---")
    except AxiomViolation as e:
        print()
        print(f"  COMPILE ERROR")
        print(f"  {e}")
        print()
        print(f"  The program violates a Human Logic axiom.")
        print(f"  It cannot be expressed. This is not a bug — it is math.")
        sys.exit(1)
    except LogicaError as e:
        print()
        print(f"  ERROR: {e}")
        sys.exit(1)

    print()


def check_file(filepath: str):
    """Check axioms without running."""
    with open(filepath, 'r') as f:
        source = f.read()

    try:
        lexer = Lexer(source)
        tokens = lexer.tokenize()
        parser = Parser(tokens)
        ast = parser.parse()
        compiler = Compiler()
        compiled = compiler.compile(ast)

        print(f"  {os.path.basename(filepath)}: ALL AXIOMS HOLD")
        print(f"  speakers: {compiled.speakers}")
        print(f"  operations: {len(compiled.operations)}")
        print(f"  functions: {list(compiled.functions.keys())}")
    except AxiomViolation as e:
        print(f"  AXIOM VIOLATION: {e}")
        sys.exit(1)
    except LogicaError as e:
        print(f"  ERROR: {e}")
        sys.exit(1)


def show_tokens(filepath: str):
    """Show tokenization of a file."""
    with open(filepath, 'r') as f:
        source = f.read()

    lexer = Lexer(source)
    tokens = lexer.tokenize()

    for token in tokens:
        if token.type.name != 'NEWLINE':
            print(f"  {token}")


def transpile_file(filepath: str, output_path: str = None):
    """Transpile a .logica file to standalone JavaScript."""
    if not os.path.exists(filepath):
        print(f"Error: file not found: {filepath}")
        sys.exit(1)

    with open(filepath, 'r') as f:
        source = f.read()

    try:
        # Phase 1: Lex
        lexer = Lexer(source)
        tokens = lexer.tokenize()

        # Phase 2: Parse
        parser = Parser(tokens)
        ast = parser.parse()

        # Phase 3: Compile (axiom checking)
        compiler = Compiler()
        compiler.compile(ast)

        # Phase 4: Transpile to JS
        from logica.transpiler import JSTranspiler
        transpiler = JSTranspiler()
        js_code = transpiler.transpile(ast)

        if output_path is None:
            output_path = filepath.replace('.logica', '.js')

        with open(output_path, 'w') as f:
            f.write(js_code)

        print()
        print("=" * 60)
        print(f"  Logica JS Transpiler")
        print("=" * 60)
        print()
        print(f"  source:  {os.path.basename(filepath)}")
        print(f"  output:  {output_path}")
        print(f"  run:     node {output_path}")
        print()

    except AxiomViolation as e:
        print(f"  COMPILE ERROR: {e}")
        sys.exit(1)
    except LogicaError as e:
        print(f"  ERROR: {e}")
        sys.exit(1)


def transpile_c_file(filepath: str, output_path: str = None):
    """Transpile a .logica file to C source code."""
    if not os.path.exists(filepath):
        print(f"Error: file not found: {filepath}")
        sys.exit(1)

    with open(filepath, 'r') as f:
        source = f.read()

    try:
        if output_path is None:
            output_path = filepath.replace('.logica', '.c')

        from logica.wasm_build import build_c
        print()
        print("=" * 60)
        print(f"  Logica C Transpiler")
        print("=" * 60)
        print()
        print(f"  source:  {os.path.basename(filepath)}")
        print(f"  output:  {output_path}")
        build_c(source, output_path)
        print()

    except AxiomViolation as e:
        print(f"  COMPILE ERROR: {e}")
        sys.exit(1)
    except LogicaError as e:
        print(f"  ERROR: {e}")
        sys.exit(1)


def compile_wasm_file(filepath: str, output_path: str = None):
    """Compile a .logica file to WebAssembly."""
    if not os.path.exists(filepath):
        print(f"Error: file not found: {filepath}")
        sys.exit(1)

    with open(filepath, 'r') as f:
        source = f.read()

    try:
        if output_path is None:
            output_path = filepath.replace('.logica', '.wasm')

        from logica.wasm_build import build_wasm
        print()
        print("=" * 60)
        print(f"  Logica WASM Compiler")
        print("=" * 60)
        print()
        print(f"  source:  {os.path.basename(filepath)}")
        print(f"  output:  {output_path}")
        build_wasm(source, output_path)
        print()

    except AxiomViolation as e:
        print(f"  COMPILE ERROR: {e}")
        sys.exit(1)
    except LogicaError as e:
        print(f"  ERROR: {e}")
        sys.exit(1)
    except RuntimeError as e:
        print(f"  BUILD ERROR: {e}")
        sys.exit(1)


def show_ast(filepath: str):
    """Show the parsed AST."""
    with open(filepath, 'r') as f:
        source = f.read()

    lexer = Lexer(source)
    tokens = lexer.tokenize()
    parser = Parser(tokens)
    ast = parser.parse()

    _print_ast(ast, indent=0)


def _print_ast(node, indent=0):
    """Pretty-print an AST node."""
    prefix = "  " * indent
    name = type(node).__name__

    if hasattr(node, 'statements'):
        print(f"{prefix}{name}:")
        for s in node.statements:
            _print_ast(s, indent + 1)
    elif hasattr(node, 'body') and isinstance(getattr(node, 'body'), list):
        attrs = {k: v for k, v in node.__dict__.items()
                 if k not in ('body', 'line', 'col', 'otherwise_body',
                              'broken_body', 'elif_clauses', 'else_body')}
        print(f"{prefix}{name}({attrs}):")
        for s in node.body:
            _print_ast(s, indent + 1)
    else:
        attrs = {k: v for k, v in node.__dict__.items()
                 if k not in ('line', 'col') and v is not None}
        print(f"{prefix}{name}({attrs})")


def repl():
    """Interactive REPL for Logica."""
    print()
    print("=" * 60)
    print("  Logica v0.1 — Interactive REPL")
    print("  A Programming Language for Human Logic")
    print("=" * 60)
    print()
    print("  Every operation has a speaker.")
    print("  Every variable has an owner.")
    print("  Every action has a receipt.")
    print()
    print("  Type 'help' for commands. Type 'quit' to exit.")
    print()

    # Maintain state across REPL interactions
    from logica.runtime import Runtime, Environment

    runtime = Runtime()
    buffer = []
    brace_depth = 0

    while True:
        try:
            if brace_depth > 0:
                prompt = "  ... "
            else:
                speaker = runtime.env.current_speaker or "logica"
                prompt = f"  [{speaker}] > "

            line = input(prompt)

            # Commands
            if not buffer and line.strip().lower() in ('quit', 'exit', 'q'):
                _repl_quit(runtime)
                break

            if not buffer and line.strip().lower() == 'help':
                _repl_help()
                continue

            if not buffer and line.strip().lower() == 'state':
                _repl_state(runtime)
                continue

            # Track brace depth for multi-line input
            brace_depth += line.count('{') - line.count('}')
            buffer.append(line)

            if brace_depth <= 0:
                # Complete statement — execute
                source = '\n'.join(buffer)
                buffer = []
                brace_depth = 0

                if not source.strip():
                    continue

                try:
                    lexer = Lexer(source)
                    tokens = lexer.tokenize()
                    parser = Parser(tokens)
                    ast = parser.parse()
                    compiler = Compiler()

                    # Carry over known speakers
                    compiler.declared_speakers = set(runtime.env.speaker_ids.keys())
                    compiler.current_speaker = runtime.env.current_speaker

                    compiled = compiler.compile(ast)

                    # Execute with existing runtime state
                    runtime.execute(compiled)

                except AxiomViolation as e:
                    print(f"    AXIOM VIOLATION: {e}")
                except LogicaError as e:
                    print(f"    ERROR: {e}")
                except Exception as e:
                    print(f"    ERROR: {e}")

        except (EOFError, KeyboardInterrupt):
            print()
            _repl_quit(runtime)
            break


def _repl_help():
    """Print REPL help."""
    print("  LOGICA REPL COMMANDS:")
    print("  ─────────────────────────────────────")
    print("  speaker Name       — Declare a speaker")
    print("  as Name { ... }    — Enter speaker context")
    print("  let x = expr       — Write to your variable")
    print("  speak expr         — Output a value")
    print("  when cond { ... }  — Three-valued conditional")
    print("  if cond { ... }    — Conditional")
    print("  while c, max N {}  — Bounded loop")
    print("  fn name(p) { ... } — Define function")
    print("  request T action   — Send request")
    print("  inspect target     — Inspect state")
    print("  history s.var      — Variable timeline")
    print("  ledger             — View ledger")
    print("  verify ledger      — Check integrity")
    print("  seal var           — Make immutable")
    print()
    print("  state              — Show runtime state")
    print("  help               — This message")
    print("  quit               — Exit")
    print()


def _repl_state(runtime):
    """Show current runtime state."""
    env = runtime.env
    print(f"  speakers: {list(env.speaker_ids.keys())}")
    print(f"  active:   {env.current_speaker or '(none)'}")
    print(f"  functions: {list(env.functions.keys())}")
    print(f"  sealed:   {list(env.sealed)}")
    total = env.mary.ledger_count(0)
    intact = env.mary.ledger_verify()
    print(f"  ledger:   {total} entries, integrity: {'VALID' if intact else 'BROKEN'}")


def _repl_quit(runtime):
    """Exit the REPL."""
    total = runtime.env.mary.ledger_count(0)
    intact = runtime.env.mary.ledger_verify()
    print()
    print("  ═══════════════════════════════════════")
    print(f"  Session complete.")
    print(f"  Ledger: {total} entries")
    print(f"  Integrity: {'VALID' if intact else 'BROKEN'}")
    print(f"  Every operation had a speaker.")
    print(f"  Human Logic holds.")
    print("  ═══════════════════════════════════════")
    print()


def main():
    """Entry point."""
    if len(sys.argv) < 2:
        repl()
        return

    if sys.argv[1] == '--check' and len(sys.argv) > 2:
        check_file(sys.argv[2])
    elif sys.argv[1] == '--tokens' and len(sys.argv) > 2:
        show_tokens(sys.argv[2])
    elif sys.argv[1] == '--ast' and len(sys.argv) > 2:
        show_ast(sys.argv[2])
    elif sys.argv[1] == '--js' and len(sys.argv) > 2:
        out = sys.argv[3] if len(sys.argv) > 3 else None
        transpile_file(sys.argv[2], out)
    elif sys.argv[1] == '--c' and len(sys.argv) > 2:
        out = sys.argv[3] if len(sys.argv) > 3 else None
        transpile_c_file(sys.argv[2], out)
    elif sys.argv[1] == '--wasm' and len(sys.argv) > 2:
        out = sys.argv[3] if len(sys.argv) > 3 else None
        compile_wasm_file(sys.argv[2], out)
    elif sys.argv[1] == '--help':
        print(__doc__)
    else:
        run_file(sys.argv[1])


if __name__ == "__main__":
    main()
