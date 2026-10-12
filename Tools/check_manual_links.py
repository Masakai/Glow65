#!/usr/bin/env python3
"""manual/ja/*.md の相対リンクと見出しアンカーを検査する。

使い方:
    python3 Tools/check_manual_links.py            # 壊れたリンクを一覧する
    python3 Tools/check_manual_links.py --check    # 壊れたリンクがあれば終了コード 1
    python3 Tools/check_manual_links.py --anchors FILE   # FILE の見出しとアンカーを表示する

アンカーの規則は GitHub に合わせる: 小文字にし、英数字(日本語を含む)、ハイフン、下線、空白以外を除き、
空白をハイフンにする。同じアンカーが重なると、2 つ目から -1、-2 を付ける。
`<a id="...">` と `<a name="...">` も、アンカーとして扱う。標準ライブラリのみを使う。
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANUAL = os.path.join(ROOT, "manual", "ja")

LINK = re.compile(r"(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def strip_inline(text):
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("`", "").replace("*", "")
    return text.strip()


def slug(text):
    s = strip_inline(text).lower()
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")


def anchors_of(path, cache={}):
    if path in cache:
        return cache[path]
    result = set()
    seen = {}
    in_code = False
    for line in open(path, encoding="utf-8"):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", line)
        if m:
            base = slug(m.group(2))
            n = seen.get(base, 0)
            seen[base] = n + 1
            result.add(base if n == 0 else f"{base}-{n}")
        for a in re.findall(r'<a\s+(?:id|name)="([^"]+)"', line):
            result.add(a)
    cache[path] = result
    return result


def check_file(path):
    problems = []
    in_code = False
    for no, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        line_nocode = re.sub(r"`[^`]*`", "", line)
        for m in LINK.finditer(line_nocode):
            url = m.group(3)
            if re.match(r"^[a-z]+:", url):
                continue
            target, _, frag = url.partition("#")
            if target == "":
                dest = path
            else:
                dest = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(dest):
                problems.append((no, url, "ファイルがない"))
                continue
            if frag and dest.endswith(".md") and frag not in anchors_of(dest):
                problems.append((no, url, "アンカーがない"))
    return problems


def main():
    if "--anchors" in sys.argv:
        f = sys.argv[sys.argv.index("--anchors") + 1]
        seen = {}
        for line in open(f, encoding="utf-8"):
            m = re.match(r"^(#{1,6})\s+(.*?)\s*$", line)
            if m:
                print(f"{slug(m.group(2))}\t{m.group(2)}")
        return 0
    # --lang ja|en で言語を選ぶ。省略すると、存在するすべての言語を検査する
    langs = [sys.argv[sys.argv.index("--lang") + 1]] if "--lang" in sys.argv else ["ja", "en"]
    files = []
    for lang in langs:
        d = os.path.join(ROOT, "manual", lang)
        if os.path.isdir(d):
            files += sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".md"))
    total = 0
    for f in files:
        for no, url, why in check_file(f):
            print(f"{os.path.relpath(f, ROOT)}:{no}: {url} ({why})")
            total += 1
    print(f"{len(files)} ファイル、壊れたリンク {total} 件")
    return 1 if (total and "--check" in sys.argv) else 0


if __name__ == "__main__":
    sys.exit(main())
