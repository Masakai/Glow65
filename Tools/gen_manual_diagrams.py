#!/usr/bin/env python3
"""マニュアル第4章(アドレッシングモード)の図を SVG で生成する。

使い方: python3 Tools/gen_manual_diagrams.py [--lang ja|en|all]
  --lang ja   日本語の図を manual/ja/images/ に出力する
  --lang en   英語の図を manual/en/images/ に出力する(ファイル名は日本語版と同じ)
  --lang all  両方を出力する(省略時)
出力先: manual/<言語>/images/04-*.svg ~ 07-*.svg(27 枚)

図の例の値は、下の EX にまとめている。本文(manual/ja/04-addressing.md)の例と一致させること。
標準ライブラリのみを使う。
"""
import argparse
import os
import subprocess
import sys
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def _lang_from_argv():
    p = argparse.ArgumentParser(description="マニュアルの図(SVG)を生成する")
    p.add_argument("--lang", choices=["ja", "en", "all"], default="all")
    return p.parse_args().lang


# all のときは、言語ごとに自分自身を起動する(文字列を import 時に選ぶため)
ARG_LANG = _lang_from_argv() if __name__ == "__main__" else "ja"
LANG = ARG_LANG if ARG_LANG in ("ja", "en") else "ja"
OUT_DIR = os.path.join(ROOT, "manual", LANG, "images")


def L(ja, en):
    """表示する文字列を言語で切り替える。"""
    return en if LANG == "en" else ja


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
FONT = L("-apple-system, 'Hiragino Sans', 'Noto Sans JP', sans-serif",
         "-apple-system, 'Helvetica Neue', Arial, sans-serif")
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
INK = "#1f2328"
MUTED = "#57606a"
BOX = "#f6f8fa"
LINE = "#8c959f"
BLUE = "#0969da"
BLUE_BG = "#ddf4ff"
ORANGE = "#bc4c00"
ORANGE_BG = "#fff1e5"


OPC = L("オペコード", "Opcode")
OPL = L("オペランド(下位)", "Operand (low)")
OPH = L("オペランド(上位)", "Operand (high)")
OPD = L("オペランド", "Operand")
REGS = L("レジスタ", "Registers")
MEM = L("メモリ", "Memory")
STK = L("スタック", "Stack")
ZPG = L("ゼロページ", "Zero page")


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
    b = sc.bytes_row([(f"{e['opcode']:02X}", OPC)], hl_from=9)
    sc.reg("X", 200, f"{h2(e['x_before'])} → {h2(e['x_after'])}", hl=True, w=190)
    sc.arrow([(62, 98), (62, 183)], 1, badge=(62, 140))
    sc.text(300, 160, L("オペランドはなく、メモリの内容は使わない。", "No operand. The contents of memory are not used."), size=13, fill=MUTED)
    finish(sc, 262, [
        L(f"① オペコード {h2(e['opcode'])}(INX)を読み、X の値に 1 を足す。X は {h2(e['x_before'])} から {h2(e['x_after'])} になる。",
          f"① Read opcode {h2(e['opcode'])} (INX) and add 1 to X. X goes from {h2(e['x_before'])} to {h2(e['x_after'])}."),
    ])


def s_accumulator(sc):
    e = EX["accumulator"]
    sc.bytes_row([(f"{e['opcode']:02X}", OPC)], hl_from=9)
    sc.reg("A", 200, f"{h2(e['a_before'])} → {h2(e['a_after'])}", hl=True, w=190)
    sc.arrow([(62, 98), (62, 183)], 1, badge=(62, 140))
    sc.text(300, 160, L("操作の対象は A そのもの。メモリの内容は使わない。", "The target is A itself. Memory is not used."), size=13, fill=MUTED)
    finish(sc, 262, [
        L(f"① オペコード {h2(e['opcode'])}(ASL A)を読み、A の各ビットを 1 つ左にずらす。A は {h2(e['a_before'])} から {h2(e['a_after'])} になる。",
          f"① Read opcode {h2(e['opcode'])} (ASL A) and shift every bit of A one place left. A goes from {h2(e['a_before'])} to {h2(e['a_after'])}."),
    ])


def s_immediate(sc):
    e = EX["immediate"]
    sc.bytes_row([(f"{e['opcode']:02X}", OPC), (f"{e['operand']:02X}", L("オペランド(値)", "Operand (value)"))])
    sc.label(30, 150, REGS)
    sc.reg("A", 200, h2(e["operand"]), hl=True)
    sc.arrow([(135, 98), (135, 183)], 1, badge=(135, 140))
    sc.text(300, 160, L("オペランドの値が、そのまま使われる。", "The operand value is used as it is."), size=13, fill=MUTED)
    sc.text(300, 182, L("メモリの番地は使わない。", "No memory address is used."), size=13, fill=MUTED)
    finish(sc, 262, [
        L(f"① オペコード {h2(e['opcode'])}(LDA #)と、オペランド {h2(e['operand'])} を読む。オペランドが値そのもの。",
          f"① Read opcode {h2(e['opcode'])} (LDA #) and operand {h2(e['operand'])}. The operand is the value itself."),
        L(f"② A に {h2(e['operand'])} を入れる。", f"② Put {h2(e['operand'])} in A."),
    ])


def direct(sc, key, mode_hex, idx=None, asm_op="LDA", dest="A", two_byte=False, rows=None):
    """ゼロページ / アブソリュート系(間接なし)の共通の図。"""
    e = EX[key]
    if two_byte:
        addr = e["addr"]
        base = addr
        items = [(f"{e['opcode']:02X}", OPC), (f"{addr & 0xFF:02X}", OPL),
                 (f"{addr >> 8:02X}", OPH)]
        fmt = h4
    else:
        base = e["zp"]
        items = [(f"{e['opcode']:02X}", OPC), (f"{base:02X}", OPD)]
        fmt = h2
    boxes = sc.bytes_row(items)
    ox = boxes[1][0]
    ocx = (ox + boxes[-1][0] + 64) / 2
    sc.label(30, 140, REGS)
    sc.label(545, 112, MEM, anchor="middle")
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
        lines = [L("実効アドレス", "Effective address"), f"{h4(eff)}"]
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
    steps.append(L(f"① オペコード {h2(e['opcode'])} と、オペランド {fmt(base)} を読む。",
                   f"① Read opcode {h2(e['opcode'])} and operand {fmt(base)}."))
    if idx:
        steps.append(L(f"② {idx} の値 {h2(e[idx.lower()])} を足して、実効アドレス {h4(eff)} を得る。",
                       f"② Add the value {h2(e[idx.lower()])} of {idx} to get effective address {h4(eff)}."))
        if not two_byte:
            steps.append(L("   ゼロページの計算は 256 バイトで折り返す($FF の次は $00)。",
                           "   Zero page arithmetic wraps around at 256 bytes ($FF is followed by $00)."))
        steps.append(L(f"③ {h4(eff)} の内容 {h2(e['value'])} を読む。",
                       f"③ Read the contents of {h4(eff)}: {h2(e['value'])}."))
        steps.append(L(f"④ {dest} に {h2(e['value'])} を入れる。", f"④ Put {h2(e['value'])} in {dest}."))
    else:
        steps.append(L(f"   オペランドが、そのまま実効アドレス {h4(eff)} になる。",
                       f"   The operand itself is the effective address {h4(eff)}."))
        steps.append(L(f"② {h4(eff)} の内容 {h2(e['value'])} を読む。",
                       f"② Read the contents of {h4(eff)}: {h2(e['value'])}."))
        steps.append(L(f"③ {dest} に {h2(e['value'])} を入れる。", f"③ Put {h2(e['value'])} in {dest}."))
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
    boxes = sc.bytes_row([(f"{e['opcode']:02X}", OPC), (f"{p & 0xFF:02X}", OPL),
                          (f"{p >> 8:02X}", OPH)])
    ocx = (boxes[1][0] + boxes[2][0] + 64) / 2
    sc.label(30, 140, REGS)
    sc.label(545, 112, MEM, anchor="middle")
    comp = sc.comp(190, 140, 210, [L("ポインタの場所", "Pointer location"), h4(p)])
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
        L(f"① オペコード {h2(e['opcode'])}(JMP)と、オペランド {h4(p)} を読む。{h4(p)} は、飛び先を収めた場所。",
          f"① Read opcode {h2(e['opcode'])} (JMP) and operand {h4(p)}. {h4(p)} is where the jump target is stored."),
        L(f"② {h4(p)} の {h2(lo)} を下位、{h4(p + 1)} の {h2(hi)} を上位として読む。",
          f"② Read {h2(lo)} at {h4(p)} as the low byte and {h2(hi)} at {h4(p + 1)} as the high byte."),
        L(f"③ 2 バイトを合わせた {h4(e['target'])} が PC に入る。次はこの番地の命令を実行する。",
          f"③ The two bytes together, {h4(e['target'])}, go into PC. The next instruction is run from that address."),
    ])


