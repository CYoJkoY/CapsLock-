#!/usr/bin/env python3
"""Lightweight structural linter for the AutoHotkey v2 sources.

The project's CI runs ``AutoHotkey64.exe /Validate`` on Windows. This script is
the portable subset of that check: it is meant for quick feedback on machines
without AutoHotkey (editors, Linux/macOS checkouts, pre-commit hooks) and for
CI use as an early, dependency-free gate.

What it checks
    * balanced ``{}`` / ``()`` / ``[]`` outside strings and comments
    * terminated string literals (both ``"..."`` and ``'...'``, including the
      backtick escape and the doubled-quote escape)
    * continuation sections (``(`` ... ``)``) are skipped as raw text
    * every ``#Include`` target resolves to an existing file
    * ``#Requires AutoHotkey v2.0`` is present

What it deliberately does NOT do
    * type checking, name resolution, or expression validation -- that is what
      ``AutoHotkey64.exe /Validate`` is for.

Usage
    python3 scripts/ahk_lint.py            # lint every .ahk file
    python3 scripts/ahk_lint.py path/to/Foo.ahk ...
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Literal encoding arguments accepted by the v2 file functions, per the
# "FileOpen"/"FileRead"/"FileAppend" documentation: UTF-8, UTF-8-RAW,
# UTF-16, UTF-16-RAW and CP0/CPnnn. There is deliberately NO bare "RAW":
# v1's "RAW" encoding does not exist in v2, and passing it *throws*
# "Parameter #3 invalid" - which a swallowing catch turns into silent
# breakage (a hash helper returning "" reads as a mismatch, for example).
_VALID_FILE_ENCODING = re.compile(r"^(?:UTF-8|UTF-8-RAW|UTF-16|UTF-16-RAW|CP\d+)$", re.I)

# Function name -> position (0-based) of the Encoding parameter in its call.
_FILE_FUNCTIONS_WITH_ENCODING = {"FileOpen": 2, "FileRead": 1, "FileAppend": 2}


class Issue:
    def __init__(self, path: str, line: int, kind: str, detail: str) -> None:
        self.path = path
        self.line = line
        self.kind = kind
        self.detail = detail

    def __str__(self) -> str:
        rel = os.path.relpath(self.path, ROOT)
        return "{}:{}: [{}] {}".format(rel, self.line, self.kind, self.detail)


def _strip_comment(line: str) -> str:
    """Remove a trailing ``;`` comment, respecting AHK string quoting."""
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if ch == "`":
            i += 2
            continue
        if ch in "\"'":
            quote = ch
            i += 1
            while i < n:
                if line[i] == "`":
                    i += 2
                    continue
                if line[i] == quote:
                    if i + 1 < n and line[i + 1] == quote:
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue
        if ch == ";":
            # A semicolon inside a hotstring or after a closing paren on a
            # continuation start is not a comment; treat the simple case.
            return line[:i]
        i += 1
    return line


def lint_text(path: str, text: str) -> list[Issue]:
    issues: list[Issue] = []
    lines = text.replace("\r\n", "\n").split("\n")

    stack: list[tuple[str, int, str]] = []  # (char, line_no, snippet)

    in_block_comment = False
    in_continuation = False
    continuation_join = False  # continuation immediately followed by an operator

    requires_v2 = False
    line_no = 0

    for raw in lines:
        line_no += 1
        stripped = raw.strip()

        if in_block_comment:
            if stripped.startswith("*/") or stripped.endswith("*/"):
                in_block_comment = False
            continue

        if stripped.startswith("/*"):
            if not stripped.endswith("*/"):
                in_block_comment = True
            continue

        if in_continuation:
            if stripped.startswith(")"):
                in_continuation = False
            continue

        if stripped.startswith("#Requires") and "AutoHotkey v2" in stripped:
            requires_v2 = True

        code = _strip_comment(raw)

        # A literal continuation section is the only construct whose body is
        # raw text rather than code. Detection is deliberately narrow: a line
        # that is nothing but "(". Multi-line parenthesized expressions such as
        # `OnEvent("Click", (*) => (` ... `))` are real code and are handled by
        # the depth tracking below, not here.
        if stripped == "(":
            in_continuation = True
            continue

        # Balance scan over the comment-stripped line.
        i = 0
        n = len(code)
        while i < n:
            ch = code[i]

            if ch == "`":
                i += 2
                continue

            if ch == '"' or ch == "'":
                quote = ch
                i += 1
                closed = False
                while i < n:
                    if code[i] == "`":
                        i += 2
                        continue
                    if code[i] == quote:
                        if i + 1 < n and code[i + 1] == quote:
                            i += 2
                            continue
                        i += 1
                        closed = True
                        break
                    i += 1
                if not closed:
                    issues.append(
                        Issue(path, line_no, "string",
                              "unterminated {}-quoted string".format("double" if quote == '"' else "single"))
                    )
                continue

            if ch in "([{":
                stack.append((ch, line_no, stripped[:60]))
                i += 1
                continue

            if ch in ")]}":
                expected = {"(": ")", "[": "]", "{": "}"}
                if not stack:
                    # A leading ")" is legal: it closes a multi-line expression
                    # opened on an earlier line inside a continuation body.
                    if ch != ")" or not stripped.startswith(")"):
                        issues.append(Issue(path, line_no, "bracket", "unmatched '{}'".format(ch)))
                    i += 1
                    continue
                else:
                    opener, open_line, _ = stack.pop()
                    if expected[opener] != ch:
                        issues.append(
                            Issue(path, line_no, "bracket",
                                  "'{}' closes '{}' opened on line {}".format(ch, opener, open_line))
                        )
                i += 1
                continue

            i += 1

    for opener, open_line, snippet in stack:
        issues.append(
            Issue(path, open_line, "bracket",
                  "unclosed '{}' (starts: {})".format(opener, snippet))
        )

    if not requires_v2 and not os.path.basename(path).startswith("_"):
        issues.append(Issue(path, 1, "requires", "missing '#Requires AutoHotkey v2.0'"))

    # Resolve #Include targets relative to the including file.
    for idx, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if not stripped.startswith("#Include"):
            continue
        rest = stripped[len("#Include"):].strip()
        if rest.startswith("%") or rest.startswith("*i "):
            rest = rest.lstrip("*i ").strip()
        if rest.startswith('"') and '"' in rest[1:]:
            target = rest[1:rest.index('"', 1)]
        elif rest.startswith("'") and "'" in rest[1:]:
            target = rest[1:rest.index("'", 1)]
        else:
            continue
        # #Include paths are written with Windows separators; normalise them so
        # the check works on POSIX checkouts too.
        target = target.replace("\\", "/")
        resolved = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(path)), target))
        if not os.path.exists(resolved):
            issues.append(Issue(path, idx, "include", "missing include target: {}".format(target)))

    issues.extend(_check_file_encodings(path, lines))

    return issues


def _paren_depth(code: str) -> int:
    """Depth of unclosed '(' in a comment-stripped line, ignoring strings."""
    depth = 0
    i = 0
    n = len(code)
    while i < n:
        ch = code[i]
        if ch == "`":
            i += 2
            continue
        if ch in "\"'":
            quote = ch
            i += 1
            while i < n:
                if code[i] == "`":
                    i += 2
                    continue
                if code[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        i += 1
    return depth


def _call_arguments(code: str, open_paren: int) -> list[str] | None:
    """Split a function call's arguments starting at ``code[open_paren] == '('``.

    Quotes, backtick escapes and nested brackets are respected. Returns None
    when the closing parenthesis is not on the same line, so multi-line calls
    are simply not checked (the lint is deliberately line-local).
    """
    depth = 0
    args: list[str] = []
    cur: list[str] = []
    quote = ""
    i = open_paren
    n = len(code)
    while i < n:
        ch = code[i]
        if quote:
            if ch == "`":
                i += 2
                continue
            if ch == quote:
                if i + 1 < n and code[i + 1] == quote:
                    i += 2
                    continue
                quote = ""
            cur.append(ch)
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            cur.append(ch)
            i += 1
            continue
        if ch == "`":
            i += 2
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                args.append("".join(cur))
                return args
        elif ch == "," and depth == 1:
            args.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    return None


def _check_file_encodings(path: str, lines: list[str]) -> list[Issue]:
    """Flag literal encoding arguments the v2 file functions would reject.

    ``FileOpen(path, "r", "RAW")`` is the motivating case: "RAW" is not a v2
    encoding, so FileOpen throws, a surrounding ``catch`` swallows it, and a
    hash helper quietly returns "" - which upstream then reports as a bogus
    SHA-256 "mismatch". One grep turns that whole failure mode into a lint hit.
    """
    issues: list[Issue] = []
    pattern = re.compile(
        r"(?<![\w.])({})\s*\(".format("|".join(_FILE_FUNCTIONS_WITH_ENCODING))
    )
    for idx, raw in enumerate(lines, start=1):
        code = _strip_comment(raw)
        for match in pattern.finditer(code):
            func = match.group(1)
            args = _call_arguments(code, code.index("(", match.start()))
            if args is None:
                continue
            enc_index = _FILE_FUNCTIONS_WITH_ENCODING[func]
            if enc_index >= len(args):
                continue
            enc = args[enc_index].strip()
            if len(enc) >= 2 and enc[0] == '"' and enc[-1] == '"':
                inner = enc[1:-1]
                if not _VALID_FILE_ENCODING.match(inner):
                    issues.append(
                        Issue(path, idx, "encoding",
                              '{}: "{}" is not a valid AutoHotkey v2 file encoding '
                              '(use CP0/CPnnn, UTF-8, UTF-8-RAW, UTF-16 or UTF-16-RAW; '
                              'v2 has no bare "RAW")'.format(func, inner))
                    )
    return issues


def iter_ahk_files(paths: list[str]) -> list[str]:
    out: list[str] = []
    if paths:
        for p in paths:
            if os.path.isdir(p):
                for dirpath, _dirnames, filenames in os.walk(p):
                    for fn in filenames:
                        if fn.lower().endswith(".ahk"):
                            out.append(os.path.join(dirpath, fn))
            else:
                out.append(p)
        return out

    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in {".git", "node_modules", "build", "configs"}]
        for fn in filenames:
            if fn.lower().endswith(".ahk"):
                out.append(os.path.join(dirpath, fn))
    return sorted(out)


def main(argv: list[str]) -> int:
    files = iter_ahk_files(argv)
    if not files:
        print("no .ahk files found")
        return 1

    all_issues: list[Issue] = []
    for path in files:
        with open(path, "r", encoding="utf-8-sig", errors="replace") as fh:
            text = fh.read()
        all_issues.extend(lint_text(path, text))

    if all_issues:
        for issue in all_issues:
            print(issue)
        print("\n{} file(s) checked, {} issue(s) found.".format(len(files), len(all_issues)))
        return 1

    print("OK: {} file(s) checked, no structural issues found.".format(len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
