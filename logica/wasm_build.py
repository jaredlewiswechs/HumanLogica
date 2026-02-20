"""
Logica WASM Build Pipeline — Logica -> C -> WASM
=================================================

Compiles a Logica source file to a standalone .wasm binary.

Steps:
    1. Parse + compile (axiom check)
    2. Transpile to C
    3. Compile C to WASM with clang (wasm32-wasi target)

Usage:
    from logica.wasm_build import build_wasm
    build_wasm(source_code, "output.wasm")

Or from CLI:
    python3 logica.py --wasm program.logica
"""

import subprocess
import tempfile
import os
import shutil


def build_wasm(logica_source: str, output_path: str, wasi_sdk: str = None,
               keep_c: bool = False):
    """
    Compile a Logica source string to a .wasm file.

    Args:
        logica_source: Logica source code string
        output_path: Where to write the .wasm file
        wasi_sdk: Path to WASI SDK (or None to auto-detect)
        keep_c: If True, also save the intermediate C file
    """
    from .lexer import Lexer
    from .parser import Parser
    from .compiler import Compiler
    from .c_transpiler import CTranspiler

    # Step 1: Parse and check axioms
    tokens = Lexer(logica_source).tokenize()
    ast = Parser(tokens).parse()
    Compiler().compile(ast)  # raises on axiom violation

    # Step 2: Transpile to C
    c_source = CTranspiler().transpile(ast)

    # Step 3: Compile to WASM
    with tempfile.TemporaryDirectory() as tmpdir:
        # Write C source
        c_path = os.path.join(tmpdir, "program.c")
        with open(c_path, "w") as f:
            f.write(c_source)

        # Copy Mary runtime
        wasm_dir = os.path.join(os.path.dirname(__file__), "..", "wasm")
        mary_h = os.path.join(wasm_dir, "mary.h")
        mary_c = os.path.join(wasm_dir, "mary.c")
        shutil.copy(mary_h, tmpdir)
        shutil.copy(mary_c, tmpdir)

        # Find compiler
        wasi_clang = _find_clang(wasi_sdk)
        sysroot = _find_sysroot(wasi_sdk)

        # Build command
        wasm_path = os.path.join(tmpdir, "output.wasm")
        cmd = [wasi_clang]

        if sysroot:
            cmd += [
                "--target=wasm32-wasi",
                f"--sysroot={sysroot}",
            ]
        else:
            cmd += ["--target=wasm32-wasi"]

        cmd += [
            "-O2",
            "-o", wasm_path,
            os.path.join(tmpdir, "mary.c"),
            c_path,
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"WASM compilation failed:\n{result.stderr}")

        # Copy output
        shutil.copy(wasm_path, output_path)

        # Optionally save C source
        if keep_c:
            c_out = output_path.replace('.wasm', '.c')
            shutil.copy(c_path, c_out)

    size = os.path.getsize(output_path)
    size_str = f"{size / 1024:.1f}KB" if size < 1024 * 1024 else f"{size / (1024*1024):.1f}MB"
    print(f"  compiled: {output_path} ({size_str})")
    print(f"  run with: wasmtime {output_path}")


def build_c(logica_source: str, output_path: str):
    """
    Transpile a Logica source string to C (without compiling to WASM).

    Args:
        logica_source: Logica source code string
        output_path: Where to write the .c file
    """
    from .lexer import Lexer
    from .parser import Parser
    from .compiler import Compiler
    from .c_transpiler import CTranspiler

    # Step 1: Parse and check axioms
    tokens = Lexer(logica_source).tokenize()
    ast = Parser(tokens).parse()
    Compiler().compile(ast)

    # Step 2: Transpile to C
    c_source = CTranspiler().transpile(ast)

    with open(output_path, 'w') as f:
        f.write(c_source)

    print(f"  C source: {output_path}")
    print(f"  compile:  clang -o program {output_path} wasm/mary.c -I wasm -lm")


def _find_clang(wasi_sdk=None):
    """Find clang with WASM target support."""
    if wasi_sdk:
        clang = os.path.join(wasi_sdk, "bin", "clang")
        if os.path.exists(clang):
            return clang

    # Try WASI SDK clang first (better WASM support)
    for sdk_path in [
        os.environ.get("WASI_SDK_PATH", ""),
        "/opt/wasi-sdk",
        os.path.expanduser("~/.wasi-sdk"),
        "/usr/local/wasi-sdk",
    ]:
        if sdk_path:
            clang = os.path.join(sdk_path, "bin", "clang")
            if os.path.exists(clang):
                return clang

    # Try system clang
    for name in ["clang-18", "clang-17", "clang-16", "clang"]:
        if shutil.which(name):
            return name

    raise RuntimeError(
        "clang not found. Install WASI SDK or clang with wasm target.\n"
        "  WASI SDK: https://github.com/WebAssembly/wasi-sdk/releases\n"
        "  Set WASI_SDK_PATH environment variable after installing."
    )


def _find_sysroot(wasi_sdk=None):
    """Find WASI sysroot."""
    if wasi_sdk:
        sr = os.path.join(wasi_sdk, "share", "wasi-sysroot")
        if os.path.exists(sr):
            return sr

    # Check WASI_SYSROOT env var directly
    env_sysroot = os.environ.get("WASI_SYSROOT", "")
    if env_sysroot and os.path.exists(env_sysroot):
        return env_sysroot

    # Check common locations
    for path in [
        os.path.join(os.environ.get("WASI_SDK_PATH", ""), "share", "wasi-sysroot"),
        "/opt/wasi-sdk/share/wasi-sysroot",
        "/usr/share/wasi-sysroot",
        os.path.expanduser("~/.wasi-sdk/share/wasi-sysroot"),
        "/usr/local/wasi-sdk/share/wasi-sysroot",
        "/tmp/wasi-sysroot-24.0",
    ]:
        if path and os.path.exists(path):
            return path

    # No sysroot found — clang might have it built-in
    return None
