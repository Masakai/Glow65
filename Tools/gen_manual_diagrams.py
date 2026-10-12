#!/usr/bin/env python3
"""マニュアル第4章(アドレッシングモード)の図を SVG で生成する。

使い方: python3 Tools/gen_manual_diagrams.py
出力先: manual/ja/images/04-*.svg

図の例の値は、下の EX にまとめている。本文(manual/ja/04-addressing.md)の例と一致させること。
標準ライブラリのみを使う。
"""
import os
from xml.sax.saxutils import escape

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "manual", "ja", "images")

# 例の値(本文の実行例と一致させる)
EX = {
    "immediate": dict(opcode=0xA9, operand=0x10),
    "zeropage": dict(opcode=0xA5, zp=0x10, value=0x42),
    "zeropage-x": dict(opcode=0xB5, zp=0x10, x=0x05, value=0x77),
    "zeropage-y": dict(opcode=0xB6, zp=0x10, y=0x03, value=0x5A),
    "absolute": dict(opcode=0xAD, addr=0x0400, value=0x99),
    "absolute-x": dict(opcode=0xBD, addr=0x0410, x=0x05, value=0xC3),
    "absolute-y": dict(opcode=0xB9, addr=0x0420, y=0x02, value=0x3C),
    "indirect": dict(opcode=0x6C, ptr=0x0430, target=0x0340, pc_before=0x0300),
    "indexed-indirect": dict(opcode=0xA1, zp=0x20, x=0x04, target=0x0600, value=0x6E),
    "indirect-indexed": dict(opcode=0xB1, zp=0x30, y=0x03, base=0x0600, value=0x9D),
    "relative": dict(opcode=0xD0, offset=0x02, next_pc=0x0304),
    "implied": dict(opcode=0xE8, x_before=0x05, x_after=0x06),
    "accumulator": dict(opcode=0x0A, a_before=0x21, a_after=0x42),
}

W = 720
FONT = "-apple-system, 'Hiragino Sans', 'Noto Sans JP', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
INK = "#1f2328"
MUTED = "#57606a"
BOX = "#f6f8fa"
LINE = "#8c959f"
BLUE = "#0969da"
BLUE_BG = "#ddf4ff"
ORANGE = "#bc4c00"
ORANGE_BG = "#fff1e5"


def h2(v):
    return "$%02X" % v


def h4(v):
    return "$%04X" % v


class Scene:
    def __init__(self, title, desc, height):
        self.h = height
        self.parts = []
        self.title = title
        self.desc = desc

    def rect(self, x, y, w, h, fill=BOX, stroke=LINE, rx=4, sw=1.2):
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
        )

    def text(self, x, y, s, size=13, weight="normal", anchor="start", fill=INK, mono=False):
        fam = MONO if mono else FONT
        self.parts.append(
            f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" '
            f'fill="{fill}" font-family="{fam}">{escape(s)}</text>'
        )

    def arrow(self, pts, num=None, badge=None, color=BLUE):
        d = "M " + " L ".join(f"{x} {y}" for x, y in pts)
        marker = "ah" if color == BLUE else "ao"
        self.parts.append(
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2" marker-end="url(#{marker})"/>'
        )
        if num is not None:
            if badge is None:
                (x1, y1), (x2, y2) = pts[0], pts[1]
                badge = ((x1 + x2) / 2, (y1 + y2) / 2)
            bx, by = badge
            self.parts.append(f'<circle cx="{bx}" cy="{by}" r="10" fill="{color}"/>')
            self.parts.append(
                f'<text x="{bx}" y="{by + 4.5}" font-size="13" font-weight="bold" text-anchor="middle" '
                f'fill="#ffffff" font-family="{FONT}">{num}</text>'
            )

    def header(self, title, asm):
        self.text(30, 32, title, size=16, weight="bold")
        self.text(W - 30, 32, asm, size=16, weight="bold", anchor="end", fill=BLUE, mono=True)

    def bytes_row(self, items, hl_from=1):
        """命令のバイト列。items = [(値, ラベル)]。先頭がオペコード。戻り値は各ボックスの (x, y, w, h)。"""
        boxes = []
        for i, (val, label) in enumerate(items):
            x = 30 + i * 100
            hl = i >= hl_from
            self.text(x + 32, 60, label, size=11, anchor="middle", fill=MUTED)
            self.rect(x, 66, 64, 32, fill=BLUE_BG if hl else BOX, stroke=BLUE if hl else LINE)
            self.text(x + 32, 88, val, size=15, weight="bold", anchor="middle", mono=True)
            boxes.append((x, 66, 64, 32))
        return boxes

    def reg(self, name, y_center, value, hl=False, sub=None, w=110, x=30):
        h = 34
        y = y_center - h / 2
        fill, stroke = (ORANGE_BG, ORANGE) if hl else (BOX, LINE)
        self.rect(x, y, w, h, fill=fill, stroke=stroke, sw=2 if hl else 1.2)
        self.text(x + 10, y + 22, name, size=14, weight="bold")
        self.text(x + w - 10, y + 22, value, size=14, weight="bold", anchor="end", mono=True,
                  fill=ORANGE if hl else INK)
        if sub:
            self.text(x, y + h + 14, sub, size=11, fill=MUTED)
        return dict(l=(x, y_center), r=(x + w, y_center), t=(x + w / 2, y), b=(x + w / 2, y + h), y=y_center)

    def comp(self, x, y, w, lines, h=56):
        self.rect(x, y, w, h, fill="#ffffff", stroke=BLUE, rx=6, sw=1.6)
        n = len(lines)
        for i, s in enumerate(lines):
            self.text(x + w / 2, y + h / 2 + (i - (n - 1) / 2) * 18 + 5, s, size=13, anchor="middle", mono=True)
        return dict(l=(x, y + h / 2), r=(x + w, y + h / 2), t=(x + w / 2, y), b=(x + w / 2, y + h))

    def cell(self, x, y_center, addr, val, kind="normal", aw=80, vw=70):
        """メモリの 1 行。kind: normal / dim / target(青) / result(橙)。"""
        h = 28
        y = y_center - h / 2
        fill, stroke, sw = BOX, LINE, 1.2
        if kind == "target":
            fill, stroke, sw = BLUE_BG, BLUE, 2
        elif kind == "dim":
            fill, stroke = "#ffffff", "#d0d7de"
        txt = MUTED if kind == "dim" else INK
        self.rect(x, y, aw, h, fill=fill, stroke=stroke, sw=sw)
        self.rect(x + aw, y, vw, h, fill=fill, stroke=stroke, sw=sw)
        self.text(x + aw / 2, y + 19, addr, size=13, anchor="middle", mono=True, fill=txt)
        self.text(x + aw + vw / 2, y + 19, val, size=14, weight="bold", anchor="middle", mono=True, fill=txt)
        return dict(l=(x, y_center), r=(x + aw + vw, y_center), t=(x + (aw + vw) / 2, y),
                    b=(x + (aw + vw) / 2, y + h), y=y_center)

    def label(self, x, y, s, anchor="start"):
        self.text(x, y, s, size=11, anchor=anchor, fill=MUTED)

    def steps(self, y0, lines):
        y = y0
        for s in lines:
            if s.startswith("   "):
                self.text(52, y, s.strip(), size=13)
            else:
                self.text(30, y, s, size=13)
            y += 22
        return y

    def svg(self):
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{self.h}" viewBox="0 0 {W} {self.h}" '
            f'role="img" aria-labelledby="t d">\n'
            f'<title id="t">{escape(self.title)}</title>\n<desc id="d">{escape(self.desc)}</desc>\n'
            '<defs>'
            f'<marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto">'
            f'<path d="M0 0 L10 5 L0 10 z" fill="{BLUE}"/></marker>'
            f'<marker id="ao" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto">'
            f'<path d="M0 0 L10 5 L0 10 z" fill="{ORANGE}"/></marker>'
            '</defs>\n'
            f'<rect x="0.5" y="0.5" width="{W - 1}" height="{self.h - 1}" rx="10" fill="#ffffff" stroke="#d0d7de"/>\n'
        )
        return head + "\n".join(self.parts) + "\n</svg>\n"


