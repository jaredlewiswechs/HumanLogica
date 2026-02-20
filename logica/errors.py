"""
Logica Errors — What Goes Wrong and Why
========================================

Every error maps to a violation. Every violation cites an axiom.
"""


class LogicaError(Exception):
    """Base error for the Logica language."""
    pass


class LexError(LogicaError):
    """Tokenization failed."""
    def __init__(self, message, line=None, col=None):
        self.line = line
        self.col = col
        loc = f" at line {line}, col {col}" if line else ""
        super().__init__(f"Lex error{loc}: {message}")


class ParseError(LogicaError):
    """Parsing failed. The syntax is wrong."""
    def __init__(self, message, token=None):
        self.token = token
        loc = ""
        if token:
            loc = f" at line {token.line}, col {token.col}"
        super().__init__(f"Parse error{loc}: {message}")


class AxiomViolation(LogicaError):
    """
    The program violates a Human Logic axiom.
    This is not a runtime error. This is a proof failure.
    The program is invalid. It cannot be expressed.
    """
    def __init__(self, axiom_number, axiom_name, message, line=None):
        self.axiom_number = axiom_number
        self.axiom_name = axiom_name
        self.line = line
        loc = f" (line {line})" if line else ""
        super().__init__(
            f"Axiom {axiom_number} violation{loc} — {axiom_name}: {message}"
        )


class RuntimeError_(LogicaError):
    """Runtime evaluation failure. Expression is broken."""
    def __init__(self, message, speaker=None):
        who = f" [{speaker}]" if speaker else ""
        super().__init__(f"Broken{who}: {message}")
