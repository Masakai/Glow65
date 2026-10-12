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

    def reg(self, name, y_center, value, hl=False, sub=None, w=110):
        x, h = 30, 34
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


def build(name, title, desc, asm, builder):
    sc = Scene(title, desc, 600)
    sc.header(title, asm)
    builder(sc)
    path = os.path.join(OUT_DIR, f"04-{name}.svg")
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


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, title, desc, asm, fn in MODES:
        p = build(name, title, desc, asm, fn)
        print(os.path.normpath(p))


if __name__ == "__main__":
    main()