def finish(sc, steps_y, steps, y0=None):
    end = sc.steps(y0 or steps_y, steps)
    sc.h = int(end + 8)


def build(name, title, desc, asm, builder, prefix="04"):
    sc = Scene(title, desc, 600)
    sc.header(title, asm)
    builder(sc)
    path = os.path.join(OUT_DIR, f"{prefix}-{name}.svg")
    with open(path, "w", encoding="utf-8") as f:
        f.write(sc.svg())
    return path


# ---- 各モードの図 ----

def s_implied(sc):
    e = EX["implied"]
    b = sc.bytes_row([(f"{e['opcode']:02X}", "オペコード")], hl_from=9)
    sc.reg("X", 200, f"{h2(e['x_before'])} → {h2(e['x_after'])}", hl=True, w=190)
    sc.arrow([(62, 98), (62, 183)], 1, badge=(62, 140))
    sc.text(300, 160, "オペランドはなく、メモリの内容は使わない。", size=13, fill=MUTED)
    finish(sc, 262, [
        f"① オペコード {h2(e['opcode'])}(INX)を読み、X の値に 1 を足す。X は {h2(e['x_before'])} から {h2(e['x_after'])} になる。",
    ])


def s_accumulator(sc):
    e = EX["accumulator"]
    sc.bytes_row([(f"{e['opcode']:02X}", "オペコード")], hl_from=9)
    sc.reg("A", 200, f"{h2(e['a_before'])} → {h2(e['a_after'])}", hl=True, w=190)
    sc.arrow([(62, 98), (62, 183)], 1, badge=(62, 140))
    sc.text(300, 160, "操作の対象は A そのもの。メモリの内容は使わない。", size=13, fill=MUTED)
    finish(sc, 262, [
        f"① オペコード {h2(e['opcode'])}(ASL A)を読み、A の各ビットを 1 つ左にずらす。A は {h2(e['a_before'])} から {h2(e['a_after'])} になる。",
    ])


def s_immediate(sc):
    e = EX["immediate"]
    sc.bytes_row([(f"{e['opcode']:02X}", "オペコード"), (f"{e['operand']:02X}", "オペランド(値)")])
    sc.label(30, 150, "レジスタ")
    sc.reg("A", 200, h2(e["operand"]), hl=True)
    sc.arrow([(135, 98), (135, 183)], 1, badge=(135, 140))
    sc.text(300, 160, "オペランドの値が、そのまま使われる。", size=13, fill=MUTED)
    sc.text(300, 182, "メモリの番地は使わない。", size=13, fill=MUTED)
    finish(sc, 262, [
        f"① オペコード {h2(e['opcode'])}(LDA #)と、オペランド {h2(e['operand'])} を読む。オペランドが値そのもの。",
        f"② A に {h2(e['operand'])} を入れる。",
    ])


