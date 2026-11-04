"""Turn README.md into the HTML guide shipped with the app. Usage: make_html.py IN.md OUT.html"""
import markdown, re, sys
src = open(sys.argv[1], encoding='utf-8').read()
html = markdown.markdown(src, extensions=['tables', 'fenced_code', 'toc', 'sane_lists'])
css = '''body{font-family:"Segoe UI",Arial,sans-serif;max-width:980px;margin:32px auto;padding:0 24px;line-height:1.55;color:#1d2330;background:#fbfbfd}
h1{border-bottom:3px solid #d4aa3c;padding-bottom:8px}
h2{margin-top:2.2em;border-bottom:1px solid #dde;padding-bottom:4px;color:#16203a}
h3{margin-top:1.6em;color:#22305a}
code{background:#eef0f5;padding:1px 5px;border-radius:4px;font-family:Consolas,monospace;font-size:.92em}
pre{background:#161e30;color:#e9edf5;padding:12px 16px;border-radius:8px;overflow:auto}
pre code{background:none;color:inherit;padding:0}
table{border-collapse:collapse;margin:12px 0;width:100%}
th,td{border:1px solid #d5d9e3;padding:6px 10px;text-align:left;vertical-align:top}
th{background:#eef1f8}
tr:nth-child(even) td{background:#f7f8fb}
a{color:#1e5aa8}'''
page = (f'<!DOCTYPE html>\n<html lang="en"><head><meta charset="utf-8"><title>MMORPG Boxer - Guide</title>\n'
        f'<style>{css}</style></head><body>\n{html}\n</body></html>')
ids = set(re.findall(r'id="([^"]+)"', page))
bad = sorted(set(re.findall(r'href="#([^"]+)"', page)) - ids)
if bad:
    sys.exit('broken links in README: %s' % bad)
open(sys.argv[2], 'w', encoding='utf-8').write(page)
