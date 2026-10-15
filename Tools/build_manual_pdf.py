#!/usr/bin/env python3
"""マニュアル(manual/ja、manual/en)と、チュートリアル(tutorial/)を、1 冊の PDF にする。

使い方: python3 Tools/build_manual_pdf.py [--lang ja|en|all]
出力:   docs/assets/Glow65-Manual-ja.pdf、docs/assets/Glow65-Manual-en.pdf
必要:   pandoc、Google Chrome(ヘッドレスで印刷する)

第 1 部(マニュアル)と第 2 部(チュートリアル)を、章ごとに pandoc で HTML にして、表紙と目次を付けて 1 つの HTML にまとめ、Chrome で PDF にする。
章をまたぐリンクは、PDF の中のリンクに直す。言語の切り替えと、前後の章への案内の行は、PDF では省く。
"""
import argparse, html, os, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TMP = tempfile.TemporaryDirectory()   # 縮めた画像の置き場(実行のあいだだけ)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE = "https://github.com/Masakai/Glow65"
ORDER = ["01-history", "02-basics", "03-cpu", "04-addressing", "05-reference",
         "05-1-load-store", "05-2-transfer", "05-3-arithmetic", "05-4-logic-shift",
         "05-5-branch-jump", "05-6-stack-flags", "05-7-65c02",
         "06-flags-stack-interrupts", "07-memory-io",
         "08-glossary-index", "08-1-glossary", "08-2-index"]
TUTORIAL = [("tutorial-1", "README"), ("tutorial-2", "02-addition"), ("tutorial-3", "03-uart"),
            ("tutorial-4", "04-echo"), ("tutorial-5", "05-usr"), ("tutorial-6", "06-interrupts"),
            ("tutorial-7", "07-65c02")]


def source_path(lang, key, name):
    """章の元のファイル。マニュアルは manual/<lang>/<name>.md、チュートリアルは、日本語が <name>.ja.md、英語が <name>.md。"""
    if key.startswith("tutorial-"):
        return ROOT / "tutorial" / (f"{name}.ja.md" if lang == "ja" else f"{name}.md")
    return ROOT / "manual" / lang / f"{name}.md"