def direct(sc, key, mode_hex, idx=None, asm_op="LDA", dest="A", two_byte=False, rows=None):
    """ゼロページ / アブソリュート系(間接なし)の共通の図。"""
    e = EX[key]
    if two_byte:
        addr = e["addr"]
        base = addr
        items = [(f"{e['opcode']:02X}", "オペコード"), (f"{addr & 0xFF:02X}", "オペランド(下位)"),
                 (f"{addr >> 8:02X}", "オペランド(上位)")]
        fmt = h4
    else:
        base = e["zp"]
        items = [(f"{e['opcode']:02X}", "オペコード"), (f"{base:02X}", "オペランド")]
        fmt = h2
    boxes = sc.bytes_row(items)
    ox = boxes[1][0]
    ocx = (ox + boxes[-1][0] + 64) / 2
    sc.label(30, 140, "レジスタ")
    sc.label(545, 112, "メモリ", anchor="middle")
    # 実効アドレス
    if idx:
        iv = e[idx.lower()]
        eff = base + iv
        if not two_byte:
            eff &= 0xFF
        lines = [f"{fmt(base)} + {idx}({h2(iv)})", f"= {h4(eff)}"]
        sc.reg(idx, 168, h2(iv))
    else:
        eff = base
        lines = [f"実効アドレス", f"{h4(eff)}"]
    comp = sc.comp(190, 140, 210, lines)
    sc.arrow([(ocx, 98), (ocx, 120), (comp["t"][0], 120), comp["t"]], 1, badge=(ocx, 112))
    n = 2
    if idx:
        sc.arrow([(140, 168), (190, 168)], n, badge=(165, 168))
        n += 1
    # メモリ
    rows = [("dim", eff - 1), ("target", eff), ("dim", eff + 1), ("dim", eff + 2)]
    ys = [134, 168, 202, 236]
    tcell = None
    for (kind, a), y in zip(rows, ys):
        if kind == "target":
            tcell = sc.cell(470, y, h4(a), h2(e["value"]), "target")
        else:
            sc.cell(470, y, h4(a), "..", "dim")
    sc.arrow([comp["r"], (470, 168)], n, badge=(435, 168))
    n += 1
    sc.reg(dest, 310, h2(e["value"]), hl=True)
    sc.arrow([(620, 168), (660, 168), (660, 310), (140, 310)], n, badge=(660, 240), color=ORANGE)
    # 手順
    steps = []
    steps.append(f"① オペコード {h2(e['opcode'])} と、オペランド {fmt(base)} を読む。")
    if idx:
        steps.append(f"② {idx} の値 {h2(e[idx.lower()])} を足して、実効アドレス {h4(eff)} を得る。")
        if not two_byte:
            steps.append("   ゼロページの計算は 256 バイトで折り返す($FF の次は $00)。")
        steps.append(f"③ {h4(eff)} の内容 {h2(e['value'])} を読む。")
        steps.append(f"④ {dest} に {h2(e['value'])} を入れる。")
    else:
        steps.append(f"   オペランドが、そのまま実効アドレス {h4(eff)} になる。")
        steps.append(f"② {h4(eff)} の内容 {h2(e['value'])} を読む。")
        steps.append(f"③ {dest} に {h2(e['value'])} を入れる。")
    finish(sc, 360, steps)


def s_zeropage(sc):
    direct(sc, "zeropage", "A5")


def s_zeropage_x(sc):
    direct(sc, "zeropage-x", "B5", idx="X")


def s_zeropage_y(sc):
    direct(sc, "zeropage-y", "B6", idx="Y", dest="X")


def s_absolute(sc):
    direct(sc, "absolute", "AD", two_byte=True)


def s_absolute_x(sc):
    direct(sc, "absolute-x", "BD", idx="X", two_byte=True)


def s_absolute_y(sc):
    direct(sc, "absolute-y", "B9", idx="Y", two_byte=True)


def s_indirect(sc):
    e = EX["indirect"]
    p = e["ptr"]
    boxes = sc.bytes_row([(f"{e['opcode']:02X}", "オペコード"), (f"{p & 0xFF:02X}", "オペランド(下位)"),
                          (f"{p >> 8:02X}", "オペランド(上位)")])
    ocx = (boxes[1][0] + boxes[2][0] + 64) / 2
    sc.label(30, 140, "レジスタ")
    sc.label(545, 112, "メモリ", anchor="middle")
    comp = sc.comp(190, 140, 210, ["ポインタの場所", h4(p)])
    sc.arrow([(ocx, 98), (ocx, 120), (comp["t"][0], 120), comp["t"]], 1, badge=(ocx, 112))
    lo = e["target"] & 0xFF
    hi = e["target"] >> 8
    sc.cell(470, 134, h4(p - 1), "..", "dim")
    c1 = sc.cell(470, 168, h4(p), h2(lo), "target")
    c2 = sc.cell(470, 202, h4(p + 1), h2(hi), "target")
    sc.cell(470, 236, h4(p + 2), "..", "dim")
    sc.arrow([comp["r"], (470, 168)], 2, badge=(435, 168))
    sc.reg("PC", 310, h4(e["target"]), hl=True, sub=None)
    sc.arrow([(620, 202), (660, 202), (660, 310), (140, 310)], 3, badge=(660, 260), color=ORANGE)
    sc.label(140, 330, "")
    finish(sc, 360, [
        f"① オペコード {h2(e['opcode'])}(JMP)と、オペランド {h4(p)} を読む。{h4(p)} は、飛び先を収めた場所。",
        f"② {h4(p)} の {h2(lo)} を下位、{h4(p + 1)} の {h2(hi)} を上位として読む。",
        f"③ 2 バイトを合わせた {h4(e['target'])} が PC に入る。次はこの番地の命令を実行する。",
    ])