def s_indexed_indirect(sc):
    e = EX["indexed-indirect"]
    zp, x = e["zp"], e["x"]
    ptr = (zp + x) & 0xFF
    t = e["target"]
    sc.bytes_row([(f"{e['opcode']:02X}", OPC), (f"{zp:02X}", OPD)])
    sc.label(30, 140, REGS)
    sc.label(396, 112, ZPG, anchor="middle")
    sc.label(586, 112, MEM, anchor="middle")
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
        L(f"① オペコード {h2(e['opcode'])}(LDA)と、オペランド {h2(zp)} を読む。",
          f"① Read opcode {h2(e['opcode'])} (LDA) and operand {h2(zp)}."),
        L(f"② オペランドに X の値 {h2(x)} を足して、ゼロページの場所 {h2(ptr)} を得る(256 バイトで折り返す)。",
          f"② Add the value {h2(x)} of X to the operand to get zero-page location {h2(ptr)} (wraps at 256 bytes)."),
        L(f"③ {h4(ptr)} の {h2(t & 0xFF)} を下位、{h4(ptr + 1)} の {h2(t >> 8)} を上位として読む。",
          f"③ Read {h2(t & 0xFF)} at {h4(ptr)} as the low byte and {h2(t >> 8)} at {h4(ptr + 1)} as the high byte."),
        L(f"④ 2 バイトを合わせた {h4(t)} が実効アドレスになる。",
          f"④ The two bytes together, {h4(t)}, are the effective address."),
        L(f"⑤ {h4(t)} の内容 {h2(e['value'])} を読んで、A に入れる。",
          f"⑤ Read the contents {h2(e['value'])} of {h4(t)} and put it in A."),
    ])


def s_indirect_indexed(sc):
    e = EX["indirect-indexed"]
    zp, y, b = e["zp"], e["y"], e["base"]
    eff = b + y
    sc.bytes_row([(f"{e['opcode']:02X}", OPC), (f"{zp:02X}", OPD)])
    sc.label(30, 140, REGS)
    sc.label(396, 112, ZPG, anchor="middle")
    sc.label(586, 112, MEM, anchor="middle")
    comp1 = sc.comp(160, 140, 130, [L("ポインタの場所", "Pointer at"), h2(zp)])
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
        L(f"① オペコード {h2(e['opcode'])}(LDA)と、オペランド {h2(zp)} を読む。",
          f"① Read opcode {h2(e['opcode'])} (LDA) and operand {h2(zp)}."),
        L(f"② {h4(zp)} の {h2(b & 0xFF)} を下位、{h4(zp + 1)} の {h2(b >> 8)} を上位として読み、基準の番地 {h4(b)} を得る。",
          f"② Read {h2(b & 0xFF)} at {h4(zp)} as the low byte and {h2(b >> 8)} at {h4(zp + 1)} as the high byte to get base address {h4(b)}."),
        L(f"③④ 基準の番地に Y の値 {h2(y)} を足して、実効アドレス {h4(eff)} を得る。",
          f"③④ Add the value {h2(y)} of Y to the base address to get effective address {h4(eff)}."),
        L(f"⑤⑥ {h4(eff)} の内容 {h2(e['value'])} を読んで、A に入れる。",
          f"⑤⑥ Read the contents {h2(e['value'])} of {h4(eff)} and put it in A."),
    ], y0=385)


def s_relative(sc):
    e = EX["relative"]
    npc = e["next_pc"]
    off = e["offset"]
    tgt = npc + off
    sc.bytes_row([(f"{e['opcode']:02X}", OPC), (f"{off:02X}", L("オペランド(距離)", "Operand (offset)"))])
    sc.label(30, 140, REGS)
    sc.reg("PC", 168, h4(npc), sub=L("命令を読み終えた位置", "Next instruction"))
    comp = sc.comp(190, 140, 210, [f"{h4(npc)} + {h2(off)}", f"= {h4(tgt)}"])
    sc.arrow([(162, 98), (162, 120), (295, 120), comp["t"]], 1, badge=(162, 112))
    sc.arrow([(140, 168), (190, 168)], 2, badge=(165, 168))
    sc.reg("PC", 310, h4(tgt), hl=True)
    sc.arrow([(295, 196), (295, 310), (140, 310)], 3, badge=(295, 250), color=ORANGE)
    sc.text(440, 160, L("分岐の条件が成り立つときだけ、", "PC is changed only when"), size=13, fill=MUTED)
    sc.text(440, 182, L("PC を書き換える。", "the branch condition is true."), size=13, fill=MUTED)
    finish(sc, 360, [
        L(f"① オペコード {h2(e['opcode'])}(BNE)と、距離 {h2(off)} を読む。距離は符号付きの 1 バイト。",
          f"① Read opcode {h2(e['opcode'])} (BNE) and offset {h2(off)}. The offset is a signed 1-byte value."),
        L(f"② 命令を読み終えた PC は {h4(npc)}。ここに距離を足す。",
          f"② After the instruction is read, PC is {h4(npc)}. The offset is added to it."),
        L(f"③ 条件が成り立つとき、PC は {h4(tgt)} になる。成り立たないときは {h4(npc)} のまま。",
          f"③ If the condition is true, PC becomes {h4(tgt)}. If not, PC stays {h4(npc)}."),
    ])