TEXT = {
    "ja": {"title": "Glow65 マニュアル", "sub": "6502 を読んで学ぶ、動かして学ぶ", "about": "このマニュアルについて", "toc": "目次",
           "part1": "第 1 部 マニュアル", "part2": "第 2 部 チュートリアル",
           "part2_text": "短いプログラムを Glow65 に入れて動かし、LED とモニタで結果を確かめます。第 1 部のマニュアルが、その背景にある仕組みを説明します。どちらから読んでもかまいません。サンプルのプログラム(`.s`)は、リポジトリの `tutorial` ディレクトリにあります。",
           "foot": "https://github.com/Masakai/Glow65", "lang": "ja"},
    "en": {"title": "Glow65 Manual", "sub": "Learn the 6502 by reading, and by running", "about": "About this manual", "toc": "Contents",
           "part1": "Part 1: Manual", "part2": "Part 2: Tutorial",
           "part2_text": "You load short programs into Glow65, run them, and check the result on the LEDs and in the monitor. The manual in Part 1 explains the ideas behind them. You can read either part first. The sample programs (`.s`) are in the `tutorial` directory of the repository.",
           "foot": "https://github.com/Masakai/Glow65", "lang": "en"},
}
CSS = """
@page { size: A4; margin: 20mm 17mm 22mm 17mm;
  @bottom-center { content: counter(page); font: 9pt 'Helvetica Neue', sans-serif; color: #666; } }
@page :first { @bottom-center { content: none; } }
html { font-size: 10pt; }
body { font-family: 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', 'Helvetica Neue', Arial, sans-serif;
  line-height: 1.75; color: #1b1d22; }
body.en { font-family: 'Helvetica Neue', Arial, 'Hiragino Sans', sans-serif; line-height: 1.6; }
h1, h2, h3, h4 { line-height: 1.4; break-after: avoid; }
section.chapter { break-before: page; }
section.chapter > h1:first-child { font-size: 20pt; border-bottom: 2px solid #c8321f; padding-bottom: 6pt; margin-top: 0; }
h2 { font-size: 14pt; margin-top: 22pt; border-left: 4px solid #c8321f; padding-left: 8pt; }
h3 { font-size: 11.5pt; margin-top: 16pt; }
p, li { orphans: 2; widows: 2; }
a { color: #1a5fb4; text-decoration: none; }
code { font-family: Menlo, 'Hiragino Sans', monospace; font-size: 0.88em; background: #f1f2f4; padding: 0 2pt; border-radius: 2pt; }
pre { background: #f6f7f9; border: 1px solid #dfe1e6; border-radius: 4pt; padding: 7pt 9pt; break-inside: avoid; white-space: pre-wrap; }
pre code { background: none; padding: 0; font-size: 8.8pt; line-height: 1.5; }
table { border-collapse: collapse; width: 100%; margin: 8pt 0; font-size: 8.8pt; }
th, td { border: 1px solid #cfd3da; padding: 3pt 5pt; vertical-align: top; }
th { background: #eceef2; }
tr { break-inside: avoid; }
blockquote { margin: 10pt 0; padding: 6pt 12pt; background: #fbf6f4; border-left: 4px solid #e0a396; break-inside: avoid; }
blockquote > p:first-child { margin-top: 0; } blockquote > p:last-child { margin-bottom: 0; }
img { max-width: 100%; height: auto; }
figure, p > img:only-child { break-inside: avoid; }
hr { border: none; border-top: 1px solid #ccc; margin: 14pt 0; }
.cover { height: 235mm; display: flex; flex-direction: column; justify-content: center; text-align: left; break-after: page; }
.cover h1 { font-size: 34pt; border: none; margin: 0 0 6pt 0; }
.cover .sub { font-size: 16pt; color: #555; margin-bottom: 40pt; }
.cover .meta { font-size: 10pt; color: #666; line-height: 1.8; }
.cover .bar { width: 70pt; height: 5pt; background: #c8321f; margin-bottom: 18pt; }
nav.toc h1 { font-size: 20pt; border-bottom: 2px solid #c8321f; padding-bottom: 6pt; }
nav.toc ul { list-style: none; padding-left: 0; margin: 0; }
nav.toc li.part { margin-top: 14pt; font-size: 12pt; font-weight: bold; color: #c8321f; border-bottom: 1px solid #e0a396; }
nav.toc li.l1 { margin-top: 7pt; font-weight: bold; }
nav.toc li.l2 { margin-left: 14pt; font-size: 9pt; font-weight: normal; line-height: 1.5; }
nav.toc { break-after: page; }
"""

NAV_STRIP = re.compile(r"\[[^\]]*\]\([^)]*\)|&nbsp;|·|次の章:|前の章:|次へ:|前へ:|Next chapter:|Previous chapter:|Next:|Previous:|\s|\|")


def is_nav_line(line):
    if not ("←" in line or "→" in line):
        return False
    return NAV_STRIP.sub("", line) == ""


def is_lang_line(line):
    if line.startswith("章: ") or line.startswith("Chapters: "):   # チュートリアルの、章の一覧の行
        return True
    return bool(re.match(r"^(\[(日本語|English)\]\([^)]*\)|\*\*(日本語|English)\*\*) \| (\[(日本語|English)\]\([^)]*\)|\*\*(日本語|English)\*\*)\s*$", line))


def clean_markdown(text, lang, src_dir, pathmap):
    out = []
    for line in text.splitlines():
        if is_lang_line(line) or is_nav_line(line) or line.startswith("PDF"):
            continue
        out.append(line)
    text = "\n".join(out)
    text = re.sub(r"\n---\n\s*\n*\Z", "\n", text.rstrip() + "\n")   # 末尾の区切り線(案内の行の前にあった)
    text = re.sub(r"\n{3,}", "\n\n", text)

    def fix(m):
        bang, label, target = m.group(1), m.group(2), m.group(3)
        if bang or re.match(r"^(https?:|mailto:|#)", target):
            return m.group(0)
        path, _, anchor = target.partition("#")
        resolved = Path(os.path.normpath(src_dir / path))
        if resolved in pathmap:                                  # PDF に入れる章への、リンク
            return f"{label}(xref:{pathmap[resolved]}--{anchor or 'top'})"
        if resolved.exists() or path.endswith(".md"):            # そのほかのファイルは、GitHub のページへ
            rel = resolved.relative_to(ROOT)
            kind = "tree" if resolved.is_dir() else "blob"
            return f"{label}({BASE}/{kind}/main/{rel}{'#' + anchor if anchor else ''})"
        return m.group(0)
    return re.sub(r"(!?)(\[[^\]]*\])\(([^)\s]+)\)", fix, text)