def s_indexed_indirect(sc):
    e = EX["indexed-indirect"]
    zp, x = e["zp"], e["x"]
    ptr = (zp + x) & 0xFF
    t = e["target"]
    sc.bytes_row([(f"{e['opcode']:02X}", "オペコード"), (f"{zp:02X}", "オペランド")])
    sc.label(30, 140, "レジスタ")
    sc.label(396, 112, "ゼロページ", anchor="middle")
    sc.label(586, 112, "メモリ", anchor="middle")
    sc.reg("X", 168, h2(x))
    comp = sc.comp(160, 140, 130, [f"{h2(zp)} + X({h2(x)})", f"= {h2(ptr)}"])
    sc.arrow([(162, 98), (162, 120), (225, 120), comp["t"]], 1, badge=(162, 112))
    sc.arrow([(140, 168), (160, 168)], 2, badge=(150, 168))
    sc.cell(330, 168, h4(ptr), h2(t & 0xFF), "target", aw=72, vw=60)
    c2 = sc.cell(330, 202, h4(ptr + 1), h2(t >> 8), "target", aw=72, vw=60)
    sc.arrow([comp["r"], (330, 168)], 3, badge=(310, 168))
    tc = sc.cell(520, 270, h4(t), h2(e["value"]), "target", aw=72, vw=60)
    sc.arrow([(462, 202), (491, 202), (491, 270), (520, 270)], 4, badge=(491, 236))
    sc.reg("A", 310, h2(e["value"]), hl=True)
    sc.arrow([(652, 270), (685, 270), (685, 310), (140, 310)], 5, badge=(685, 292), color=ORANGE)
    finish(sc, 360, [
        f"① オペコード {h2(e['opcode'])}(LDA)と、オペランド {h2(zp)} を読む。",
        f"② オペランドに X の値 {h2(x)} を足して、ゼロページの場所 {h2(ptr)} を得る(256 バイトで折り返す)。",
        f"③ {h4(ptr)} の {h2(t & 0xFF)} を下位、{h4(ptr + 1)} の {h2(t >> 8)} を上位として読む。",
        f"④ 2 バイトを合わせた {h4(t)} が実効アドレスになる。",
        f"⑤ {h4(t)} の内容 {h2(e['value'])} を読んで、A に入れる。",
    ])


def s_indirect_indexed(sc):
    e = EX["indirect-indexed"]
    zp, y, b = e["zp"], e["y"], e["base"]
    eff = b + y
    sc.bytes_row([(f"{e['opcode']:02X}", "オペコード"), (f"{zp:02X}", "オペランド")])
    sc.label(30, 140, "レジスタ")
    sc.label(396, 112, "ゼロページ", anchor="middle")
    sc.label(586, 112, "メモリ", anchor="middle")
    comp1 = sc.comp(160, 140, 130, ["ポインタの場所", h2(zp)])
    sc.arrow([(162, 98), (162, 120), (225, 120), comp1["t"]], 1, badge=(162, 112))
    sc.cell(330, 168, h4(zp), h2(b & 0xFF), "target", aw=72, vw=60)
    sc.cell(330, 202, h4(zp + 1), h2(b >> 8), "target", aw=72, vw=60)
    sc.arrow([comp1["r"], (330, 168)], 2, badge=(310, 168))
    sc.reg("Y", 276, h2(y))
    comp2 = sc.comp(330, 250, 132, [f"{h4(b)} + Y({h2(y)})", f"= {h4(eff)}"], h=52)
    sc.arrow([(396, 216), (396, 250)], 3, badge=(416, 233))
    sc.arrow([(140, 276), (330, 276)], 4, badge=(235, 276))
    tc = sc.cell(520, 276, h4(eff), h2(e["value"]), "target", aw=72, vw=60)
    sc.arrow([comp2["r"], (520, 276)], 5, badge=(491, 276))
    sc.reg("A", 335, h2(e["value"]), hl=True)
    sc.arrow([(652, 276), (685, 276), (685, 335), (140, 335)], 6, badge=(685, 305), color=ORANGE)
    finish(sc, 360, [
        f"① オペコード {h2(e['opcode'])}(LDA)と、オペランド {h2(zp)} を読む。",
        f"② {h4(zp)} の {h2(b & 0xFF)} を下位、{h4(zp + 1)} の {h2(b >> 8)} を上位として読み、基準の番地 {h4(b)} を得る。",
        f"③④ 基準の番地に Y の値 {h2(y)} を足して、実効アドレス {h4(eff)} を得る。",
        f"⑤⑥ {h4(eff)} の内容 {h2(e['value'])} を読んで、A に入れる。",
    ], y0=385)


def s_relative(sc):
    e = EX["relative"]
    npc = e["next_pc"]
    off = e["offset"]
    tgt = npc + off
    sc.bytes_row([(f"{e['opcode']:02X}", "オペコード"), (f"{off:02X}", "オペランド(距離)")])
    sc.label(30, 140, "レジスタ")
    sc.reg("PC", 168, h4(npc), sub="命令を読み終えた位置")
    comp = sc.comp(190, 140, 210, [f"{h4(npc)} + {h2(off)}", f"= {h4(tgt)}"])
    sc.arrow([(162, 98), (162, 120), (295, 120), comp["t"]], 1, badge=(162, 112))
    sc.arrow([(140, 168), (190, 168)], 2, badge=(165, 168))
    sc.reg("PC", 310, h4(tgt), hl=True)
    sc.arrow([(295, 196), (295, 310), (140, 310)], 3, badge=(295, 250), color=ORANGE)
    sc.text(440, 160, "分岐の条件が成り立つときだけ、", size=13, fill=MUTED)
    sc.text(440, 182, "PC を書き換える。", size=13, fill=MUTED)
    finish(sc, 360, [
        f"① オペコード {h2(e['opcode'])}(BNE)と、距離 {h2(off)} を読む。距離は符号付きの 1 バイト。",
        f"② 命令を読み終えた PC は {h4(npc)}。ここに距離を足す。",
        f"③ 条件が成り立つとき、PC は {h4(tgt)} になる。成り立たないときは {h4(npc)} のまま。",
    ])


