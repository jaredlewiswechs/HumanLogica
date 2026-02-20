"""
Logica Lexer — Breaking Source Into Tokens
==========================================

Twenty-five keywords. Three values. One language.
"""

from enum import Enum, auto
from dataclasses import dataclass
from typing import Optional
from .errors import LexError


class TokenType(Enum):
    # Literals
    INTEGER = auto()
    FLOAT = auto()
    STRING = auto()
    BOOLEAN = auto()

    # Identifiers
    IDENTIFIER = auto()

    # Keywords — Identity
    SPEAKER = auto()       # speaker
    AS = auto()            # as

    # Keywords — Variables
    LET = auto()           # let
    READ = auto()          # read

    # Keywords — Expressions
    SPEAK = auto()         # speak
    WHEN = auto()           # when
    OTHERWISE = auto()     # otherwise
    BROKEN = auto()        # broken

    # Keywords — Functions
    FN = auto()            # fn
    RETURN = auto()        # return

    # Keywords — Loops
    WHILE = auto()         # while
    MAX = auto()           # max

    # Keywords — Communication
    REQUEST = auto()       # request
    RESPOND = auto()       # respond
    ACCEPT = auto()        # accept
    REFUSE = auto()        # refuse

    # Keywords — Inspection
    INSPECT = auto()       # inspect
    HISTORY = auto()       # history
    LEDGER = auto()        # ledger
    VERIFY = auto()        # verify

    # Keywords — Worlds
    WORLD = auto()         # world
    SEAL = auto()          # seal

    # Keywords — Logic
    AND = auto()           # and
    OR = auto()            # or
    NOT = auto()           # not

    # Keywords — Values
    ACTIVE = auto()        # active
    INACTIVE = auto()      # inactive
    TRUE = auto()          # true
    FALSE = auto()         # false
    NONE = auto()          # none

    # Keywords — Control
    IF = auto()            # if
    ELIF = auto()          # elif
    ELSE = auto()          # else
    PASS = auto()          # pass
    FAIL = auto()          # fail

    # Operators
    PLUS = auto()          # +
    MINUS = auto()         # -
    STAR = auto()          # *
    SLASH = auto()         # /
    PERCENT = auto()       # %
    ASSIGN = auto()        # =
    EQ = auto()            # ==
    NEQ = auto()           # !=
    LT = auto()            # <
    GT = auto()            # >
    LTE = auto()           # <=
    GTE = auto()           # >=
    DOT = auto()           # .
    COMMA = auto()         # ,
    COLON = auto()         # :
    ARROW = auto()         # ->

    # Delimiters
    LBRACE = auto()        # {
    RBRACE = auto()        # }
    LPAREN = auto()        # (
    RPAREN = auto()        # )
    LBRACKET = auto()      # [
    RBRACKET = auto()      # ]

    # Special
    NEWLINE = auto()
    EOF = auto()
    COMMENT = auto()


# Keyword map
KEYWORDS = {
    "speaker": TokenType.SPEAKER,
    "as": TokenType.AS,
    "let": TokenType.LET,
    "read": TokenType.READ,
    "speak": TokenType.SPEAK,
    "when": TokenType.WHEN,
    "otherwise": TokenType.OTHERWISE,
    "broken": TokenType.BROKEN,
    "fn": TokenType.FN,
    "return": TokenType.RETURN,
    "while": TokenType.WHILE,
    "max": TokenType.MAX,
    "request": TokenType.REQUEST,
    "respond": TokenType.RESPOND,
    "accept": TokenType.ACCEPT,
    "refuse": TokenType.REFUSE,
    "inspect": TokenType.INSPECT,
    "history": TokenType.HISTORY,
    "ledger": TokenType.LEDGER,
    "verify": TokenType.VERIFY,
    "world": TokenType.WORLD,
    "seal": TokenType.SEAL,
    "and": TokenType.AND,
    "or": TokenType.OR,
    "not": TokenType.NOT,
    "active": TokenType.ACTIVE,
    "inactive": TokenType.INACTIVE,
    "true": TokenType.TRUE,
    "false": TokenType.FALSE,
    "none": TokenType.NONE,
    "if": TokenType.IF,
    "elif": TokenType.ELIF,
    "else": TokenType.ELSE,
    "pass": TokenType.PASS,
    "fail": TokenType.FAIL,
}


@dataclass
class Token:
    type: TokenType
    value: str
    line: int
    col: int

    def __repr__(self):
        return f"Token({self.type.name}, {self.value!r}, L{self.line}:{self.col})"


