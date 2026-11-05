#!/usr/bin/env python3
"""Build a deterministic README preview for nvim-go-ide.

The composition is derived from the tracked configuration:
- explorer_width = 34
- always_show_tabs = true
- breadcrumbs = true
- minimap_width = 10
- go-night palette from settings.lua
- lualine's pinned Horizon theme for the per-window statusline

The preview intentionally excludes terminal/tmux chrome and floating UI so the
image represents the repository-owned Neovim surfaces only.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont
from pygments import lex
from pygments.lexers import GoLexer
from pygments.token import Comment, Keyword, Name, Number, Operator, Punctuation, String, Text

W, H = 1920, 1080
COL_W = 10
ROW_H = 24
EXPLORER_COLS = 34
EXPLORER_W = EXPLORER_COLS * COL_W
TAB_H = 34
CRUMB_H = 32
STATUS_H = 30
EDITOR_TOP = TAB_H + CRUMB_H
EDITOR_BOTTOM = H - STATUS_H
MINIMAP_W = 10 * COL_W

def parse_settings(root: Path):
    text = (root / "config/lua/go_ide/settings.lua").read_text(encoding="utf-8")
    def num(name, default):
        m = re.search(rf"\b{name}\s*=\s*(\d+)", text)
        return int(m.group(1)) if m else default
    colors = dict(re.findall(r"(\w+)\s*=\s*'(#(?:[0-9A-Fa-f]{6}))'", text))
    return {
        "explorer_width": num("explorer_width", 34),
        "minimap_width": num("minimap_width", 10),
        "colors": colors,
    }

ROOT = Path(__file__).resolve().parents[1]
SETTINGS = parse_settings(ROOT)
EXPLORER_COLS = SETTINGS["explorer_width"]
EXPLORER_W = EXPLORER_COLS * COL_W
MINIMAP_W = SETTINGS["minimap_width"] * COL_W

# Palette comes from config/lua/go_ide/settings.lua. Fallbacks only keep this
# documentation helper usable if a color is temporarily absent during edits.
_defaults = {
    "bg": "#1a1b26", "bg_inactive": "#181923", "panel": "#16161e", "chrome": "#171821",
    "active_tab": "#24283b", "selection": "#292e42", "line": "#292e42", "border": "#1c1e2b",
    "fg": "#c0caf5", "fg_dim": "#a9b1d6", "muted": "#565f89", "hidden": "#424455",
    "gutter": "#3b4261", "comment": "#565f89", "coral": "#f7768e", "teal": "#0db9d7",
    "purple": "#9d7cd8", "mauve": "#bb9af7", "orange": "#ff9e64", "blue": "#7aa2f7",
    "cyan": "#7dcfff", "green": "#9ece6a", "red": "#f7768e", "yellow": "#e0af68",
    "go_icon": "#00add8", "member": "#73daca", "visual": "#283457",
}
C = {**_defaults, **SETTINGS["colors"]}
# Pinned lualine Horizon palette from lualine.nvim@221ce6b2d999187044529f49da6554a92f740a96.
C.update({
    "hz_black": "#1c1e26", "hz_white": "#6C6F93", "hz_gray": "#E95678",
    "hz_dark": "#1A1C23", "hz_light": "#2E303E",
})


FONT_DIR = Path("/usr/share/fonts/truetype/dejavu")
REG = FONT_DIR / "DejaVuSansMono.ttf"
BOLD = FONT_DIR / "DejaVuSansMono-Bold.ttf"
ITAL = FONT_DIR / "DejaVuSansMono-Oblique.ttf"

F = {
    "ui": ImageFont.truetype(str(REG), 18),
    "ui_b": ImageFont.truetype(str(BOLD), 18),
    "small": ImageFont.truetype(str(REG), 15),
    "code": ImageFont.truetype(str(REG), 19),
    "code_b": ImageFont.truetype(str(BOLD), 19),
    "code_i": ImageFont.truetype(str(ITAL), 19),
    "status": ImageFont.truetype(str(BOLD), 17),
}

SAMPLE = (ROOT / "sample-project/main.go").read_text(encoding="utf-8")


def font(style: str):
    return F["code_i"] if style == "i" else F["code_b"] if style == "b" else F["code"]


def token_style(ttype, value):
    if ttype in Comment or str(ttype).startswith("Token.Comment"):
        return C["comment"], "i"
    if ttype in Keyword or str(ttype).startswith("Token.Keyword"):
        return C["purple"], "i"
    if ttype in String or str(ttype).startswith("Token.Literal.String"):
        return C["green"], "r"
    if ttype in Number or str(ttype).startswith("Token.Literal.Number"):
        return C["orange"], "r"
    if ttype in Operator or str(ttype).startswith("Token.Operator"):
        return C["cyan"], "r"
    if ttype in Name.Function or str(ttype).startswith("Token.Name.Function"):
        return C["blue"], "r"
    if ttype in Name.Class or ttype in Name.Builtin or str(ttype).startswith("Token.Name.Class"):
        return C["teal"], "r"
    if ttype in Name.Namespace:
        return C["cyan"], "r"
    if ttype in Punctuation:
        return C["fg_dim"], "r"
    return C["fg"], "r"


def draw_text_segments(draw, x, y, line):
    # Pygments tokenizes a whole string; keeping tabs as 4 columns preserves Go layout.
    cur = x
    for ttype, value in lex(line, GoLexer()):
        value = value.rstrip("\n")
        if not value:
            continue
        if value.startswith("\t"):
            n = len(value) - len(value.lstrip("\t"))
            for _ in range(n):
                draw.text((cur, y), "»", font=F["small"], fill=C["gutter"])
                cur += COL_W * 4
            value = value[n:]
        value = value.replace("\t", "    ")
        col, st = token_style(ttype, value)
        ft = font(st)
        draw.text((cur, y), value, font=ft, fill=col)
        cur += draw.textlength(value, font=ft)
    return cur


def chevron(draw, x0, x1, y0, y1, fill, left=False, right=True):
    mid = (y0 + y1) // 2
    pts = []
    if left:
        pts += [(x0 + 14, y0), (x0, mid), (x0 + 14, y1)]
    else:
        pts += [(x0, y0), (x0, y1)]
    if right:
        pts += [(x1 - 14, y1), (x1, mid), (x1 - 14, y0)]
    else:
        pts += [(x1, y1), (x1, y0)]
    draw.polygon(pts, fill=fill)


def build(output: Path):
    im = Image.new("RGB", (W, H), C["bg"])
    d = ImageDraw.Draw(im)

    # Base panes and editor chrome.
    d.rectangle((0, 0, EXPLORER_W, H), fill=C["panel"])
    d.rectangle((EXPLORER_W, 0, W, TAB_H), fill=C["chrome"])
    d.rectangle((EXPLORER_W, TAB_H, W, EDITOR_TOP), fill=C["chrome"])

    # Tabline: Explorer label occupies exactly the explorer width.
    d.text((10, 7), " Explorer", font=F["ui"], fill=C["fg_dim"])

    # Active tab is the config's powerline-cap capsule; inactive tabs blend into chrome.
    tx = EXPLORER_W + 16
    tab_w = 145
    d.rounded_rectangle((tx, 3, tx + tab_w, TAB_H - 3), radius=14, fill=C["active_tab"])
    d.rounded_rectangle((tx + 18, 9, tx + 30, 21), radius=2, fill=C["go_icon"])
    d.text((tx + 40, 7), "main.go", font=F["ui_b"], fill=C["fg"])
    d.text((tx + tab_w + 26, 7), "main_test.go", font=F["ui"], fill=C["muted"])
    d.text((tx + tab_w + 188, 7), "go.mod", font=F["ui"], fill=C["muted"])

    # Breadcrumb row from ui.lua/navic.
    bx = EXPLORER_W + 20
    d.rounded_rectangle((bx, TAB_H + 9, bx + 11, TAB_H + 20), radius=2, fill=C["go_icon"])
    d.text((bx + 22, TAB_H + 5), "main.go", font=F["ui"], fill=C["fg_dim"])
    d.text((bx + 110, TAB_H + 5), "›", font=F["ui"], fill=C["muted"])
    d.text((bx + 135, TAB_H + 5), "NewCliConfig", font=F["ui"], fill=C["blue"])

    # Neo-tree root + files. No visible window separator by design.
    y = 42
    d.text((10, y), "▾", font=F["ui"], fill=C["gutter"])
    d.text((32, y), "~/code/golang/scratch", font=F["ui_b"], fill=C["fg_dim"])
    tree = [
        ("example.txt", C["green"]),
        ("go.mod", C["go_icon"]),
        ("main.go", C["go_icon"]),
        ("main_test.go", C["go_icon"]),
    ]
    for i, (name, color) in enumerate(tree):
        yy = 72 + i * 28
        if name == "main.go":
            d.rectangle((0, yy - 2, EXPLORER_W, yy + 24), fill=C["active_tab"])
        if name.endswith(".go") or name == "go.mod":
            d.rounded_rectangle((28, yy + 5, 38, yy + 15), radius=2, fill=color)
        else:
            d.rectangle((28, yy + 6, 37, yy + 15), fill=color)
        d.text((50, yy), name, font=F["ui"], fill=C["fg_dim"])
    d.text((32, 72 + len(tree)*28 + 4), "(2 hidden items)", font=F["small"], fill=C["hidden"])

    # Editor code.
    code_x = EXPLORER_W + 78
    number_x = EXPLORER_W + 58
    first_y = EDITOR_TOP + 18
    lines = SAMPLE.splitlines()
    current_line = 29  # NewCliConfig declaration
    visible = lines[:42]
    for idx, line in enumerate(visible, start=1):
        yy = first_y + (idx - 1) * ROW_H
        if yy >= EDITOR_BOTTOM - ROW_H:
            break
        rel = abs(idx - current_line)
        label = str(idx if idx == current_line else rel)
        if idx == current_line:
            d.rectangle((EXPLORER_W + 68, yy - 2, W - MINIMAP_W - 42, yy + ROW_H - 2), fill=C["line"])
        nfont = F["code_b"] if idx == current_line else F["code"]
        ncolor = C["orange"] if idx == current_line else C["gutter"]
        tw = d.textlength(label, font=nfont)
        d.text((number_x - tw, yy), label, font=nfont, fill=ncolor)
        draw_text_segments(d, code_x, yy, line)

    # Cursor on the active line.
    cy = first_y + (current_line - 1) * ROW_H
    cursor_x = code_x + 5 * COL_W
    d.rectangle((cursor_x, cy + 2, cursor_x + 2, cy + 21), fill=C["orange"])

    # Minimap: 10 terminal columns, no border, background screen bounds.
    mini_x0 = W - MINIMAP_W - 18
    mini_y0 = EDITOR_TOP + 16
    mini_h = 225
    d.rectangle((mini_x0, mini_y0, W - 18, mini_y0 + mini_h), fill=C["bg_inactive"])
    for row, line in enumerate(visible[:36]):
        yy = mini_y0 + 8 + row * 5
        if yy >= mini_y0 + mini_h - 5:
            break
        stripped = line.strip()
        if not stripped:
            continue
        x = mini_x0 + 8 + min(len(line) - len(line.lstrip()), 5) * 4
        color = C["purple"] if stripped.startswith(("func ", "type ", "return ", "for ", "if ")) else C["cyan"]
        if '"' in stripped:
            color = C["green"]
        ln = min(70, max(10, len(stripped) * 2))
        d.rectangle((x, yy, x + ln, yy + 2), fill=color)
    view_y = mini_y0 + 104
    d.rectangle((mini_x0 + 8, view_y, mini_x0 + 17, view_y + 30), outline=C["fg"], width=2)

    # Per-pane statuslines. Explorer's own statusline stays separate from lualine.
    sy = H - STATUS_H
    d.rectangle((0, sy, EXPLORER_W, H), fill=C["panel"])
    d.text((8, sy + 6), "neo-tree filesystem [1] [-]", font=F["small"], fill=C["hidden"])
    right = "4:5"
    rw = d.textlength(right, font=F["small"])
    d.text((EXPLORER_W - rw - 12, sy + 6), right, font=F["small"], fill=C["muted"])

    # lualine Horizon normal mode: a/c on left; x/y/z on right.
    d.rectangle((EXPLORER_W, sy, W, H), fill=C["hz_dark"])
    mode_x0 = EXPLORER_W
    mode_x1 = mode_x0 + 118
    chevron(d, mode_x0, mode_x1, sy, H, C["hz_gray"], left=False, right=True)
    d.text((mode_x0 + 16, sy + 5), "NORMAL", font=F["status"], fill=C["hz_black"])
    d.text((mode_x1 + 12, sy + 6), "main.go", font=F["small"], fill=C["hz_white"])

    # right-aligned lualine sections
    loc_w, prog_w = 92, 78
    loc_x0 = W - loc_w
    chevron(d, loc_x0, W, sy, H, C["hz_gray"], left=True, right=False)
    d.text((loc_x0 + 25, sy + 5), "29:10", font=F["status"], fill=C["hz_black"])

    prog_x0 = loc_x0 - prog_w
    chevron(d, prog_x0, loc_x0 + 14, sy, H, C["hz_light"], left=True, right=False)
    d.text((prog_x0 + 22, sy + 6), "63%", font=F["small"], fill=C["hz_white"])

    info = "utf-8   unix   Go"
    iw = d.textlength(info, font=F["small"])
    info_x = prog_x0 - iw - 34
    d.text((info_x, sy + 6), "utf-8", font=F["small"], fill=C["hz_white"])
    # component separators are the configured right-facing light separators, represented geometrically.
    d.text((info_x + 58, sy + 5), "‹", font=F["ui"], fill=C["hz_white"])
    d.text((info_x + 80, sy + 6), "unix", font=F["small"], fill=C["hz_white"])
    d.text((info_x + 126, sy + 5), "‹", font=F["ui"], fill=C["hz_white"])
    d.rounded_rectangle((info_x + 150, sy + 8, info_x + 160, sy + 18), radius=2, fill=C["go_icon"])
    d.text((info_x + 166, sy + 6), "go", font=F["small"], fill=C["hz_white"])

    output.parent.mkdir(parents=True, exist_ok=True)
    im.save(output, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default="docs/nvim-go-workbench.png")
    args = ap.parse_args()
    build(Path(args.output))

if __name__ == "__main__":
    main()