MODES = [
    ("implied", "インプライド(Implied)", "オペランドを持たず、メモリの内容を使わない。例は INX。", "INX", s_implied),
    ("accumulator", "アキュムレータ(Accumulator)", "操作の対象が A レジスタ自身。例は ASL A。", "ASL A", s_accumulator),
    ("immediate", "イミディエイト(Immediate)", "オペランドの値が、そのまま使われる。例は LDA #$10。", "LDA #$10", s_immediate),
    ("zeropage", "ゼロページ(Zero Page)", "1 バイトのオペランドで、先頭 256 バイトの番地を指定する。例は LDA $10。", "LDA $10", s_zeropage),
    ("zeropage-x", "ゼロページ X(Zero Page,X)", "オペランドに X の値を足した、ゼロページの番地を使う。例は LDA $10,X。", "LDA $10,X", s_zeropage_x),
    ("zeropage-y", "ゼロページ Y(Zero Page,Y)", "オペランドに Y の値を足した、ゼロページの番地を使う。例は LDX $10,Y。", "LDX $10,Y", s_zeropage_y),
    ("absolute", "アブソリュート(Absolute)", "2 バイトのオペランドで、64KB のどの番地でも指定する。例は LDA $0400。", "LDA $0400", s_absolute),
    ("absolute-x", "アブソリュート X(Absolute,X)", "2 バイトのオペランドに X の値を足した番地を使う。例は LDA $0410,X。", "LDA $0410,X", s_absolute_x),
    ("absolute-y", "アブソリュート Y(Absolute,Y)", "2 バイトのオペランドに Y の値を足した番地を使う。例は LDA $0420,Y。", "LDA $0420,Y", s_absolute_y),
    ("indirect", "インダイレクト(Indirect)", "オペランドの番地に収めた 2 バイトを、飛び先として使う。JMP だけのモード。例は JMP ($0430)。", "JMP ($0430)", s_indirect),
    ("indexed-indirect", "インデックスト・インダイレクト(Indexed Indirect)", "ゼロページの表から、X 番目の 2 バイトの番地を取り出す。例は LDA ($20,X)。", "LDA ($20,X)", s_indexed_indirect),
    ("indirect-indexed", "インダイレクト・インデックスト(Indirect Indexed)", "ゼロページの 2 バイトの番地に Y の値を足した番地を使う。例は LDA ($30),Y。", "LDA ($30),Y", s_indirect_indexed),
    ("relative", "リラティブ(Relative)", "分岐命令で、次の命令からの距離(符号付き 1 バイト)を足した番地へ飛ぶ。例は BNE。", "BNE +2", s_relative),
]


# ---- 第5章(命令リファレンス)の図 ----

def bitbox(sc, x, y, text, w=44, h=34, hl=None, size=15):
    fill, stroke, sw = BOX, LINE, 1.2
    if hl == "blue":
        fill, stroke, sw = BLUE_BG, BLUE, 2
    elif hl == "orange":
        fill, stroke, sw = ORANGE_BG, ORANGE, 2
    sc.rect(x, y, w, h, fill=fill, stroke=stroke, sw=sw)
    sc.text(x + w / 2, y + h / 2 + 5, text, size=size, weight="bold", anchor="middle", mono=True)


def shift_row(sc, y0, kind, a, carry_in):
    """ASL / LSR / ROL / ROR の 1 行。a は実行前の A、carry_in は実行前の C。"""
    bx0, bw, pitch = 190, 44, 48
    bits = [(a >> (7 - i)) & 1 for i in range(8)]  # 左から b7..b0
    xs = [bx0 + i * pitch for i in range(8)]
    left_c = kind in ("ASL", "ROL")
    cx = 110 if left_c else 582
    zx = 582 if kind == "ASL" else 110  # 0 を入れる箱(ASL は右、LSR は左)
    sc.text(30, y0 + 24, kind, size=18, weight="bold", mono=True, fill=BLUE)
    # C の箱
    bitbox(sc, cx, y0, ("C " + str(carry_in)) if kind in ("ROL", "ROR") else "C", w=52)
    for x, b in zip(xs, bits):
        bitbox(sc, x, y0, str(b), hl="blue")
    # 結果の計算
    if kind == "ASL":
        r, c = (a << 1) & 0xFF, a >> 7
    elif kind == "LSR":
        r, c = a >> 1, a & 1
    elif kind == "ROL":
        r, c = ((a << 1) & 0xFF) | carry_in, a >> 7
    else:
        r, c = (a >> 1) | (carry_in << 7), a & 1
    mid = y0 + 17
    if kind == "ASL":
        top_x = xs[0] + bw / 2
        sc.arrow([(top_x, y0), (top_x, y0 - 14), (cx + 26, y0 - 14), (cx + 26, y0)], None, color=BLUE)
        bitbox(sc, zx, y0, "0", w=36)
        sc.arrow([(zx, mid), (xs[7] + bw, mid)], None, color=BLUE)
    elif kind == "LSR":
        top_x = xs[7] + bw / 2
        sc.arrow([(top_x, y0), (top_x, y0 - 14), (cx + 26, y0 - 14), (cx + 26, y0)], None, color=BLUE)
        bitbox(sc, zx, y0, "0", w=36)
        sc.arrow([(zx + 36, mid), (xs[0], mid)], None, color=BLUE)
    elif kind == "ROL":
        top_x = xs[0] + bw / 2
        sc.arrow([(top_x, y0), (top_x, y0 - 14), (cx + 26, y0 - 14), (cx + 26, y0)], None, color=BLUE)
        sc.arrow([(cx + 26, y0 + 34), (cx + 26, y0 + 50), (xs[7] + bw / 2, y0 + 50), (xs[7] + bw / 2, y0 + 34)], None, color=BLUE)
    else:
        top_x = xs[7] + bw / 2
        sc.arrow([(top_x, y0), (top_x, y0 - 14), (cx + 26, y0 - 14), (cx + 26, y0)], None, color=BLUE)
        sc.arrow([(cx + 26, y0 + 34), (cx + 26, y0 + 50), (xs[0] + bw / 2, y0 + 50), (xs[0] + bw / 2, y0 + 34)], None, color=BLUE)
    rb = format(r, "08b")
    sc.text(30, y0 + 70, f"実行後: A = %{rb[:4]} {rb[4:]}({h2(r)})、C = {c}", size=13, mono=False)
    return r, c