def modes():
    return [
        ("implied", L("インプライド(Implied)", "Implied"),
         L("オペランドを持たず、メモリの内容を使わない。例は INX。", "No operand, and the contents of memory are not used. Example: INX."),
         "INX", s_implied),
        ("accumulator", L("アキュムレータ(Accumulator)", "Accumulator"),
         L("操作の対象が A レジスタ自身。例は ASL A。", "The operation acts on the A register itself. Example: ASL A."),
         "ASL A", s_accumulator),
        ("immediate", L("イミディエイト(Immediate)", "Immediate"),
         L("オペランドの値が、そのまま使われる。例は LDA #$10。", "The operand value is used as it is. Example: LDA #$10."),
         "LDA #$10", s_immediate),
        ("zeropage", L("ゼロページ(Zero Page)", "Zero Page"),
         L("1 バイトのオペランドで、先頭 256 バイトの番地を指定する。例は LDA $10。", "A 1-byte operand selects an address in the first 256 bytes. Example: LDA $10."),
         "LDA $10", s_zeropage),
        ("zeropage-x", L("ゼロページ X(Zero Page,X)", "Zero Page,X"),
         L("オペランドに X の値を足した、ゼロページの番地を使う。例は LDA $10,X。", "The address is the operand plus X, within zero page. Example: LDA $10,X."),
         "LDA $10,X", s_zeropage_x),
        ("zeropage-y", L("ゼロページ Y(Zero Page,Y)", "Zero Page,Y"),
         L("オペランドに Y の値を足した、ゼロページの番地を使う。例は LDX $10,Y。", "The address is the operand plus Y, within zero page. Example: LDX $10,Y."),
         "LDX $10,Y", s_zeropage_y),
        ("absolute", L("アブソリュート(Absolute)", "Absolute"),
         L("2 バイトのオペランドで、64KB のどの番地でも指定する。例は LDA $0400。", "A 2-byte operand selects any address in the 64KB space. Example: LDA $0400."),
         "LDA $0400", s_absolute),
        ("absolute-x", L("アブソリュート X(Absolute,X)", "Absolute,X"),
         L("2 バイトのオペランドに X の値を足した番地を使う。例は LDA $0410,X。", "The address is the 2-byte operand plus X. Example: LDA $0410,X."),
         "LDA $0410,X", s_absolute_x),
        ("absolute-y", L("アブソリュート Y(Absolute,Y)", "Absolute,Y"),
         L("2 バイトのオペランドに Y の値を足した番地を使う。例は LDA $0420,Y。", "The address is the 2-byte operand plus Y. Example: LDA $0420,Y."),
         "LDA $0420,Y", s_absolute_y),
        ("indirect", L("インダイレクト(Indirect)", "Indirect"),
         L("オペランドの番地に収めた 2 バイトを、飛び先として使う。JMP だけのモード。例は JMP ($0430)。", "The 2 bytes stored at the operand's address are the jump target. Only JMP uses this mode. Example: JMP ($0430)."),
         "JMP ($0430)", s_indirect),
        ("indexed-indirect", L("インデックスト・インダイレクト(Indexed Indirect)", "Indexed Indirect (zp,X)"),
         L("ゼロページの表から、X 番目の 2 バイトの番地を取り出す。例は LDA ($20,X)。", "Takes the X-th 2-byte address from a table in zero page. Example: LDA ($20,X)."),
         "LDA ($20,X)", s_indexed_indirect),
        ("indirect-indexed", L("インダイレクト・インデックスト(Indirect Indexed)", "Indirect Indexed (zp),Y"),
         L("ゼロページの 2 バイトの番地に Y の値を足した番地を使う。例は LDA ($30),Y。", "The address is the 2-byte address in zero page plus Y. Example: LDA ($30),Y."),
         "LDA ($30),Y", s_indirect_indexed),
        ("relative", L("リラティブ(Relative)", "Relative"),
         L("分岐命令で、次の命令からの距離(符号付き 1 バイト)を足した番地へ飛ぶ。例は BNE。", "A branch jumps to the address of the next instruction plus a signed 1-byte offset. Example: BNE."),
         "BNE +2", s_relative),
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
    sc.text(30, y0 + 70, L(f"実行後: A = %{rb[:4]} {rb[4:]}({h2(r)})、C = {c}", f"After: A = %{rb[:4]} {rb[4:]} ({h2(r)}), C = {c}"), size=13, mono=False)
    return r, c


def f5_shift(sc):
    a = 0xB1
    for i in range(8):
        sc.label(190 + i * 48 + 22, 90, f"b{7 - i}", anchor="middle")
    sc.text(30, 56, L(f"実行前: A = %10110001({h2(a)})。ROL と ROR は、実行前の C が 1 の場合",
                       f"Before: A = %10110001 ({h2(a)}). For ROL and ROR, C is 1 before the instruction."), size=13)
    ys = [130, 250, 370, 490]
    for y0, kind in zip(ys, ["ASL", "LSR", "ROL", "ROR"]):
        shift_row(sc, y0, kind, a, 1)
    sc.h = 610


def stack_panel(sc, dy, kind):
    """PHA / PLA の 1 面。SP = $FD、A = $42 の例。"""
    sc.text(30, dy + 24, "PHA" if kind == "PHA" else "PLA", size=16, weight="bold", mono=True, fill=BLUE)
    sc.label(545, dy + 30, L("スタック(メモリ)", "Stack (memory)"), anchor="middle")
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
            L("① SP が指す番地 $01FD(= $0100 + $FD)に、A の値 $42 を書く。",
              "① Write the value $42 of A to the address $01FD that SP points to (= $0100 + $FD)."),
            L("② SP から 1 を引く。SP は $FD から $FC になり、次の書き込みは $01FC になる。",
              "② Subtract 1 from SP. SP goes from $FD to $FC, and the next write goes to $01FC."),
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
            L("① SP に 1 を足す。SP は $FC から $FD になる。", "① Add 1 to SP. SP goes from $FC to $FD."),
            L("② SP が指す番地 $01FD の内容 $42 を読んで、A に入れる。",
              "② Read the contents $42 of the address $01FD that SP points to and put it in A."),
        ])


def f5_stack(sc):
    stack_panel(sc, 50, "PHA")
    stack_panel(sc, 290, "PLA")
    sc.h = 560


def f5_jsr_rts(sc):
    # JSR($0300 にある 3 バイトの命令)
    boxes = sc.bytes_row([("20", OPC), ("40", OPL), ("03", OPH)])
    for i, a in enumerate(["$0300", "$0301", "$0302"]):
        sc.label(boxes[i][0] + 32, 114, a, anchor="middle")
    sc.reg("PC", 150, "$0340", hl=True, x=470)
    sc.arrow([(358, 82), (410, 82), (410, 150), (470, 150)], 4, badge=(410, 110), color=ORANGE)
    sc.reg("PC", 190, "$0303", sub=L("3 バイト読み終えた位置", "After reading 3 bytes"))
    comp = sc.comp(250, 162, 170, ["PC − 1", "= $0302"])
    sc.arrow([(140, 190), (250, 190)], 1, badge=(195, 190))
    sc.label(555, 214, STK, anchor="middle")
    sc.cell(470, 240, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, 276, h4(0x1FC), "$02", "target", aw=72, vw=60)
    sc.cell(470, 312, h4(0x1FB), "..", "dim", aw=72, vw=60)
    sc.arrow([(420, 176), (445, 176), (445, 240), (470, 240)], 2, badge=(432, 176))
    sc.arrow([(420, 202), (445, 202), (445, 276), (470, 276)], 3, badge=(432, 202))
    sc.reg("SP", 300, "$FD → $FB", hl=True, w=140)
    sc.steps(350, L([
        "① 3 バイトを読み終えた PC は $0303。",
        "② ③ PC から 1 を引いた $0302 を、上位($03)、下位($02)の順に積む。$0302 は、JSR の最後のバイトの番地。",
        "④ PC はオペランドの $0340 になる。SP は 2 減って $FB になる。",
    ], [
        "① After the 3 bytes are read, PC is $0303.",
        "② ③ Push PC − 1 = $0302: the high byte ($03) first, then the low byte ($02).",
        "   $0302 is the address of the last byte of the JSR instruction.",
        "④ PC becomes the operand $0340. SP drops by 2 and becomes $FB.",
    ]))
    # RTS
    dy = 470
    sc.text(30, dy + 8, "RTS", size=16, weight="bold", mono=True, fill=BLUE)
    sc.label(555, dy + 20, STK, anchor="middle")
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
        L("① ② SP に 1 ずつ足しながら、下位($02)、上位($03)の順に取り出し、$0302 を作る。",
          "① ② Add 1 to SP each time and pull the low byte ($02), then the high byte ($03), to get $0302."),
        L("③ 1 を足した $0303 を PC に入れる。$0303 は、JSR の次の命令の番地。",
          "③ Put $0303 (that plus 1) in PC. $0303 is the address of the instruction after JSR."),
    ])
    sc.h = dy + 224