def prefix_ids(body, stem):
    """id と、同じファイルの中へのリンク(#...)に、章の名前を付ける。章をまたぐリンク(xref:)は、そのまま #... にする。"""
    body = re.sub(r'\bid="([^"]+)"', lambda m: f'id="{stem}--{m.group(1)}"', body)
    body = re.sub(r'href="#([^"]+)"', lambda m: f'href="#{stem}--{m.group(1)}"', body)
    return body.replace('href="xref:', 'href="#')


_shrunk = {}


def shrink(path):
    if path in _shrunk:
        return _shrunk[path]
    from PIL import Image
    im = Image.open(path)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        base = Image.new("RGB", im.size, "white")
        base.paste(im, mask=im.split()[-1])
        im = base
    else:
        im = im.convert("RGB")
    if im.width > 1400:
        im = im.resize((1400, round(im.height * 1400 / im.width)), Image.LANCZOS)
    out = Path(TMP.name) / (re.sub(r"[^A-Za-z0-9._-]", "_", path) + ".jpg")
    im.save(out, "JPEG", quality=86, optimize=True)
    _shrunk[path] = str(out)
    return str(out)


def render_chapter(key, src, lang, pathmap):
    text = clean_markdown(src.read_text(encoding="utf-8"), lang, src.parent, pathmap)
    body = subprocess.run(
        ["pandoc", "-f", "gfm", "-t", "html5", "--wrap=none"],
        input=text.encode("utf-8"), capture_output=True, check=True).stdout.decode("utf-8")
    body = prefix_ids(body, key)
    # 画像は、絶対パスにする。画面写真(PNG)は、サイズを抑えるため、幅 1400px 以内の JPEG にして使う
    def img(m):
        s = m.group(1)
        if re.match(r"^(https?:|data:)", s):
            return m.group(0)
        path = os.path.normpath(os.path.join(src.parent, s))
        if path.endswith(".png"):
            path = shrink(path)
        return 'src="file://%s"' % path
    body = re.sub(r'src="([^"]+)"', img, body)
    return f'<section class="chapter" id="{key}--top">\n{body}\n</section>'


def headings(section_html):
    items = []
    for m in re.finditer(r'<h([12]) id="([^"]+)">(.*?)</h\1>', section_html, re.S):
        level, hid, inner = int(m.group(1)), m.group(2), re.sub(r"<[^>]+>", "", m.group(3))
        items.append((level, hid, html.unescape(inner).strip()))
    return items