def f5_shift(sc):
    a = 0xB1
    for i in range(8):
        sc.label(190 + i * 48 + 22, 90, f"b{7 - i}", anchor="middle")
    sc.text(30, 56, f"実行前: A = %10110001({h2(a)})。ROL と ROR は、実行前の C が 1 の場合", size=13)
    ys = [130, 250, 370, 490]
    for y0, kind in zip(ys, ["ASL", "LSR", "ROL", "ROR"]):
        shift_row(sc, y0, kind, a, 1)
    sc.h = 610


def stack_panel(sc, dy, kind):
    """PHA / PLA の 1 面。SP = $FD、A = $42 の例。"""
    sc.text(30, dy + 24, "PHA" if kind == "PHA" else "PLA", size=16, weight="bold", mono=True, fill=BLUE)
    sc.label(545, dy + 30, "スタック(メモリ)", anchor="middle")
    ys = {0x1FE: dy + 56, 0x1FD: dy + 92, 0x1FC: dy + 128}
    cells = {}
    if kind == "PHA":
        sc.cell(470, ys[0x1FE], h4(0x1FE), "..", "dim", aw=72, vw=60)
        cells[0x1FD] = sc.cell(470, ys[0x1FD], h4(0x1FD), "$42", "target", aw=72, vw=60)
        sc.cell(470, ys[0x1FC], h4(0x1FC), "..", "dim", aw=72, vw=60)
        sc.reg("A", dy + 92, "$42")
        sc.reg("SP", dy + 150, "$FD → $FC", hl=True, w=140)
        sc.arrow([(140, dy + 92), (470, dy + 92)], 1, badge=(300, dy + 92))
        sc.arrow([(170, dy + 150), (310, dy + 150), (310, dy + 128), (470, dy + 128)], 2, badge=(240, dy + 150), color=ORANGE)
        sc.steps(dy + 186, [
            "① SP が指す番地 $01FD(= $0100 + $FD)に、A の値 $42 を書く。",
            "② SP から 1 を引く。SP は $FD から $FC になり、次の書き込みは $01FC になる。",
        ])
    else:
        sc.cell(470, ys[0x1FE], h4(0x1FE), "..", "dim", aw=72, vw=60)
        cells[0x1FD] = sc.cell(470, ys[0x1FD], h4(0x1FD), "$42", "target", aw=72, vw=60)
        sc.cell(470, ys[0x1FC], h4(0x1FC), "..", "dim", aw=72, vw=60)
        sc.reg("A", dy + 92, "$42", hl=True)
        sc.reg("SP", dy + 150, "$FC → $FD", hl=True, w=140)
        sc.arrow([(170, dy + 150), (310, dy + 150), (310, dy + 128), (470, dy + 128)], 1, badge=(240, dy + 150))
        sc.arrow([(470, dy + 92), (140, dy + 92)], 2, badge=(300, dy + 92), color=ORANGE)
        sc.steps(dy + 186, [
            "① SP に 1 を足す。SP は $FC から $FD になる。",
            "② SP が指す番地 $01FD の内容 $42 を読んで、A に入れる。",
        ])


def f5_stack(sc):
    stack_panel(sc, 50, "PHA")
    stack_panel(sc, 290, "PLA")
    sc.h = 560


