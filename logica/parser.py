"""
Logica Parser — Source Text to Abstract Syntax Tree
====================================================

The parser reads tokens and builds a tree.
The tree is the program's structure.
The compiler reads the tree and checks the axioms.

Grammar (simplified):
    program     := statement*
    statement   := speaker_decl | world_decl | as_block | let_stmt | speak_stmt
                 | when_block | if_stmt | while_loop | fn_decl | return_stmt
                 | request_stmt | respond_stmt | inspect_stmt | history_stmt
                 | ledger_stmt | verify_stmt | seal_stmt | pass_stmt | fail_stmt
                 | expr_stmt
"""

from .lexer import Token, TokenType
from .ast_nodes import *
from .errors import ParseError


class Parser:
    """
    Recursive descent parser for Logica.

    Consumes tokens, produces AST.
    """

    def __init__(self, tokens: list[Token]):
        self.tokens = tokens
        self.pos = 0

    # ── Utilities ──────────────────────────────────────────────────────

    def _current(self) -> Token:
        if self.pos < len(self.tokens):
            return self.tokens[self.pos]
        return Token(TokenType.EOF, '', 0, 0)

    def _peek(self, offset=0) -> Token:
        idx = self.pos + offset
        if idx < len(self.tokens):
            return self.tokens[idx]
        return Token(TokenType.EOF, '', 0, 0)

    def _advance(self) -> Token:
        token = self._current()
        self.pos += 1
        return token

    def _expect(self, token_type: TokenType) -> Token:
        token = self._current()
        if token.type != token_type:
            raise ParseError(
                f"expected {token_type.name}, got {token.type.name} ({token.value!r})",
                token
            )
        return self._advance()

    def _match(self, *types) -> bool:
        return self._current().type in types

    def _skip_newlines(self):
        while self._match(TokenType.NEWLINE):
            self._advance()

    def _at_end(self) -> bool:
        return self._current().type == TokenType.EOF

    # ── Top-Level ─────────────────────────────────────────────────────

    def parse(self) -> Program:
        """Parse the entire program."""
        program = Program()
        self._skip_newlines()
        while not self._at_end():
            stmt = self._parse_statement()
            if stmt is not None:
                program.statements.append(stmt)
            self._skip_newlines()
        return program

    # ── Statements ────────────────────────────────────────────────────

    def _parse_statement(self):
        """Parse a single statement."""
        self._skip_newlines()
        if self._at_end():
            return None

        token = self._current()

        if token.type == TokenType.SPEAKER:
            return self._parse_speaker_decl()
        if token.type == TokenType.WORLD:
            return self._parse_world_decl()
        if token.type == TokenType.AS:
            return self._parse_as_block()
        if token.type == TokenType.LET:
            return self._parse_let()
        if token.type == TokenType.SPEAK:
            return self._parse_speak()
        if token.type == TokenType.WHEN:
            return self._parse_when()
        if token.type == TokenType.IF:
            return self._parse_if()
        if token.type == TokenType.WHILE:
            return self._parse_while()
        if token.type == TokenType.FN:
            return self._parse_fn()
        if token.type == TokenType.RETURN:
            return self._parse_return()
        if token.type == TokenType.REQUEST:
            return self._parse_request()
        if token.type == TokenType.RESPOND:
            return self._parse_respond()
        if token.type == TokenType.INSPECT:
            return self._parse_inspect()
        if token.type == TokenType.HISTORY:
            return self._parse_history()
        if token.type == TokenType.LEDGER:
            return self._parse_ledger()
        if token.type == TokenType.VERIFY:
            return self._parse_verify()
        if token.type == TokenType.SEAL:
            return self._parse_seal()
        if token.type == TokenType.PASS:
            return self._parse_pass()
        if token.type == TokenType.FAIL:
            return self._parse_fail()

        # Expression statement (function call, etc.)
        return self._parse_expr_statement()

    def _parse_speaker_decl(self) -> SpeakerDecl:
        """speaker Name"""
        token = self._expect(TokenType.SPEAKER)
        name_token = self._expect(TokenType.IDENTIFIER)
        self._consume_terminator()
        return SpeakerDecl(name=name_token.value, line=token.line, col=token.col)

    def _parse_world_decl(self) -> WorldDecl:
        """world Name or world Name(args)"""
        token = self._expect(TokenType.WORLD)
        name_token = self._expect(TokenType.IDENTIFIER)
        args = []
        if self._match(TokenType.LPAREN):
            self._advance()
            while not self._match(TokenType.RPAREN):
                args.append(self._parse_expression())
                if self._match(TokenType.COMMA):
                    self._advance()
            self._expect(TokenType.RPAREN)
        self._consume_terminator()
        return WorldDecl(name=name_token.value, args=args, line=token.line, col=token.col)

    def _parse_as_block(self) -> AsBlock:
        """as SpeakerName { body }"""
        token = self._expect(TokenType.AS)
        name_token = self._expect(TokenType.IDENTIFIER)
        self._skip_newlines()
        self._expect(TokenType.LBRACE)
        body = self._parse_block_body()
        self._expect(TokenType.RBRACE)
        return AsBlock(speaker_name=name_token.value, body=body,
                       line=token.line, col=token.col)

    def _parse_let(self) -> LetStatement:
        """let name = expr  or  let name.member = expr"""
        token = self._expect(TokenType.LET)
        # Parse the left-hand side — could be simple name or member access
        name_parts = [self._expect(TokenType.IDENTIFIER).value]
        while self._match(TokenType.DOT):
            self._advance()
            name_parts.append(self._expect(TokenType.IDENTIFIER).value)
        name = '.'.join(name_parts)

        # Handle indexing: let grades[student] = ...
        if self._match(TokenType.LBRACKET):
            self._advance()
            index_expr = self._parse_expression()
            self._expect(TokenType.RBRACKET)
            name = name  # keep the base name, index handled separately

        self._expect(TokenType.ASSIGN)
        value = self._parse_expression()
        self._consume_terminator()
        return LetStatement(name=name, value=value, line=token.line, col=token.col)

    def _parse_speak(self) -> SpeakStatement:
        """speak expr"""
        token = self._expect(TokenType.SPEAK)
        value = self._parse_expression()
        self._consume_terminator()
        return SpeakStatement(value=value, line=token.line, col=token.col)

    def _parse_when(self) -> WhenBlock:
        """
        when condition { body }
        when condition { body } otherwise { body }
        when condition { body } otherwise { body } broken { body }
        """
        token = self._expect(TokenType.WHEN)
        condition = self._parse_expression()
        self._skip_newlines()
        self._expect(TokenType.LBRACE)
        body = self._parse_block_body()
        self._expect(TokenType.RBRACE)

        otherwise_body = []
        broken_body = []

        self._skip_newlines()
        if self._match(TokenType.OTHERWISE):
            self._advance()
            self._skip_newlines()
            self._expect(TokenType.LBRACE)
            otherwise_body = self._parse_block_body()
            self._expect(TokenType.RBRACE)

        self._skip_newlines()
        if self._match(TokenType.BROKEN):
            self._advance()
            self._skip_newlines()
            self._expect(TokenType.LBRACE)
            broken_body = self._parse_block_body()
            self._expect(TokenType.RBRACE)

        return WhenBlock(condition=condition, body=body,
                         otherwise_body=otherwise_body,
                         broken_body=broken_body,
                         line=token.line, col=token.col)

    def _parse_if(self) -> IfStatement:
        """if condition { body } elif condition { body } else { body }"""
        token = self._expect(TokenType.IF)
        condition = self._parse_expression()
        self._skip_newlines()
        self._expect(TokenType.LBRACE)
        body = self._parse_block_body()
        self._expect(TokenType.RBRACE)

        elif_clauses = []
        else_body = []

        while True:
            self._skip_newlines()
            if self._match(TokenType.ELIF):
                elif_token = self._advance()
                elif_cond = self._parse_expression()
                self._skip_newlines()
                self._expect(TokenType.LBRACE)
                elif_body = self._parse_block_body()
                self._expect(TokenType.RBRACE)
                elif_clauses.append(ElifClause(
                    condition=elif_cond, body=elif_body,
                    line=elif_token.line, col=elif_token.col
                ))
            else:
                break

        self._skip_newlines()
        if self._match(TokenType.ELSE):
            self._advance()
            self._skip_newlines()
            self._expect(TokenType.LBRACE)
            else_body = self._parse_block_body()
            self._expect(TokenType.RBRACE)

        return IfStatement(condition=condition, body=body,
                           elif_clauses=elif_clauses,
                           else_body=else_body,
                           line=token.line, col=token.col)

    def _parse_while(self) -> WhileLoop:
        """while condition, max N { body }"""
        token = self._expect(TokenType.WHILE)
        condition = self._parse_expression()

        max_iterations = None
        if self._match(TokenType.COMMA):
            self._advance()
            self._expect(TokenType.MAX)
            max_iterations = self._parse_expression()

        self._skip_newlines()
        self._expect(TokenType.LBRACE)
        body = self._parse_block_body()
        self._expect(TokenType.RBRACE)

        return WhileLoop(condition=condition, body=body,
                         max_iterations=max_iterations,
                         line=token.line, col=token.col)

    def _parse_fn(self) -> FnDecl:
        """fn name(params) { body }"""
        token = self._expect(TokenType.FN)
        name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.LPAREN)

        params = []
        while not self._match(TokenType.RPAREN):
            params.append(self._expect(TokenType.IDENTIFIER).value)
            if self._match(TokenType.COMMA):
                self._advance()
        self._expect(TokenType.RPAREN)

        self._skip_newlines()
        self._expect(TokenType.LBRACE)
        body = self._parse_block_body()
        self._expect(TokenType.RBRACE)

        return FnDecl(name=name, params=params, body=body,
                       line=token.line, col=token.col)

    def _parse_return(self) -> ReturnStatement:
        """return or return expr"""
        token = self._expect(TokenType.RETURN)
        value = None
        if not self._match(TokenType.NEWLINE, TokenType.RBRACE, TokenType.EOF):
            value = self._parse_expression()
        self._consume_terminator()
        return ReturnStatement(value=value, line=token.line, col=token.col)

    def _parse_request(self) -> RequestStatement:
        """request TargetSpeaker action_string"""
        token = self._expect(TokenType.REQUEST)
        target = self._expect(TokenType.IDENTIFIER).value
        action = self._parse_expression()
        data = None
        # Check for 'with' keyword (using identifier since it's not a keyword)
        # We'll use a simpler syntax: request Target "action" data_expr
        self._consume_terminator()
        return RequestStatement(target=target, action=action, data=data,
                                line=token.line, col=token.col)

    def _parse_respond(self) -> RespondStatement:
        """respond accept or respond refuse"""
        token = self._expect(TokenType.RESPOND)
        accept = True
        if self._match(TokenType.ACCEPT):
            self._advance()
        elif self._match(TokenType.REFUSE):
            self._advance()
            accept = False
        data = None
        self._consume_terminator()
        return RespondStatement(accept=accept, data=data,
                                line=token.line, col=token.col)

    def _parse_inspect(self) -> InspectStatement:
        """inspect expr"""
        token = self._expect(TokenType.INSPECT)
        target = self._parse_expression()
        self._consume_terminator()
        return InspectStatement(target=target, line=token.line, col=token.col)

    def _parse_history(self) -> HistoryStatement:
        """history speaker.variable"""
        token = self._expect(TokenType.HISTORY)
        target = self._parse_expression()
        self._consume_terminator()
        return HistoryStatement(target=target, line=token.line, col=token.col)

    def _parse_ledger(self) -> LedgerStatement:
        """ledger or ledger last N"""
        token = self._expect(TokenType.LEDGER)
        count = None
        # Check for "last" as identifier
        if self._match(TokenType.IDENTIFIER) and self._current().value == "last":
            self._advance()
            count = self._parse_expression()
        elif self._match(TokenType.INTEGER):
            count = self._parse_expression()
        self._consume_terminator()
        return LedgerStatement(count=count, line=token.line, col=token.col)

    def _parse_verify(self) -> VerifyStatement:
        """verify ledger"""
        token = self._expect(TokenType.VERIFY)
        target = "ledger"
        if self._match(TokenType.LEDGER):
            self._advance()
        self._consume_terminator()
        return VerifyStatement(target=target, line=token.line, col=token.col)

    def _parse_seal(self) -> SealStatement:
        """seal variable_name"""
        token = self._expect(TokenType.SEAL)
        name = self._expect(TokenType.IDENTIFIER).value
        self._consume_terminator()
        return SealStatement(target=name, line=token.line, col=token.col)

    def _parse_pass(self) -> PassStatement:
        token = self._expect(TokenType.PASS)
        self._consume_terminator()
        return PassStatement(line=token.line, col=token.col)

    def _parse_fail(self) -> FailStatement:
        token = self._expect(TokenType.FAIL)
        reason = None
        if not self._match(TokenType.NEWLINE, TokenType.RBRACE, TokenType.EOF):
            reason = self._parse_expression()
        self._consume_terminator()
        return FailStatement(reason=reason, line=token.line, col=token.col)

    def _parse_expr_statement(self) -> ExpressionStatement:
        """An expression used as a statement."""
        expr = self._parse_expression()
        self._consume_terminator()
        return ExpressionStatement(expression=expr, line=expr.line, col=expr.col)

    # ── Block Parsing ─────────────────────────────────────────────────

    def _parse_block_body(self) -> list:
        """Parse statements inside { } until we see }."""
        statements = []
        self._skip_newlines()
        while not self._match(TokenType.RBRACE) and not self._at_end():
            stmt = self._parse_statement()
            if stmt is not None:
                statements.append(stmt)
            self._skip_newlines()
        return statements

    # ── Expressions ───────────────────────────────────────────────────

    def _parse_expression(self) -> Expression:
        """Parse an expression. Entry point for expression parsing."""
        return self._parse_or()

    def _parse_or(self) -> Expression:
        left = self._parse_and()
        while self._match(TokenType.OR):
            op_token = self._advance()
            right = self._parse_and()
            left = BinaryOp(left=left, op='or', right=right,
                            line=op_token.line, col=op_token.col)
        return left

    def _parse_and(self) -> Expression:
        left = self._parse_not()
        while self._match(TokenType.AND):
            op_token = self._advance()
            right = self._parse_not()
            left = BinaryOp(left=left, op='and', right=right,
                            line=op_token.line, col=op_token.col)
        return left

    def _parse_not(self) -> Expression:
        if self._match(TokenType.NOT):
            op_token = self._advance()
            operand = self._parse_not()
            return UnaryOp(op='not', operand=operand,
                           line=op_token.line, col=op_token.col)
        return self._parse_comparison()

    def _parse_comparison(self) -> Expression:
        left = self._parse_addition()
        while self._match(TokenType.EQ, TokenType.NEQ, TokenType.LT,
                          TokenType.GT, TokenType.LTE, TokenType.GTE):
            op_token = self._advance()
            right = self._parse_addition()
            left = BinaryOp(left=left, op=op_token.value, right=right,
                            line=op_token.line, col=op_token.col)
        return left

    def _parse_addition(self) -> Expression:
        left = self._parse_multiplication()
        while self._match(TokenType.PLUS, TokenType.MINUS):
            op_token = self._advance()
            right = self._parse_multiplication()
            left = BinaryOp(left=left, op=op_token.value, right=right,
                            line=op_token.line, col=op_token.col)
        return left

    def _parse_multiplication(self) -> Expression:
        left = self._parse_unary()
        while self._match(TokenType.STAR, TokenType.SLASH, TokenType.PERCENT):
            op_token = self._advance()
            right = self._parse_unary()
            left = BinaryOp(left=left, op=op_token.value, right=right,
                            line=op_token.line, col=op_token.col)
        return left

    def _parse_unary(self) -> Expression:
        if self._match(TokenType.MINUS):
            op_token = self._advance()
            operand = self._parse_unary()
            return UnaryOp(op='-', operand=operand,
                           line=op_token.line, col=op_token.col)
        return self._parse_postfix()

    def _parse_postfix(self) -> Expression:
        """Parse member access (.), indexing ([]), and function calls (())."""
        expr = self._parse_primary()

        while True:
            if self._match(TokenType.DOT):
                self._advance()
                member = self._expect(TokenType.IDENTIFIER)
                expr = MemberAccess(object=expr, member=member.value,
                                    line=member.line, col=member.col)
            elif self._match(TokenType.LPAREN):
                self._advance()
                args = []
                while not self._match(TokenType.RPAREN):
                    args.append(self._parse_expression())
                    if self._match(TokenType.COMMA):
                        self._advance()
                self._expect(TokenType.RPAREN)
                expr = FnCall(function=expr, args=args,
                              line=expr.line, col=expr.col)
            elif self._match(TokenType.LBRACKET):
                self._advance()
                index = self._parse_expression()
                self._expect(TokenType.RBRACKET)
                expr = IndexAccess(object=expr, index=index,
                                   line=expr.line, col=expr.col)
            else:
                break

        return expr

    def _parse_primary(self) -> Expression:
        """Parse a primary expression (literals, identifiers, groups)."""
        token = self._current()

        # Integer
        if token.type == TokenType.INTEGER:
            self._advance()
            return IntegerLiteral(value=int(token.value),
                                  line=token.line, col=token.col)

        # Float
        if token.type == TokenType.FLOAT:
            self._advance()
            return FloatLiteral(value=float(token.value),
                                line=token.line, col=token.col)

        # String
        if token.type == TokenType.STRING:
            self._advance()
            return StringLiteral(value=token.value,
                                 line=token.line, col=token.col)

        # Boolean
        if token.type in (TokenType.TRUE, TokenType.FALSE):
            self._advance()
            return BooleanLiteral(value=(token.type == TokenType.TRUE),
                                  line=token.line, col=token.col)

        # None
        if token.type == TokenType.NONE:
            self._advance()
            return NoneLiteral(line=token.line, col=token.col)

        # Status literals
        if token.type == TokenType.ACTIVE:
            self._advance()
            return StatusLiteral(value="active", line=token.line, col=token.col)
        if token.type == TokenType.INACTIVE:
            self._advance()
            return StatusLiteral(value="inactive", line=token.line, col=token.col)
        if token.type == TokenType.BROKEN:
            self._advance()
            return StatusLiteral(value="broken", line=token.line, col=token.col)

        # Read expression
        if token.type == TokenType.READ:
            self._advance()
            target = self._parse_postfix()
            return ReadExpr(target=target, line=token.line, col=token.col)

        # Identifier
        if token.type == TokenType.IDENTIFIER:
            self._advance()
            return Identifier(name=token.value,
                              line=token.line, col=token.col)

        # Parenthesized expression
        if token.type == TokenType.LPAREN:
            self._advance()
            expr = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return expr

        raise ParseError(f"unexpected token: {token.value!r}", token)

    # ── Helpers ───────────────────────────────────────────────────────

    def _consume_terminator(self):
        """Consume a newline or check for end of block/file."""
        if self._match(TokenType.NEWLINE):
            while self._match(TokenType.NEWLINE):
                self._advance()
        elif self._match(TokenType.RBRACE, TokenType.EOF):
            pass  # don't consume — let the block parser handle it
        # else: allow missing terminator (e.g., last statement in block)