def f5_brk_rti(sc):
    # BRK($0302 にある)
    boxes = sc.bytes_row([("00", OPC), ("99", L("署名バイト(使われない)", "Signature byte (unused)"))], hl_from=9)
    sc.label(boxes[0][0] + 32, 114, "$0302", anchor="middle")
    sc.label(boxes[1][0] + 32, 114, "$0303", anchor="middle")
    sc.reg("PC", 168, "$0304")
    sc.reg("P", 222, "$24")
    sc.label(555, 130, STK, anchor="middle")
    sc.cell(470, 150, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, 186, h4(0x1FC), "$04", "target", aw=72, vw=60)
    sc.cell(470, 222, h4(0x1FB), "$34", "target", aw=72, vw=60)
    sc.arrow([(140, 168), (430, 168), (430, 150), (470, 150)], 1, badge=(300, 168))
    sc.arrow([(430, 168), (430, 186), (470, 186)], None)
    sc.arrow([(140, 222), (470, 222)], 2, badge=(300, 222))
    sc.label(555, 266, L("割り込みベクタ", "Interrupt vector"), anchor="middle")
    sc.cell(470, 292, h4(0xFFFE), L("下位", "Low"), "normal", aw=72, vw=60)
    sc.cell(470, 328, h4(0xFFFF), L("上位", "High"), "normal", aw=72, vw=60)
    sc.reg("PC", 310, L("ベクタの番地", "Vector address"), hl=True, w=170)
    sc.arrow([(470, 310), (200, 310)], 3, badge=(335, 310), color=ORANGE)
    sc.steps(365, [
        L("① PC の $0304 を、上位($03)、下位($04)の順に積む。署名バイトの次の番地。",
          "① Push PC = $0304 (the address after the signature byte): high byte ($03), then low byte ($04)."),
        L("② P を積む。B(ビット 4)とビット 5 は 1 にして積む($24 は $34 になる)。",
          "② Push P with B (bit 4) and bit 5 set to 1 ($24 is pushed as $34)."),
        L("③ I を 1 にして、$FFFE(下位)と $FFFF(上位)の番地を PC に入れる。",
          "③ Set I to 1 and load PC from $FFFE (low byte) and $FFFF (high byte)."),
    ])
    dy = 480
    sc.text(30, dy + 8, "RTI", size=16, weight="bold", mono=True, fill=BLUE)
    sc.label(555, dy + 20, STK, anchor="middle")
    sc.cell(470, dy + 40, h4(0x1FD), "$03", "target", aw=72, vw=60)
    sc.cell(470, dy + 76, h4(0x1FC), "$04", "target", aw=72, vw=60)
    sc.cell(470, dy + 112, h4(0x1FB), "$34", "target", aw=72, vw=60)
    sc.reg("P", dy + 112, "$34 → $24", hl=True, w=140)
    sc.reg("PC", dy + 58, "$0304", hl=True)
    sc.arrow([(470, dy + 112), (170, dy + 112)], 1, badge=(320, dy + 112), color=ORANGE)
    sc.arrow([(470, dy + 58), (140, dy + 58)], 2, badge=(300, dy + 58), color=ORANGE)
    sc.steps(dy + 160, [
        L("① P を取り出す。B は取り込まず、ビット 5 は 1 にする。",
          "① Pull P. B is not loaded, and bit 5 is set to 1."),
        L("② PC の下位($04)、上位($03)の順に取り出す。RTS と違って、1 を足さない。",
          "② Pull PC: low byte ($04), then high byte ($03). Unlike RTS, nothing is added."),
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
    branch_panel(sc, 30, L("前へ分岐(距離 +2)", "Branch forward (offset +2)"), [
        ("$0302", "D0 02", "BNE $0306", "branch"),
        ("$0304", "A9 EE", "LDA #$EE", "dim"),
        ("$0306", "8D F0 03", "STA $03F0", "target"),
    ], 0, 2, L("次の命令 $0304 + $02 = $0306", "Next instruction $0304 + $02 = $0306"))
    branch_panel(sc, 380, L("後ろへ分岐(距離 −3)", "Branch backward (offset −3)"), [
        ("$0302", "CA", "DEX", "target"),
        ("$0303", "D0 FD", "BNE $0302", "branch"),
        ("$0305", "8E F0 03", "STX $03F0", "dim"),
    ], 1, 0, L("次の命令 $0305 + $FD(−3) = $0302", "Next instruction $0305 + $FD (−3) = $0302"))
    sc.steps(250, [
        L("距離は、分岐命令の次の命令の番地から測る。$FD は、符号付きの 8 ビットで −3。",
          "The offset is measured from the address of the instruction after the branch. $FD is −3 as a signed 8-bit value."),
        L("条件が成り立たないとき、PC は次の命令に進む。成り立つときだけ、PC に距離を足す。",
          "If the condition is false, PC goes to the next instruction. Only if true is the offset added."),
    ])
    sc.h = 310


def f5_bit(sc):
    m = 0xC0
    a = 0x01
    sc.text(30, 56, L(f"BIT $0400(メモリの内容 {h2(m)}、A = {h2(a)} の例)", f"BIT $0400 (example: memory contents {h2(m)}, A = {h2(a)})"), size=14, weight="bold")
    xs = [30 + i * 48 for i in range(8)]
    for i, x in enumerate(xs):
        sc.label(x + 22, 76, f"b{7 - i}", anchor="middle")
        bitbox(sc, x, 82, str((m >> (7 - i)) & 1), hl="blue" if i < 2 else None)
    bitbox(sc, xs[0], 190, "N = 1", w=44, hl="orange", size=13)
    bitbox(sc, xs[1], 190, "V = 1", w=44, hl="orange", size=13)
    sc.arrow([(xs[0] + 22, 116), (xs[0] + 22, 190)], 1, badge=(xs[0] + 22, 160))
    sc.arrow([(xs[1] + 22, 116), (xs[1] + 22, 190)], 2, badge=(xs[1] + 22, 160))
    sc.text(xs[0], 250, L("ビット 7 → N、ビット 6 → V", "Bit 7 → N, bit 6 → V"), size=12, fill=MUTED)
    sc.reg("A", 99, h2(a), x=500)
    sc.comp(440, 170, 220, ["A AND M", f"{h2(a)} AND {h2(m)} = $00"])
    sc.arrow([(414, 99), (470, 99), (470, 170)], 3, badge=(442, 99))
    sc.arrow([(555, 116), (555, 170)], 4, badge=(555, 143))
    bitbox(sc, 520, 250, "Z = 1", w=60, hl="orange", size=13)
    sc.arrow([(550, 226), (550, 250)], 5, badge=(550, 238), color=ORANGE)
    sc.steps(310, [
        L("① ② メモリの内容のビット 7 が N に、ビット 6 が V に、そのまま写る。",
          "① ② Bit 7 of the memory contents is copied to N, and bit 6 to V, as they are."),
        L("③ ④ A とメモリの内容を AND する。結果そのものは捨てて、A は変わらない。",
          "③ ④ A is ANDed with the memory contents. The result itself is discarded and A is unchanged."),
        L("⑤ AND の結果が 0 なら、Z を 1 にする。", "⑤ If the AND result is 0, Z is set to 1."),
    ])
    sc.h = 396


def ref5():
    return [
        ("shift", L("ビットの動き(ASL、LSR、ROL、ROR)", "Bit movement (ASL, LSR, ROL, ROR)"),
         L("ASL、LSR、ROL、ROR が、A の 8 ビットとキャリーをどう動かすか。", "How ASL, LSR, ROL and ROR move the 8 bits of A and the carry."),
         "", f5_shift),
        ("stack", L("スタック(PHA と PLA)", "Stack (PHA and PLA)"),
         L("PHA が SP の指す番地に A を書いて SP を 1 減らし、PLA が SP を 1 増やして A に読むこと。", "PHA writes A to the address SP points to and decrements SP by 1. PLA increments SP by 1 and reads into A."),
         "", f5_stack),
        ("jsr-rts", L("JSR と RTS", "JSR and RTS"),
         L("JSR が戻り番地(最後のバイトの番地)を積み、RTS が 1 を足して戻ること。", "JSR pushes the return address (the address of its last byte). RTS adds 1 to it and returns."),
         "", f5_jsr_rts),
        ("brk-rti", L("BRK と RTI", "BRK and RTI"),
         L("BRK が PC と P を積んでベクタへ飛び、RTI が P と PC を取り出して戻ること。", "BRK pushes PC and P and jumps through the vector. RTI pulls P and PC and returns."),
         "", f5_brk_rti),
        ("branch", L("分岐の飛び先", "Branch destination"),
         L("分岐命令の距離は、次の命令の番地から測ること。前へも後ろへも分岐できること。", "A branch offset is measured from the address of the next instruction. A branch can go forward or backward."),
         "", f5_branch),
        ("bit", L("BIT のフラグ", "Flags set by BIT"),
         L("BIT がメモリの上位 2 ビットを N と V に写し、A との AND で Z を決めること。", "BIT copies the top 2 bits of memory to N and V, and sets Z from the AND with A."),
         "", f5_bit),
    ]


# ---- 第6章(フラグ、スタック、割り込み)の図 ----

def f6_flags(sc):
    names = ["N", "V", "-", "B", "D", "I", "Z", "C"]
    desc = L([("結果が負", "(最上位ビット)"), ("符号付きの", "桁あふれ"), ("常に 1", "(実体なし)"), ("積むときだけ", "(実体なし)"),
              ("10進モード", ""), ("割り込み", "禁止"), ("結果が 0", ""), ("桁上がり", "(SBC は借りの逆)")],
             [("Negative", "(top bit)"), ("Signed", "overflow"), ("Always 1", "(no real bit)"), ("Only on push", "(no real bit)"),
              ("Decimal", "mode"), ("Interrupt", "disable"), ("Result is 0", ""), ("Carry", "(SBC: 1 = no borrow)")])
    for i, (n, d) in enumerate(zip(names, desc)):
        x = 30 + i * 84
        sc.label(x + 38, 76, L(f"ビット {7 - i}", f"Bit {7 - i}"), anchor="middle")
        fill, stroke = (BOX, LINE) if n not in ("-", "B") else ("#ffffff", "#d0d7de")
        sc.rect(x, 82, 76, 40, fill=fill, stroke=stroke, sw=1.4)
        sc.text(x + 38, 109, n, size=20, weight="bold", anchor="middle", mono=True, fill=INK if n not in ("-", "B") else MUTED)
        sc.text(x + 38, 142, d[0], size=12, anchor="middle")
        sc.text(x + 38, 158, d[1], size=11, anchor="middle", fill=MUTED)
    rows = [(L("リセット後の値(Glow65): $24", "Value after reset (Glow65): $24"), "00100100", None),
            (L("PHP と BRK が積む値(例: $34)。B が 1", "Value pushed by PHP and BRK (example: $34). B is 1"), "00110100", 3),
            (L("IRQ と NMI が積む値(例: $24)。B が 0", "Value pushed by IRQ and NMI (example: $24). B is 0"), "00100100", 3)]
    y = 196
    for label, bits, hl in rows:
        sc.text(30, y, label, size=13, weight="bold")
        for i, b in enumerate(bits):
            x = 30 + i * 84
            on = b == "1"
            hlc = "orange" if hl == i else None
            bitbox(sc, x, y + 8, b, w=76, h=30, hl=hlc if hlc else ("blue" if on else None))
        y += 70
    sc.h = y + 4


def f6_compare(sc):
    sc.text(30, 62, L("A = $30 のとき、M を変えて比べた結果", "Results of comparing with different values of M when A = $30"), size=13)
    for j, n in enumerate(["C", "Z", "N"]):
        sc.text(330 + j * 70 + 28, 90, n, size=14, weight="bold", anchor="middle", mono=True)
    sc.text(540, 90, L("使う分岐", "Branch to use"), size=13, weight="bold")
    rows = [("A < M", "CMP #$40", (0, 0, 1), L("BCC(C = 0)", "BCC (C=0)")),
            ("A = M", "CMP #$30", (1, 1, 0), L("BEQ(Z = 1)", "BEQ (Z=1)")),
            ("A > M", "CMP #$20", (1, 0, 0), L("BCS(C = 1)と BNE(Z = 0)", "BCS (C=1), BNE (Z=0)"))]
    y = 108
    for case, asm, (c, z, n), br in rows:
        sc.text(30, y + 20, case, size=18, weight="bold", mono=True, fill=BLUE)
        sc.text(130, y + 20, asm, size=14, mono=True)
        for j, v in enumerate((c, z, n)):
            bitbox(sc, 330 + j * 70, y, str(v), w=56, hl="orange" if v else None)
        sc.text(540, y + 22, br, size=13)
        y += 56
    sc.text(30, y + 20, L("C は A が M 以上のとき 1。Z は A と M が等しいとき 1。N は A − M の結果の最上位ビット。",
                          "C is 1 when A is greater than or equal to M. Z is 1 when A equals M. N is the top bit of A − M."), size=13)
    sc.text(30, y + 42, L("N は、符号付きの大小を直接表すものではない。比較は、符号なしの数として行われる。",
                          "N does not directly show signed order. The comparison treats both values as unsigned."), size=13, fill=MUTED)
    sc.h = y + 64


def f6_nested(sc):
    sc.text(30, 62, L("SP = $FD から始める", "Start with SP = $FD"), size=13)
    panels = [
        (L("① 最初の JSR のあと", "① After the first JSR"), 0xFB, [(0x1FD, "$03", "t"), (0x1FC, "$02", "t"), (0x1FB, "..", "d"), (0x1FA, "..", "d"), (0x1F9, "..", "d")]),
        (L("② 2 つ目の JSR のあと", "② After the second JSR"), 0xF9, [(0x1FD, "$03", "t"), (0x1FC, "$02", "t"), (0x1FB, "$03", "t"), (0x1FA, "$22", "t"), (0x1F9, "..", "d")]),
        (L("③ RTS で 1 つ戻ったあと", "③ After one RTS"), 0xFB, [(0x1FD, "$03", "t"), (0x1FC, "$02", "t"), (0x1FB, "$03", "d"), (0x1FA, "$22", "d"), (0x1F9, "..", "d")]),
    ]
    for i, (title, sp, rows) in enumerate(panels):
        x0 = 30 + i * 232
        sc.text(x0, 86, title, size=13, weight="bold")
        sc.text(x0, 106, f"SP = ${sp:02X}", size=13, mono=True, fill=ORANGE, weight="bold")
        for k, (addr, val, kind) in enumerate(rows):
            y = 134 + k * 34
            sc.cell(x0, y, h4(addr), val, "target" if kind == "t" else "dim", aw=70, vw=52)
            if addr == 0x100 + sp:
                sc.arrow([(x0 + 172, y), (x0 + 128, y)], None, color=ORANGE)
                sc.text(x0 + 178, y + 5, "SP", size=13, weight="bold", fill=ORANGE)
    sc.steps(330, L([
        "$01FD と $01FC は、最初の JSR が積んだ戻り番地(`$0302`)。上位が先、下位が次。".replace("`", ""),
        "$01FB と $01FA は、2 つ目の JSR が積んだ戻り番地($0322)。SP は 2 つずつ下がる。",
        "RTS は、SP を戻して番地を取り出す。取り出した値は、メモリに残るが、次の PHA や JSR で上書きされる。",
    ], [
        "$01FD and $01FC hold the return address ($0302) pushed by the first JSR: high byte first, then low byte.",
        "$01FB and $01FA hold the return address ($0322) pushed by the second JSR. SP drops by 2 each time.",
        "RTS moves SP back and pulls the address. The pulled values stay in memory",
        "   until a later PHA or JSR overwrites them.",
    ]))
    sc.h = L(420, 440)


def f6_flow(sc):
    W_, H_ = 200, 60
    xs = [30, 260, 490]
    ys = [80, 190, 300]
    def box(x, y, n, l1, l2, kind):
        fill, stroke, sw = BOX, LINE, 1.4
        if kind == "cpu":
            fill, stroke, sw = BLUE_BG, BLUE, 2
        elif kind == "handler":
            fill, stroke, sw = ORANGE_BG, ORANGE, 2
        sc.rect(x, y, W_, H_, fill=fill, stroke=stroke, sw=sw, rx=6)
        sc.text(x + 12, y + 24, f"{n}", size=15, weight="bold", fill=stroke if kind else INK)
        sc.text(x + 34, y + 25, l1, size=13, weight="bold")
        sc.text(x + 34, y + 45, l2, size=12, fill=MUTED)
    seq = [
        (0, 0, "①", L("主プログラムを実行", "Run the main program"), L("命令を 1 つずつ実行", "One instruction at a time"), None),
        (1, 0, "②", L("割り込みの要求", "Interrupt request"), L("NMI、または IRQ", "NMI or IRQ"), None),
        (2, 0, "③", L("実行中の命令を終える", "Finish the instruction"), L("命令の途中では受けない", "Not taken mid-instruction"), "cpu"),
        (2, 1, "④", L("PC と P を積む", "Push PC and P"), L("PCH、PCL、P の順", "PCH, PCL, then P"), "cpu"),
        (1, 1, "⑤", L("I フラグを 1 にする", "Set the I flag to 1"), L("IRQ を重ねて受けない", "Blocks further IRQs"), "cpu"),
        (0, 1, "⑥", L("ベクタを読んで飛ぶ", "Read vector, jump"), "NMI $FFFA、IRQ $FFFE" if LANG == "ja" else "NMI $FFFA, IRQ $FFFE", "cpu"),
        (0, 2, "⑦", L("ハンドラを実行", "Run the handler"), L("レジスタを保存して使う", "Save registers before use"), "handler"),
        (1, 2, "⑧", L("RTI を実行", "Run RTI"), L("P と PC を取り出す", "Pull P and PC"), "handler"),
        (2, 2, "⑨", L("主プログラムの続き", "Main program resumes"), L("積んだ PC の番地から", "From the pushed PC address"), None),
    ]
    pos = {}
    for c, r, n, l1, l2, kind in seq:
        box(xs[c], ys[r], n, l1, l2, kind)
        pos[n] = (xs[c], ys[r])
    def mid(n, side):
        x, y = pos[n]
        return {"r": (x + W_, y + H_ / 2), "l": (x, y + H_ / 2), "b": (x + W_ / 2, y + H_), "t": (x + W_ / 2, y)}[side]
    sc.arrow([mid("①", "r"), mid("②", "l")], None)
    sc.arrow([mid("②", "r"), mid("③", "l")], None)
    sc.arrow([mid("③", "b"), mid("④", "t")], None)
    sc.arrow([mid("④", "l"), mid("⑤", "r")], None)
    sc.arrow([mid("⑤", "l"), mid("⑥", "r")], None)
    sc.arrow([mid("⑥", "b"), mid("⑦", "t")], None)
    sc.arrow([mid("⑦", "r"), mid("⑧", "l")], None)
    sc.arrow([mid("⑧", "r"), mid("⑨", "l")], None)
    sc.text(30, 392, L("青い枠は、CPU が自動で行う手順。橙の枠は、プログラム(ハンドラ)が行う手順。",
                       "Blue boxes: steps the CPU does automatically. Orange boxes: steps the program (handler) does."), size=13)
    sc.h = 420


def f6_nmi_irq(sc):
    x0, x1 = 190, 690
    def wave(y, pts, label, sub):
        yl, yh = y + 40, y
        sc.text(30, y + 26, label, size=13, weight="bold")
        sc.text(30, y + 46, sub, size=11, fill=MUTED)
        path = []
        cur = yl
        path.append((x0, cur))
        for x, lvl in pts:
            ny = yh if lvl else yl
            path.append((x, cur)); path.append((x, ny)); cur = ny
        path.append((x1, cur))
        d = "M " + " L ".join(f"{a} {b}" for a, b in path)
        sc.parts.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="2"/>')
        sc.text(x0 - 8, yh + 4, L("あり", "Active"), size=11, anchor="end", fill=MUTED)
        sc.text(x0 - 8, yl + 4, L("なし", "Idle"), size=11, anchor="end", fill=MUTED)
        return yh
    def mark(x, y):
        sc.arrow([(x, y - 34), (x, y - 4)], None, color=ORANGE)
    # NMI
    y = 120
    wave(y, [(250, 1), (420, 0), (500, 1), (590, 0)], "NMI", L("(要求の線)", "(request line)"))
    mark(250, y + 4); mark(500, y + 4)
    sc.text(250, y - 40, L("受け付け", "Accepted"), size=11, anchor="middle", fill=ORANGE)
    sc.text(500, y - 40, L("受け付け", "Accepted"), size=11, anchor="middle", fill=ORANGE)
    sc.text(30, y + 76, L("要求が「なし」から「あり」に変わった 1 回ごとに、1 回だけ受け付ける。I フラグには関係しない。",
                          "Accepted once for each change from Idle to Active. The I flag does not matter."), size=12)
    # IRQ 消さない
    y = 260
    wave(y, [(250, 1)], "IRQ", L("(要因を消さない)", "(cause not cleared)"))
    for x in (270, 350, 430, 510, 590, 670):
        mark(x, y + 4)
    sc.text(30, y + 76, L("要求が「あり」の間、RTI のあとすぐに、何度でも受け付ける(I = 0 のとき)。",
                          "While the request stays Active, it is accepted again right after each RTI (when I = 0)."), size=12)
    # IRQ 消す
    y = 390
    wave(y, [(250, 1), (300, 0)], "IRQ", L("(ハンドラが要因を消す)", "(handler clears cause)"))
    mark(270, y + 4)
    sc.text(318, y + 24, L("$A001 を読んで、要求を下げる", "Reading $A001 clears the request"), size=11, fill=MUTED)
    sc.text(30, y + 76, L("ハンドラが要因を消せば、受け付けは 1 回で終わる。", "If the handler clears the cause, the request is accepted only once."), size=12)
    sc.h = 500


def ref6():
    return [
        ("flags", L("P レジスタの 8 ビット", "The 8 bits of the P register"),
         L("N、V、B、D、I、Z、C のビットの位置と意味。リセット後、PHP と BRK、IRQ と NMI が積む P の値の違い。", "Bit positions and meanings of N, V, B, D, I, Z and C. How the value of P differs after reset, when pushed by PHP and BRK, and when pushed by IRQ and NMI."),
         "", f6_flags),
        ("compare", L("CMP の結果とフラグ", "CMP results and flags"),
         L("CMP のあとの C、Z、N の読み方と、使う分岐命令の対応。", "How to read C, Z and N after CMP, and which branch instruction goes with each result."),
         "", f6_compare),
        ("stack-nested", L("ネストした JSR とスタック", "Nested JSR and the stack"),
         L("JSR を 2 回重ねたときのスタックの中身と、RTS で戻ったあとの様子。", "The contents of the stack after two nested JSRs, and after returning with RTS."),
         "", f6_nested),
        ("interrupt-flow", L("割り込みの流れ", "Interrupt flow"),
         L("割り込みの要求から、ハンドラの実行、RTI による復帰までの手順。", "The steps from an interrupt request, through the handler, to the return by RTI."),
         "", f6_flow),
        ("nmi-irq", L("NMI と IRQ の違い", "NMI and IRQ compared"),
         L("NMI がエッジで 1 回、IRQ がレベルで、要因が消えるまで繰り返し受け付けられること。", "NMI is accepted once per edge. IRQ is level-triggered and is accepted repeatedly until its cause is cleared."),
         "", f6_nmi_irq),
    ]

# ---- 第7章(メモリマップと I/O)の図 ----

def dashed_rect(sc, x, y, w, h):
    sc.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="#ffffff" stroke="{LINE}" '
                    f'stroke-width="1.4" stroke-dasharray="5 4"/>')


def band(sc, x, y, w, h, kind, l1, l2=None):
    if kind == "ram":
        sc.rect(x, y, w, h, fill=BLUE_BG, stroke=BLUE, sw=2, rx=3)
    elif kind == "rom":
        sc.rect(x, y, w, h, fill=ORANGE_BG, stroke=ORANGE, sw=2, rx=3)
    elif kind == "io":
        sc.rect(x, y, w, h, fill="#d8dee4", stroke=INK, sw=2, rx=3)
    else:
        dashed_rect(sc, x, y, w, h)
    tc = MUTED if kind == "none" else INK
    if l2 is None:
        sc.text(x + w / 2, y + h / 2 + 5, l1, size=12, anchor="middle", fill=tc, mono=True)
    else:
        sc.text(x + w / 2, y + h / 2 - 2, l1, size=12, anchor="middle", fill=tc, mono=True)
        sc.text(x + w / 2, y + h / 2 + 15, l2, size=12, anchor="middle", fill=tc)


def f7_map(sc):
    x0, w0 = 30, 230
    y = 62
    mains = [("rom", "$F000-$FFFF", L("モニタの ROM とベクタ", "Monitor ROM and vectors"), 56),
             ("rom", "$C000-$EFFF", L("BASIC の ROM", "BASIC ROM"), 72),
             ("none", "$A100-$BFFF", L("何もつながっていない", "Nothing connected"), 50),
             ("io", "$A000-$A0FF", "UART", 40),
             ("none", "$8000-$9FFF", L("何もつながっていない", "Nothing connected"), 50),
             ("ram", "$0000-$7FFF", L("RAM(32KB)", "RAM (32KB)"), 228)]
    ram_top = ram_bot = 0
    for kind, a, n, h in mains:
        band(sc, x0, y, w0, h, kind, a, n)
        if a.startswith("$0000"):
            ram_top, ram_bot = y, y + h
        y += h
    subs = [("$0400-$7FFF", L("BASIC のプログラムと変数", "BASIC program, variables"), 62),
            ("$03F8-$03FB", L("割り込みベクタ(RAM)", "Interrupt vectors (RAM)"), 30),
            ("$0300-$03F7", L("ユーザープログラム用", "User programs"), 38),
            ("$0200-$027F", L("モニタの行入力バッファ", "Monitor line buffer"), 38),
            ("$0100-$01FF", STK, 30),
            ("$0000-$00FF", ZPG, 30)]
    xs, ws = 410, 280
    ys = ram_top
    sc.text(xs, ram_top - 8, L("RAM の主な使い道", "Main uses of RAM"), size=12, weight="bold")
    for a, n, h in subs:
        sc.rect(xs, ys, ws, h, fill=BLUE_BG, stroke=BLUE, sw=2, rx=3)
        sc.text(xs + 10, ys + h / 2 + 5, a, size=12, mono=True)
        sc.text(xs + 112, ys + h / 2 + 5, n, size=12)
        ys += h
    sc.parts.append(f'<line x1="{x0 + w0}" y1="{ram_top}" x2="{xs}" y2="{ram_top}" stroke="{BLUE}" stroke-width="1.2" stroke-dasharray="4 3"/>')
    sc.parts.append(f'<line x1="{x0 + w0}" y1="{ram_bot}" x2="{xs}" y2="{ys}" stroke="{BLUE}" stroke-width="1.2" stroke-dasharray="4 3"/>')
    # 凡例
    ly = max(ram_bot, ys) + 26
    for i, (kind, text) in enumerate([("ram", "RAM"), ("rom", "ROM"), ("io", "I/O"), ("none", L("未接続", "Not connected"))]):
        lx = 30 + i * 120
        if kind == "none":
            dashed_rect(sc, lx, ly - 12, 22, 16)
        else:
            band(sc, lx, ly - 12, 22, 16, kind, "")
        sc.text(lx + 30, ly + 1, text, size=12)
    sc.text(30, ly + 28, L("未接続のアドレスを読むと $FF が返り、書き込みは無視される。ROM への書き込みも無視される。",
                         "Reading an unconnected address returns $FF, and writing to it is ignored. Writes to ROM are ignored too."), size=12, fill=MUTED)
    sc.h = ly + 46


def f7_uart(sc):
    sc.text(30, 62, L("MC6850 風の最小構成", "Minimal MC6850-style layout"), size=13)
    def regrow(y, title, cells, notes=None):
        sc.text(30, y, title, size=13, weight="bold")
        for i in range(8):
            x = 30 + i * 84
            sc.label(x + 38, y + 18, L(f"ビット {7 - i}", f"Bit {7 - i}"), anchor="middle")
        for i, (name, desc, hl) in enumerate(cells):
            x = 30 + i * 84
            hlc = {"b": "blue", "o": "orange"}.get(hl)
            bitbox(sc, x, y + 24, name, w=76, h=34, hl=hlc, size=14)
            sc.text(x + 38, y + 76, desc[0], size=11, anchor="middle")
            if len(desc) > 1:
                sc.text(x + 38, y + 91, desc[1], size=11, anchor="middle", fill=MUTED)
    UNUSED = (L("未使用", "Unused"),)
    NOTUSED = (L("使わない", "Unused"),)
    regrow(100, L("状態レジスタ($A000 を読む)", "Status register (read $A000)"), [
        ("IRQ", L(("割り込み", "要求中"), ("Interrupt", "pending")), "o"), ("0", UNUSED, None), ("0", UNUSED, None), ("0", UNUSED, None),
        ("0", UNUSED, None), ("0", UNUSED, None), ("TDRE", (L("送信可", "Can send"),), "b"), ("RDRF", (L("受信あり", "Byte received"),), "b")])
    regrow(250, L("制御レジスタ($A000 に書く)", "Control register (write $A000)"), [
        ("RIE", L(("受信割り込みの", "許可"), ("RX interrupt", "enable")), "o"), ("-", NOTUSED, None), ("-", NOTUSED, None), ("-", NOTUSED, None),
        ("-", NOTUSED, None), ("-", NOTUSED, None), ("1", (L("11 で", "11 means"),), "b"), ("1", (L("マスタリセット", "master reset"),), "b")])
    sc.text(30, 410, L("データレジスタ($A001)", "Data register ($A001)"), size=13, weight="bold")
    sc.rect(30, 420, 330, 42, fill=BLUE_BG, stroke=BLUE, sw=2)
    sc.text(195, 446, L("読むと: 受信した 1 バイト", "Read: the received byte"), size=13, anchor="middle")
    sc.rect(372, 420, 330, 42, fill=ORANGE_BG, stroke=ORANGE, sw=2)
    sc.text(537, 446, L("書くと: 送信する 1 バイト", "Write: the byte to send"), size=13, anchor="middle")
    sc.h = 490


def diamond(sc, cx, cy, w, h, lines):
    pts = f"{cx},{cy - h / 2} {cx + w / 2},{cy} {cx},{cy + h / 2} {cx - w / 2},{cy}"
    sc.parts.append(f'<polygon points="{pts}" fill="#ffffff" stroke="{BLUE}" stroke-width="2"/>')
    n = len(lines)
    for i, t in enumerate(lines):
        sc.text(cx, cy + (i - (n - 1) / 2) * 17 + 5, t, size=12, anchor="middle")


def flow_panel(sc, cx, title, first, test, last, bit):
    sc.text(cx - 130, 64, title, size=14, weight="bold")
    bw = 240
    sc.rect(cx - bw / 2, 84, bw, 44, fill=BOX, stroke=LINE, sw=1.4, rx=6)
    sc.text(cx, 111, first, size=13, anchor="middle", mono=True)
    diamond(sc, cx, 210, 240, 90, test)
    sc.rect(cx - bw / 2, 306, bw, 44, fill=ORANGE_BG, stroke=ORANGE, sw=2, rx=6)
    sc.text(cx, 333, last, size=13, anchor="middle", mono=True)
    sc.arrow([(cx, 128), (cx, 165)], None)
    sc.arrow([(cx, 255), (cx, 306)], None, color=ORANGE)
    sc.text(cx + 10, 284, L("はい(1)", "Yes (1)"), size=12, fill=ORANGE)
    sc.arrow([(cx - 120, 210), (cx - 150, 210), (cx - 150, 106), (cx - 120, 106)], None)
    sc.text(cx - 148, 232, L("いいえ(0)", "No (0)"), size=12, fill=BLUE)


def f7_polling(sc):
    flow_panel(sc, 190, L("送信(1 バイトを送る)", "Transmit (send 1 byte)"), "LDA $A000", L(["TDRE(ビット 1)", "が 1 か"], ["TDRE (bit 1)", "is 1?"]), "STA $A001", 1)
    flow_panel(sc, 530, L("受信(1 バイトを受け取る)", "Receive (get 1 byte)"), "LDA $A000", L(["RDRF(ビット 0)", "が 1 か"], ["RDRF (bit 0)", "is 1?"]), "LDA $A001", 0)
    sc.steps(384, L([
        "状態レジスタの該当ビットを AND で取り出し、0 の間は読み直す。1 になったら、データレジスタに触る。",
        "送信は TDRE が 1 のとき書く。受信は RDRF が 1 のとき読む。読むと、受信した 1 バイトがキューから消える。",
    ], [
        "Pick out the bit in the status register with AND, and read again while it is 0.",
        "When it is 1, access the data register.",
        "Transmit: write when TDRE is 1. Receive: read when RDRF is 1.",
        "Reading removes the received byte from the queue.",
    ]))
    sc.h = L(440, 484)


def ref7():
    return [
        ("memory-map", L("メモリマップ全体", "Whole memory map"),
         L("Glow65 の 64KB のアドレス空間の割り振りと、RAM の主な使い道。", "How the 64KB address space of Glow65 is allocated, and the main uses of RAM."),
         "", f7_map),
        ("uart", L("UART のレジスタ", "UART registers"),
         L("UART の状態レジスタ、制御レジスタ、データレジスタのビットの意味。", "The meaning of the bits in the UART status, control and data registers."),
         "", f7_uart),
        ("polling", L("ポーリングの流れ", "Polling flow"),
         L("状態レジスタのビットを調べて、送信と受信を行う流れ。", "How to check the status register bits to transmit and receive."),
         "", f7_polling),
    ]


def main():
    if ARG_LANG == "all":
        # 文字列は import 時に言語で選ぶので、言語ごとに自分自身を起動する
        for lang in ("ja", "en"):
            subprocess.run([sys.executable, os.path.abspath(__file__), "--lang", lang], check=True)
        return
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, title, desc, asm, fn in modes():
        p = build(name, title, desc, asm, fn)
        print(os.path.normpath(p))
    for name, title, desc, asm, fn in ref5():
        p = build(name, title, desc, asm, fn, prefix="05")
        print(os.path.normpath(p))
    for name, title, desc, asm, fn in ref6():
        p = build(name, title, desc, asm, fn, prefix="06")
        print(os.path.normpath(p))
    for name, title, desc, asm, fn in ref7():
        p = build(name, title, desc, asm, fn, prefix="07")
        print(os.path.normpath(p))


if __name__ == "__main__":
    main()