class Lexer:
    """
    Breaks Logica source code into tokens.

    Supports:
    - # line comments
    - String literals with " or '
    - Integer and float literals
    - All operators and delimiters
    - 25 keywords
    """

    def __init__(self, source: str):
        self.source = source
        self.pos = 0
        self.line = 1
        self.col = 1
        self.tokens: list[Token] = []

    def tokenize(self) -> list[Token]:
        """Tokenize the entire source. Returns list of tokens."""
        while self.pos < len(self.source):
            self._skip_whitespace()
            if self.pos >= len(self.source):
                break

            ch = self.source[self.pos]

            # Newlines
            if ch == '\n':
                self._add(TokenType.NEWLINE, '\n')
                self._advance()
                continue

            # Comments
            if ch == '#':
                self._read_comment()
                continue

            # Strings
            if ch in ('"', "'"):
                self._read_string(ch)
                continue

            # Numbers
            if ch.isdigit():
                self._read_number()
                continue

            # Identifiers and keywords
            if ch.isalpha() or ch == '_':
                self._read_identifier()
                continue

            # Two-character operators
            if self.pos + 1 < len(self.source):
                two = self.source[self.pos:self.pos + 2]
                if two == '==':
                    self._add(TokenType.EQ, '==')
                    self._advance(2)
                    continue
                if two == '!=':
                    self._add(TokenType.NEQ, '!=')
                    self._advance(2)
                    continue
                if two == '<=':
                    self._add(TokenType.LTE, '<=')
                    self._advance(2)
                    continue
                if two == '>=':
                    self._add(TokenType.GTE, '>=')
                    self._advance(2)
                    continue
                if two == '->':
                    self._add(TokenType.ARROW, '->')
                    self._advance(2)
                    continue

            # Single-character operators and delimiters
            single = {
                '+': TokenType.PLUS,
                '-': TokenType.MINUS,
                '*': TokenType.STAR,
                '/': TokenType.SLASH,
                '%': TokenType.PERCENT,
                '=': TokenType.ASSIGN,
                '<': TokenType.LT,
                '>': TokenType.GT,
                '.': TokenType.DOT,
                ',': TokenType.COMMA,
                ':': TokenType.COLON,
                '{': TokenType.LBRACE,
                '}': TokenType.RBRACE,
                '(': TokenType.LPAREN,
                ')': TokenType.RPAREN,
                '[': TokenType.LBRACKET,
                ']': TokenType.RBRACKET,
            }

            if ch in single:
                self._add(single[ch], ch)
                self._advance()
                continue

            raise LexError(f"unexpected character: {ch!r}", self.line, self.col)

        self._add(TokenType.EOF, '')
        return self.tokens

    def _skip_whitespace(self):
        """Skip spaces and tabs (not newlines)."""
        while self.pos < len(self.source) and self.source[self.pos] in (' ', '\t', '\r'):
            self._advance()

    def _advance(self, n=1):
        """Advance position by n characters."""
        for _ in range(n):
            if self.pos < len(self.source):
                if self.source[self.pos] == '\n':
                    self.line += 1
                    self.col = 1
                else:
                    self.col += 1
                self.pos += 1

    def _add(self, token_type: TokenType, value: str):
        """Add a token to the list."""
        self.tokens.append(Token(token_type, value, self.line, self.col))

    def _read_comment(self):
        """Read a # comment to end of line."""
        start_col = self.col
        comment = ''
        self._advance()  # skip #
        while self.pos < len(self.source) and self.source[self.pos] != '\n':
            comment += self.source[self.pos]
            self._advance()
        # Comments are skipped, not added to tokens

    def _read_string(self, quote: str):
        """Read a string literal."""
        start_line = self.line
        start_col = self.col
        self._advance()  # skip opening quote
        value = ''
        while self.pos < len(self.source):
            ch = self.source[self.pos]
            if ch == '\\' and self.pos + 1 < len(self.source):
                next_ch = self.source[self.pos + 1]
                escapes = {'n': '\n', 't': '\t', '\\': '\\', quote: quote}
                if next_ch in escapes:
                    value += escapes[next_ch]
                    self._advance(2)
                    continue
            if ch == quote:
                self._advance()  # skip closing quote
                self.tokens.append(Token(TokenType.STRING, value, start_line, start_col))
                return
            if ch == '\n':
                raise LexError("unterminated string", start_line, start_col)
            value += ch
            self._advance()
        raise LexError("unterminated string", start_line, start_col)

    def _read_number(self):
        """Read an integer or float literal."""
        start_col = self.col
        value = ''
        is_float = False
        while self.pos < len(self.source) and (self.source[self.pos].isdigit() or self.source[self.pos] == '.'):
            if self.source[self.pos] == '.':
                # Check if this is a decimal point or member access
                if is_float:
                    break  # second dot — stop
                if self.pos + 1 < len(self.source) and self.source[self.pos + 1].isdigit():
                    is_float = True
                else:
                    break  # dot followed by non-digit — member access
            value += self.source[self.pos]
            self._advance()
        token_type = TokenType.FLOAT if is_float else TokenType.INTEGER
        self.tokens.append(Token(token_type, value, self.line, start_col))

    def _read_identifier(self):
        """Read an identifier or keyword."""
        start_col = self.col
        value = ''
        while self.pos < len(self.source) and (self.source[self.pos].isalnum() or self.source[self.pos] == '_'):
            value += self.source[self.pos]
            self._advance()

        # Check for keywords
        token_type = KEYWORDS.get(value, TokenType.IDENTIFIER)
        self.tokens.append(Token(token_type, value, self.line, start_col))