def build(lang):
    t = TEXT[lang]
    on_disk = {p.stem for p in (ROOT / "manual" / lang).glob("*.md")} - {"README"}
    missing, extra = on_disk - set(ORDER), set(ORDER) - on_disk
    if missing or extra:
        sys.exit(f"章の一覧と、manual/{lang} の中身が、一致しない: 足りない {sorted(extra)}、一覧にない {sorted(missing)}")
    manual = [(stem, source_path(lang, stem, stem)) for stem in ORDER]
    tutorial = [(key, source_path(lang, key, name)) for key, name in TUTORIAL]
    for key, path in manual + tutorial:
        if not path.exists():
            sys.exit(f"ファイルがない: {path}")
    pathmap = {Path(os.path.normpath(path)): key for key, path in manual + tutorial}
    manual_secs = [render_chapter(k, p, lang, pathmap) for k, p in manual]
    tutorial_secs = [render_chapter(k, p, lang, pathmap) for k, p in tutorial]

    # このマニュアルについて: README の、目次より前
    readme_path = ROOT / "manual" / lang / "README.md"
    intro = re.split(r"^## ", readme_path.read_text(encoding="utf-8"), maxsplit=1, flags=re.M)[0].split("\n", 1)[1]
    intro = clean_markdown(intro, lang, readme_path.parent, pathmap)
    intro_html = prefix_ids(subprocess.run(["pandoc", "-f", "gfm", "-t", "html5", "--wrap=none"],
                                input=intro.encode("utf-8"), capture_output=True, check=True).stdout.decode("utf-8"), "about")
    part2_html = prefix_ids(subprocess.run(["pandoc", "-f", "gfm", "-t", "html5", "--wrap=none"],
                                input=t["part2_text"].encode("utf-8"), capture_output=True, check=True).stdout.decode("utf-8"), "part2")

    toc = [f'<nav class="toc"><h1>{t["toc"]}</h1><ul>']
    toc.append(f'<li class="part"><a href="#about--top">{t["part1"]}</a></li>')
    toc.append(f'<li class="l1"><a href="#about--top">{t["about"]}</a></li>')
    for sec in manual_secs:
        for level, hid, text in headings(sec):
            toc.append(f'<li class="l{level}"><a href="#{hid}">{html.escape(text)}</a></li>')
    toc.append(f'<li class="part"><a href="#part2--top">{t["part2"]}</a></li>')
    for sec in tutorial_secs:
        for level, hid, text in headings(sec):
            toc.append(f'<li class="l{level}"><a href="#{hid}">{html.escape(text)}</a></li>')
    toc.append("</ul></nav>")

    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    date = subprocess.run(["date", "+%Y-%m-%d"], capture_output=True, text=True).stdout.strip()
    cover = (f'<div class="cover"><div class="bar"></div><h1>{t["title"]}</h1><div class="sub">{t["sub"]}</div>'
             f'<div class="meta">Glow65: a 6502 emulator for learning<br>{t["foot"]}<br>{date} / {commit}<br>MIT License</div></div>')
    about = f'<section class="chapter" id="about--top"><h1>{t["about"]}</h1>\n{intro_html}</section>'
    part2 = f'<section class="chapter" id="part2--top"><h1>{t["part2"]}</h1>\n{part2_html}</section>'

    doc = (f'<!doctype html><html lang="{t["lang"]}"><head><meta charset="utf-8"><title>{t["title"]}</title>'
           f"<style>{CSS}</style></head><body class=\"{lang}\">{cover}{''.join(toc)}{about}{''.join(manual_secs)}{part2}{''.join(tutorial_secs)}</body></html>")

    # リンクの確認: ページ内の #... が、すべて存在するか
    ids = set(re.findall(r'\bid="([^"]+)"', doc))
    broken = sorted({h for h in re.findall(r'href="#([^"]+)"', doc) if h not in ids})
    if broken:
        print(f"[{lang}] 壊れたページ内リンク {len(broken)} 件: {broken[:10]}", file=sys.stderr)

    out = ROOT / "docs" / "assets" / f"Glow65-Manual-{lang}.pdf"
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "manual.html"
        page.write_text(doc, encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                        "--allow-file-access-from-files", "--generate-pdf-document-outline", f"--print-to-pdf={out}", f"file://{page}"],
                       check=True, capture_output=True)
    # 圧縮し直して、サイズを減らす(qpdf があれば)。しおり(アウトライン)とリンクは、そのまま残る
    if subprocess.run(["which", "qpdf"], capture_output=True).returncode == 0:
        packed = out.with_suffix(".tmp.pdf")
        subprocess.run(["qpdf", "--object-streams=generate", "--compress-streams=y", "--recompress-flate",
                        "--compression-level=9", str(out), str(packed)], check=True)
        packed.replace(out)
    print(f"生成: {out} ({out.stat().st_size // 1024} KB, 壊れたリンク {len(broken)} 件)")
    return len(broken)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="all", choices=["ja", "en", "all"])
    a = ap.parse_args()
    bad = sum(build(l) for l in (["ja", "en"] if a.lang == "all" else [a.lang]))
    sys.exit(1 if bad else 0)