def f5_jsr_rts(sc):
    # JSR($0300 にある 3 バイトの命令)
    boxes = sc.bytes_row([("20", "オペコード"), ("40", "オペランド(下位)"), ("03", "オペランド(上位)")])
    for i, a in enumerate(["$0300", "$0301", "$0302"]):
        sc.label(boxes[i][0] + 32, 114, a, anchor="middle")
    sc.reg("PC", 150, "$0340", hl=True, x=470)
    sc.arrow([(358, 82), (410, 82), (410, 150), (470, 150)], 4, badge=(410, 110), color=ORANGE)
    sc.reg("PC", 190, "$0303", sub="3 バイト読み終えた位置")
    comp = sc.comp(250, 162, 170, ["PC − 1", "= $0302"])
    sc.arrow([(140, 190), (250, 190)], 1, badge=(195, 190))
    sc.label(555, 214, "スタック", anchor="middle")
    sc.cell(470, 240, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, 276, h4(0x1FC), "$02", "target", aw=72, vw=60)
    sc.cell(470, 312, h4(0x1FB), "..", "dim", aw=72, vw=60)
    sc.arrow([(420, 176), (445, 176), (445, 240), (470, 240)], 2, badge=(432, 176))
    sc.arrow([(420, 202), (445, 202), (445, 276), (470, 276)], 3, badge=(432, 202))
    sc.reg("SP", 300, "$FD → $FB", hl=True, w=140)
    sc.steps(350, [
        "① 3 バイトを読み終えた PC は $0303。",
        "② ③ PC から 1 を引いた $0302 を、上位($03)、下位($02)の順に積む。$0302 は、JSR の最後のバイトの番地。",
        "④ PC はオペランドの $0340 になる。SP は 2 減って $FB になる。",
    ])
    # RTS
    dy = 470
    sc.text(30, dy + 8, "RTS", size=16, weight="bold", mono=True, fill=BLUE)
    sc.label(555, dy + 20, "スタック", anchor="middle")
    sc.cell(470, dy + 40, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, dy + 76, h4(0x1FC), "$02", "target", aw=72, vw=60)
    sc.cell(470, dy + 112, h4(0x1FB), "..", "dim", aw=72, vw=60)
    sc.reg("SP", dy + 76, "$FB → $FD", hl=True, w=140)
    sc.comp(250, dy + 48, 170, ["$0302 + 1", "= $0303"])
    sc.arrow([(470, dy + 76), (445, dy + 76), (445, dy + 90), (420, dy + 90)], 1, badge=(458, dy + 76))
    sc.arrow([(470, dy + 40), (445, dy + 40), (445, dy + 62), (420, dy + 62)], 2, badge=(458, dy + 40))
    sc.reg("PC", dy + 140, "$0303", hl=True)
    sc.arrow([(335, dy + 104), (335, dy + 140), (140, dy + 140)], 3, badge=(250, dy + 140), color=ORANGE)
    sc.steps(dy + 180, [
        "① ② SP に 1 ずつ足しながら、下位($02)、上位($03)の順に取り出し、$0302 を作る。",
        "③ 1 を足した $0303 を PC に入れる。$0303 は、JSR の次の命令の番地。",
    ])
    sc.h = dy + 224


def f5_brk_rti(sc):
    # BRK($0302 にある)
    boxes = sc.bytes_row([("00", "オペコード"), ("99", "署名バイト(使われない)")], hl_from=9)
    sc.label(boxes[0][0] + 32, 114, "$0302", anchor="middle")
    sc.label(boxes[1][0] + 32, 114, "$0303", anchor="middle")
    sc.reg("PC", 168, "$0304")
    sc.reg("P", 222, "$24")
    sc.label(555, 130, "スタック", anchor="middle")
    sc.cell(470, 150, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, 186, h4(0x1FC), "$04", "target", aw=72, vw=60)
    sc.cell(470, 222, h4(0x1FB), "$34", "target", aw=72, vw=60)
    sc.arrow([(140, 168), (430, 168), (430, 150), (470, 150)], 1, badge=(300, 168))
    sc.arrow([(430, 168), (430, 186), (470, 186)], None)
    sc.arrow([(140, 222), (470, 222)], 2, badge=(300, 222))
    sc.label(555, 266, "割り込みベクタ", anchor="middle")
    sc.cell(470, 292, h4(0xFFFE), "下位", "normal", aw=72, vw=60)
    sc.cell(470, 328, h4(0xFFFF), "上位", "normal", aw=72, vw=60)
    sc.reg("PC", 310, "ベクタの番地", hl=True, w=170)
    sc.arrow([(470, 310), (200, 310)], 3, badge=(335, 310), color=ORANGE)
    sc.steps(365, [
        "① PC の $0304 を、上位($03)、下位($04)の順に積む。署名バイトの次の番地。",
        "② P を積む。B(ビット 4)とビット 5 は 1 にして積む($24 は $34 になる)。",
        "③ I を 1 にして、$FFFE(下位)と $FFFF(上位)の番地を PC に入れる。",
    ])
    dy = 480
    sc.text(30, dy + 8, "RTI", size=16, weight="bold", mono=True, fill=BLUE)
    sc.label(555, dy + 20, "スタック", anchor="middle")
    sc.cell(470, dy + 40, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, dy + 76, h4(0x1FC), "$04", "target", aw=72, vw=60)
    sc.cell(470, dy + 112, h4(0x1FB), "$34", "target", aw=72, vw=60)
    sc.reg("P", dy + 112, "$34 → $24", hl=True, w=140)
    sc.reg("PC", dy + 58, "$0304", hl=True)
    sc.arrow([(470, dy + 112), (170, dy + 112)], 1, badge=(320, dy + 112), color=ORANGE)
    sc.arrow([(470, dy + 58), (140, dy + 58)], 2, badge=(300, dy + 58), color=ORANGE)
    sc.steps(dy + 160, [
        "① P を取り出す。B は取り込まず、ビット 5 は 1 にする。",
        "② PC の下位($04)、上位($03)の順に取り出す。RTS と違って、1 を足さない。",
    ])
    sc.h = dy + 205


