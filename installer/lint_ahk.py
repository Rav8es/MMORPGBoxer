#!/usr/bin/env python3
"""Catch AutoHotkey v2 mistakes that only show up when the script loads.

- " ;" inside a quoted string starts a comment in AHK v2 (write "`;").
- Unbalanced braces/parentheses.
- A global used (directly or through the functions it calls) by start-up
  code that runs before the line that creates that global
  ("This global variable has not been assigned a value").
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

# ---- start-up order of globals ----
def strip(line):
    line = re.sub(r'"(?:[^"`\n]|`.)*"', '""', line)
    line = re.sub(r"'(?:[^'`\n]|`.)*'", "''", line)
    return re.sub(r"(^|\s);.*", "", line)

code = [strip(l) for l in lines]
# blank out continuation sections (literal text, e.g. the default config)
inside = False
for k, raw in enumerate(lines):
    st = raw.strip()
    if inside:
        code[k] = ""
        if st.startswith(")"):
            inside = False
            code[k] = st[1:]
        continue
    if st.startswith("(") and not st.startswith("()") and ")" not in st:
        inside = True
        code[k] = ""
funcs = {}          # name(lower) -> (start, end) line indexes of its body
top = []            # indexes of top-level lines
i = 0
in_cont = False
while i < len(code):
    l = code[i]
    st = lines[i].strip()
    if in_cont:
        if st.startswith(")"):
            in_cont = False
        i += 1
        continue
    if st.startswith("(") and not st.startswith("()"):
        in_cont = True
        i += 1
        continue
    m = re.match(r"^([A-Za-z_]\w*)\(.*\)\s*(\{|=>)", l)
    if m:
        name = m.group(1).lower()
        if m.group(2) == "=>":
            funcs[name] = (i, i)
            i += 1
            continue
        depth = 0
        j = i
        while j < len(code):
            depth += code[j].count("{") - code[j].count("}")
            if depth <= 0 and j > i or (depth == 0 and j == i and "}" in code[j]):
                break
            j += 1
        funcs[name] = (i, j)
        i = j + 1
        continue
    top.append(i)
    i += 1

globals_at = {}
for idx in top:
    for m in re.finditer(r"^global\s+(.*)$", code[idx]):
        for part in m.group(1).split(","):
            g = part.split(":=")[0].strip().lower()
            if re.match(r"^[a-z_]\w*$", g) and g not in globals_at:
                globals_at[g] = idx

def body(name):
    a, b = funcs[name]
    return "\n".join(code[a:b + 1])

calls_cache = {}
def calls(text):
    return {c.lower() for c in re.findall(r"(?<![.\w])([A-Za-z_]\w*)\(", text)} & set(funcs)

def reach(start):
    seen, todo = set(), list(start)
    while todo:
        f = todo.pop()
        if f in seen:
            continue
        seen.add(f)
        todo.extend(calls(body(f)) - seen)
    return seen

for idx in top:
    started = calls(code[idx])
    if not started:
        continue
    for f in reach(started):
        a, _ = funcs[f]
        text = re.sub(r"(?<![.\w?])[A-Za-z_]\w*\s*:(?!=)", " ", body(f))   # object-literal keys {name: ...}
        used = {w.lower() for w in re.findall(r"(?<![.\w])([A-Za-z_]\w*)\b", text)}
        for g in used & set(globals_at):
            if globals_at[g] > idx:
                errors.append(f"line {idx + 1} runs {f}() before line {globals_at[g] + 1} creates global {g}")

for e in sorted(set(errors)):
    print("lint:", e)
sys.exit(1 if errors else 0)
