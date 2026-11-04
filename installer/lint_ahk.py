#!/usr/bin/env python3
"""Catch AutoHotkey v2 mistakes that only show up when the script loads.

- " ;" inside a quoted string starts a comment in AHK v2 (write "`;").
- Unbalanced braces/parentheses.
Exits non-zero so the build and the release workflow stop.
"""
import re, sys

path = sys.argv[1]
src = open(path, encoding="utf-8").read()
lines = src.split("\n")
errors = []
in_cont = False
for i, l in enumerate(lines, 1):
    st = l.strip()
    if in_cont:
        if st.startswith(")"):
            in_cont = False
        continue
    if st.startswith("(") and not st.startswith("()"):
        in_cont = True
        continue
    q = None
    j = 0
    while j < len(l):
        c = l[j]
        if q:
            if c == "`":
                j += 2
                continue
            if c == q:
                q = None
            elif c == ";" and j > 0 and l[j - 1] in " \t":
                errors.append(f"line {i}: ' ;' inside a string starts a comment in AHK v2 - use '`;': {st}")
                break
        else:
            if c in "\"'":
                q = c
            elif c == ";" and (j == 0 or l[j - 1] in " \t"):
                break
        j += 1

t = re.sub(r'"(?:[^"`\n]|`.)*"', '""', src)
t = re.sub(r"'(?:[^'`\n]|`.)*'", "''", t)
t = re.sub(r"(^|\s);[^\n]*", "", t)
for a, b in ("{}", "()"):
    if t.count(a) != t.count(b):
        errors.append(f"unbalanced {a}{b}: {t.count(a)} vs {t.count(b)}")

for e in errors:
    print("lint:", e)
sys.exit(1 if errors else 0)