def branch_panel(sc, x0, title, rows, bi, ti, offtxt):
    """rows: [(addr, bytes, asm, kind)]。bi は分岐の行、ti は飛び先の行。"""
    sc.text(x0, 64, title, size=14, weight="bold")
    ys = [100 + i * 38 for i in range(len(rows))]
    for (addr, bs, asm, kind), y in zip(rows, ys):
        fill, stroke, sw = BOX, LINE, 1.2
        if kind == "branch":
            fill, stroke, sw = BLUE_BG, BLUE, 2
        elif kind == "target":
            fill, stroke, sw = ORANGE_BG, ORANGE, 2
        elif kind == "dim":
            fill, stroke = "#ffffff", "#d0d7de"
        sc.rect(x0, y - 15, 64, 30, fill=fill, stroke=stroke, sw=sw)
        sc.rect(x0 + 64, y - 15, 84, 30, fill=fill, stroke=stroke, sw=sw)
        sc.rect(x0 + 148, y - 15, 112, 30, fill=fill, stroke=stroke, sw=sw)
        tc = MUTED if kind == "dim" else INK
        sc.text(x0 + 32, y + 5, addr, size=13, anchor="middle", mono=True, fill=tc)
        sc.text(x0 + 106, y + 5, bs, size=13, anchor="middle", mono=True, fill=tc)
        sc.text(x0 + 204, y + 5, asm, size=13, anchor="middle", mono=True, fill=tc, weight="bold")
    xr = x0 + 260
    sc.arrow([(xr, ys[bi]), (xr + 24, ys[bi]), (xr + 24, ys[ti]), (xr, ys[ti])], 1, badge=(xr + 24, (ys[bi] + ys[ti]) / 2), color=ORANGE)
    sc.text(x0, ys[-1] + 34, offtxt, size=13)


def f5_branch(sc):
    branch_panel(sc, 30, "前へ分岐(距離 +2)", [
        ("$0302", "D0 02", "BNE $0306", "branch"),
        ("$0304", "A9 EE", "LDA #$EE", "dim"),
        ("$0306", "8D F0 03", "STA $03F0", "target"),
    ], 0, 2, "次の命令 $0304 + $02 = $0306")
    branch_panel(sc, 380, "後ろへ分岐(距離 −3)", [
        ("$0302", "CA", "DEX", "target"),
        ("$0303", "D0 FD", "BNE $0302", "branch"),
        ("$0305", "8E F0 03", "STX $03F0", "dim"),
    ], 1, 0, "次の命令 $0305 + $FD(−3) = $0302")
    sc.steps(250, [
        "距離は、分岐命令の次の命令の番地から測る。$FD は、符号付きの 8 ビットで −3。",
        "条件が成り立たないとき、PC は次の命令に進む。成り立つときだけ、PC に距離を足す。",
    ])
    sc.h = 310


def f5_bit(sc):
    m = 0xC0
    a = 0x01
    sc.text(30, 56, f"BIT $0400(メモリの内容 {h2(m)}、A = {h2(a)} の例)", size=14, weight="bold")
    xs = [30 + i * 48 for i in range(8)]
    for i, x in enumerate(xs):
        sc.label(x + 22, 76, f"b{7 - i}", anchor="middle")
        bitbox(sc, x, 82, str((m >> (7 - i)) & 1), hl="blue" if i < 2 else None)
    sc.label(30, 134, "メモリ $0400 の内容", anchor="start")
    bitbox(sc, xs[0], 190, "N = 1", w=44, hl="orange", size=13)
    bitbox(sc, xs[1], 190, "V = 1", w=44, hl="orange", size=13)
    sc.arrow([(xs[0] + 22, 116), (xs[0] + 22, 190)], 1, badge=(xs[0] + 22, 160))
    sc.arrow([(xs[1] + 22, 116), (xs[1] + 22, 190)], 2, badge=(xs[1] + 22, 160))
    sc.text(xs[0], 250, "ビット 7 → N、ビット 6 → V", size=12, fill=MUTED)
    sc.reg("A", 99, h2(a), x=500)
    sc.comp(440, 170, 220, ["A AND M", f"{h2(a)} AND {h2(m)} = $00"])
    sc.arrow([(414, 99), (470, 99), (470, 170)], 3, badge=(442, 99))
    sc.arrow([(555, 116), (555, 170)], 4, badge=(555, 143))
    bitbox(sc, 520, 250, "Z = 1", w=60, hl="orange", size=13)
    sc.arrow([(550, 226), (550, 250)], 5, badge=(550, 238), color=ORANGE)
    sc.steps(310, [
        "① ② メモリの内容のビット 7 が N に、ビット 6 が V に、そのまま写る。",
        "③ ④ A とメモリの内容を AND する。結果そのものは捨てて、A は変わらない。",
        "⑤ AND の結果が 0 なら、Z を 1 にする。",
    ])
    sc.h = 396


REF = [
    ("shift", "ビットの動き(ASL、LSR、ROL、ROR)", "ASL、LSR、ROL、ROR が、A の 8 ビットとキャリーをどう動かすか。", "", f5_shift),
    ("stack", "スタック(PHA と PLA)", "PHA が SP の指す番地に A を書いて SP を 1 減らし、PLA が SP を 1 増やして A に読むこと。", "", f5_stack),
    ("jsr-rts", "JSR と RTS", "JSR が戻り番地(最後のバイトの番地)を積み、RTS が 1 を足して戻ること。", "", f5_jsr_rts),
    ("brk-rti", "BRK と RTI", "BRK が PC と P を積んでベクタへ飛び、RTI が P と PC を取り出して戻ること。", "", f5_brk_rti),
    ("branch", "分岐の飛び先", "分岐命令の距離は、次の命令の番地から測ること。前へも後ろへも分岐できること。", "", f5_branch),
    ("bit", "BIT のフラグ", "BIT がメモリの上位 2 ビットを N と V に写し、A との AND で Z を決めること。", "", f5_bit),
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, title, desc, asm, fn in MODES:
        p = build(name, title, desc, asm, fn)
        print(os.path.normpath(p))
    for name, title, desc, asm, fn in REF:
        p = build(name, title, desc, asm, fn, prefix="05")
        print(os.path.normpath(p))


if __name__ == "__main__":
    main()
