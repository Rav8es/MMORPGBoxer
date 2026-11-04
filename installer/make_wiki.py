#!/usr/bin/env python3
"""Build GitHub wiki pages from README.md.

README.md stays the single source of the guide. This script splits it into one
wiki page per "## " section, writes Home.md (the README's introduction plus a
list of pages), _Sidebar.md and _Footer.md, and rewrites the README's
"#anchor" links so they point at the right page.

    python3 installer/make_wiki.py README.md wiki-out [owner/repo]
"""
import os
import re
import sys

README, OUT = sys.argv[1], sys.argv[2]
REPO = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("GITHUB_REPOSITORY", "Rav8es/MMORPGBoxer")
REPO_URL = f"https://github.com/{REPO}"


def slug(text):
    """GitHub's heading anchor."""
    text = text.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def page_name(title):
    """Wiki page name for a section title: no trailing '(...)', no commas."""
    name = re.sub(r"\s*\([^)]*\)\s*$", "", title)
    name = name.replace(",", "").replace("/", " ")
    name = re.sub(r"\s+", " ", name).strip()
    return name.replace(" ", "-")


def split_lines(text):
    """Yield (line, in_code_block)."""
    fence = False
    for line in text.split("\n"):
        if line.startswith("```"):
            fence = not fence
            yield line, True
            continue
        yield line, fence


src = open(README, encoding="utf-8").read().replace("\r\n", "\n")

# ---- split into the introduction and "## " sections -------------------------
intro, sections, cur = [], [], None
for line, code in split_lines(src):
    m = None if code else re.match(r"^## (.+)$", line)
    if m:
        cur = {"title": m.group(1).strip(), "lines": []}
        sections.append(cur)
    elif cur is None:
        intro.append(line)
    else:
        cur["lines"].append(line)

# Sections before "Contents" belong to Home; "Contents" itself is dropped.
home_sections, pages, seen_contents = [], [], False
for sec in sections:
    if sec["title"] == "Contents":
        seen_contents = True
        continue
    (pages if seen_contents else home_sections).append(sec)

for sec in pages:
    sec["page"] = page_name(sec["title"])
names = [p["page"] for p in pages]
assert len(set(names)) == len(names), f"two sections give the same page name: {names}"

# ---- which page holds each anchor -------------------------------------------
anchor_page = {}
for sec in home_sections:
    anchor_page[slug(sec["title"])] = ("Home", False)
    for line, code in split_lines("\n".join(sec["lines"])):
        m = None if code else re.match(r"^#{3,6} (.+)$", line)
        if m:
            anchor_page[slug(m.group(1))] = ("Home", False)
for sec in pages:
    anchor_page[slug(sec["title"])] = (sec["page"], True)
    for line, code in split_lines("\n".join(sec["lines"])):
        m = None if code else re.match(r"^#{3,6} (.+)$", line)
        if m:
            anchor_page.setdefault(slug(m.group(1)), (sec["page"], False))


def fix_links(text, here):
    def sub(m):
        label, anchor = m.group(1), m.group(2)
        if anchor not in anchor_page:
            raise SystemExit(f"link to #{anchor} on page {here}: no such heading")
        page, is_top = anchor_page[anchor]
        if page == here:
            return f"[{label}](#{anchor})"
        return f"[{label}]({page})" if is_top else f"[{label}]({page}#{anchor})"
    return re.sub(r"\[([^\]]+)\]\(#([^)\s]+)\)", sub, text)


def body(lines, here, promote):
    out = []
    for line, code in split_lines("\n".join(lines)):
        if not code:
            if promote:
                line = re.sub(r"^#(#{2,5}) ", r"\1 ", line)
            line = fix_links(line, here)
        out.append(line)
    text = "\n".join(out).strip("\n")
    # A page shouldn't end on the "---" rule that separated README sections.
    text = re.sub(r"\n+---\s*$", "", text)
    return text + "\n"


os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".md"):
        os.remove(os.path.join(OUT, f))

# ---- pages -------------------------------------------------------------------
for i, sec in enumerate(pages):
    nav = []
    if i > 0:
        nav.append(f"← [{pages[i - 1]['title']}]({pages[i - 1]['page']})")
    nav.append("[Home](Home)")
    if i + 1 < len(pages):
        nav.append(f"[{pages[i + 1]['title']}]({pages[i + 1]['page']}) →")
    text = body(sec["lines"], sec["page"], promote=True)
    text += "\n---\n" + " · ".join(nav) + "\n"
    with open(os.path.join(OUT, sec["page"] + ".md"), "w", encoding="utf-8") as f:
        f.write(text)

# ---- Home ----------------------------------------------------------------------
intro_text = "\n".join(intro)
# The wiki link in the README points here; point at the repository instead.
intro_text = re.sub(r"\*\*\[Guide \(wiki\)\]\([^)]*\)\*\*", f"**[Source code]({REPO_URL})**", intro_text)
home = [body(intro_text.split("\n"), "Home", promote=False)]
for sec in home_sections:
    home.append(f"## {sec['title']}\n" + body(sec["lines"], "Home", promote=False))
guide = ["## The guide"]
for sec in pages:
    subs = []
    for line, code in split_lines("\n".join(sec["lines"])):
        m = None if code else re.match(r"^### (.+)$", line)
        if m and not sec["title"].startswith("Configuration reference"):
            subs.append(f"[{m.group(1)}]({sec['page']}#{slug(m.group(1))})")
    entry = f"- **[{sec['title']}]({sec['page']})**"
    if subs:
        entry += ": " + " · ".join(subs)
    guide.append(entry)
home.append("\n".join(guide) + "\n")
with open(os.path.join(OUT, "Home.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(home))

# ---- sidebar and footer -----------------------------------------------------------
side = ["**[Home](Home)**", ""]
side += [f"- [{sec['title']}]({sec['page']})" for sec in pages]
side += ["", f"**[Download]({REPO_URL}/releases/latest)** · [What's new]({REPO_URL}/blob/main/CHANGELOG.md)"]
with open(os.path.join(OUT, "_Sidebar.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(side) + "\n")
with open(os.path.join(OUT, "_Footer.md"), "w", encoding="utf-8") as f:
    f.write(f"This wiki is made from [README.md]({REPO_URL}/blob/main/README.md) each time it changes, "
            f"so edits made here are replaced. [Download MMORPG Boxer]({REPO_URL}/releases/latest) · "
            f"[Report a problem]({REPO_URL}/issues)\n")

print(f"{len(pages) + 1} pages written to {OUT}")
