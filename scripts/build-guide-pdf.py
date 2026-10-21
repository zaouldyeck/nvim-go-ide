#!/usr/bin/env python3
"""Build the complete printable guide from the repository's Markdown sources.

Documentation-only dependencies: python3 -m pip install reportlab matplotlib
Usage: python3 scripts/build-guide-pdf.py [--output /path/to/guide.pdf]

The Markdown sources remain authoritative. This renderer supports their
headings, paragraphs, numbered/bulleted lists, tables, code blocks, and images.
"""

from __future__ import annotations

import argparse
import html
import importlib.util
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    Image,
    KeepTogether,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Table,
    TableStyle,
    XPreformatted,
)


ROOT = Path(__file__).resolve().parents[1]
GUIDE = ROOT / "docs/GETTING_STARTED.md"
SHORTCUTS = ROOT / "docs/SHORTCUTS.md"
SCREEN = ROOT / "docs/nvim-go-editor.png"
W, H = A4
MARGIN = 48
WIDTH = W - 2 * MARGIN
INK = colors.HexColor("#16232b")
MUTED = colors.HexColor("#52636c")
TEAL = colors.HexColor("#237e7c")
BLUE = colors.HexColor("#286c8a")
PALE = colors.HexColor("#f2f6f7")
BORDER = colors.HexColor("#d8e2e5")
DARK = colors.HexColor("#1a1b26")


def register_fonts():
    """Use Matplotlib's bundled DejaVu fonts without platform-specific paths."""
    spec = importlib.util.find_spec("matplotlib")
    if spec is None or spec.origin is None:
        raise SystemExit("Install documentation dependencies: python3 -m pip install reportlab matplotlib")
    font_dir = Path(spec.origin).parent / "mpl-data/fonts/ttf"
    for name, filename in [
        ("Body", "DejaVuSans.ttf"),
        ("Body-Bold", "DejaVuSans-Bold.ttf"),
        ("Body-Italic", "DejaVuSans-Oblique.ttf"),
        ("Body-BoldItalic", "DejaVuSans-BoldOblique.ttf"),
        ("Mono", "DejaVuSansMono.ttf"),
        ("Mono-Bold", "DejaVuSansMono-Bold.ttf"),
    ]:
        pdfmetrics.registerFont(TTFont(name, str(font_dir / filename)))
    pdfmetrics.registerFontFamily(
        "Body", normal="Body", bold="Body-Bold", italic="Body-Italic", boldItalic="Body-BoldItalic"
    )
    pdfmetrics.registerFontFamily(
        "Mono", normal="Mono", bold="Mono-Bold", italic="Mono", boldItalic="Mono-Bold"
    )


STYLES = {
    "body": ParagraphStyle("Body", fontName="Body", fontSize=9.6, leading=13.8,
                           textColor=INK, spaceAfter=7, allowWidows=0, allowOrphans=0),
    "h1": ParagraphStyle("Heading1", fontName="Body-Bold", fontSize=17.8, leading=23,
                         textColor=INK, spaceBefore=16, spaceAfter=9, keepWithNext=True),
    "h2": ParagraphStyle("Heading2", fontName="Body-Bold", fontSize=11.8, leading=16,
                         textColor=BLUE, spaceBefore=9, spaceAfter=5, keepWithNext=True),
    "cell": ParagraphStyle("Cell", fontName="Body", fontSize=8.65, leading=12.1,
                           textColor=INK, allowWidows=0, allowOrphans=0),
    "thead": ParagraphStyle("TableHead", fontName="Body-Bold", fontSize=8.5,
                            leading=11.5, textColor=colors.white),
    "code": ParagraphStyle("Code", fontName="Mono", fontSize=8.15, leading=11.1,
                           textColor=INK, spaceAfter=0),
    "small": ParagraphStyle("Small", fontName="Body", fontSize=8.2, leading=11.5,
                            textColor=MUTED, spaceAfter=8),
    "list": ParagraphStyle("List", fontName="Body", fontSize=9.6, leading=13.8,
                           textColor=INK, leftIndent=16, firstLineIndent=-16,
                           spaceAfter=7, allowWidows=0, allowOrphans=0),
}


def clean(text):
    for character in ("\u2011", "\u2010", "\u2013", "\u2014"):
        text = text.replace(character, "-")
    return text.replace("\u00a0", " ")


def inline(text):
    protected = []

    def hold(value):
        protected.append(value)
        return f"ZZZPLACEHOLDER{len(protected) - 1}ZZZ"

    text = clean(text)
    text = re.sub(
        r"`([^`]+)`",
        lambda match: hold('<font name="Mono" size="8.5">' + html.escape(match[1]) + "</font>"),
        text,
    )
    text = re.sub(
        r"\[([^\]]+)\]\((https?://[^)]+)\)",
        lambda match: hold('<link href="' + html.escape(match[2], quote=True)
                           + '" color="#286c8a"><u>' + html.escape(match[1]) + "</u></link>"),
        text,
    )
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    for index, value in enumerate(protected):
        text = text.replace(f"ZZZPLACEHOLDER{index}ZZZ", value)
    return text


def paragraph(text, style="body"):
    return Paragraph(inline(text), STYLES[style])


def make_table(rows):
    columns = len(rows[0])
    if any(len(row) != columns for row in rows):
        raise ValueError(f"Inconsistent Markdown table: {rows[0]!r}")
    if columns == 3:
        fractions = [0.17, 0.44, 0.39] if rows[0][0] == "Mode" else [0.38, 0.28, 0.34]
    elif columns == 2:
        fractions = [0.30, 0.70] if rows[0][0] in ("Command", "Trigger") else [0.48, 0.52]
    else:
        fractions = [1 / columns] * columns
    cells = [[paragraph(cell, "thead" if row_index == 0 else "cell") for cell in row]
             for row_index, row in enumerate(rows)]
    padding = 5 if rows[0][0] == "Trigger" else 6
    table = Table(cells, colWidths=[WIDTH * fraction for fraction in fractions],
                  repeatRows=1, hAlign="LEFT", spaceAfter=9)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), BLUE),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PALE]),
        ("LINEBELOW", (0, 0), (-1, 0), 0.6, BLUE),
        ("LINEBELOW", (0, -1), (-1, -1), 0.5, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), padding),
        ("BOTTOMPADDING", (0, 0), (-1, -1), padding),
    ]))
    return table


def codebox(text):
    text = clean(text).expandtabs(4)
    longest = max((pdfmetrics.stringWidth(line, "Mono", STYLES["code"].fontSize)
                   for line in text.splitlines()), default=0)
    if longest > WIDTH - 20:
        raise ValueError("A code line exceeds the printable width; wrap it in the Markdown source.")
    content = XPreformatted(html.escape(text), STYLES["code"])
    box = Table([[content]], colWidths=[WIDTH], hAlign="LEFT", spaceBefore=2, spaceAfter=10)
    box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE),
        ("LINEBEFORE", (0, 0), (0, -1), 2, TEAL),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
    ]))
    return box


class Cover(Flowable):
    def __init__(self):
        super().__init__()
        self.width = WIDTH
        self.height = H - 95

    def draw(self):
        canvas = self.canv
        top = self.height
        canvas.setFillColor(colors.HexColor("#2ac3de"))
        canvas.setFont("Mono-Bold", 11)
        canvas.drawString(0, top - 12, "NVIM-GO / DAILY DRIVER")
        canvas.setFillColor(colors.white)
        canvas.setFont("Body-Bold", 40)
        canvas.drawString(0, top - 77, "Your Go IDE,")
        canvas.drawString(0, top - 126, "in Neovim.")
        canvas.setFillColor(colors.HexColor("#c0caf5"))
        canvas.setFont("Body", 15)
        canvas.drawString(0, top - 162, "Getting started + complete shortcut reference")
        canvas.setFont("Body", 10)
        canvas.drawString(0, top - 196, "Built for Fedora Asahi Remix and the way you write Go.")
        for index, (label, color) in enumerate([
            ("EDIT", "#9ece6a"), ("TEST", "#7aa2f7"), ("DEBUG", "#bb9af7")
        ]):
            canvas.setFillColor(colors.HexColor(color))
            canvas.roundRect(index * 89, top - 238, 77, 24, 5, fill=1, stroke=0)
            canvas.setFillColor(DARK)
            canvas.setFont("Body-Bold", 8.5)
            canvas.drawCentredString(index * 89 + 38.5, top - 230, label)
        if not SCREEN.is_file():
            raise FileNotFoundError(SCREEN)
        screenshot = Image(str(SCREEN))
        scale = min(WIDTH / screenshot.imageWidth, 300 / screenshot.imageHeight)
        canvas.drawImage(str(SCREEN), 0, 136, width=screenshot.imageWidth * scale,
                         height=screenshot.imageHeight * scale, preserveAspectRatio=True,
                         anchor="sw", mask="auto")
        canvas.setFillColor(colors.HexColor("#a9b1d6"))
        canvas.setFont("Body", 7.5)
        canvas.drawString(0, 120, "Actual Neovim UI rendered from the configured editor.")
        canvas.drawString(0, 107, "Your Neovim style with the Go workflow. Font and spacing may vary.")
        canvas.setFillColor(colors.HexColor("#c0caf5"))
        canvas.setFont("Body", 8.5)
        canvas.drawString(0, 55, "INSTALL  /  USE YOUR SNIPPETS  /  TEST AND DEBUG")
        canvas.setFillColor(colors.HexColor("#a9b1d6"))
        canvas.setFont("Body", 8)
        canvas.drawString(0, 30, "Custom snippet workflow edition  /  Profile: nvim-go")
        canvas.drawString(0, 15, "github.com/zaouldyeck/nvim-go-ide")


class GuideDoc(BaseDocTemplate):
    section = "GETTING STARTED"
    anchor_count = 0

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph) and flowable.style.name in ("Heading1", "Heading2"):
            title = flowable.getPlainText()
            self.anchor_count += 1
            key = f"section-{self.anchor_count}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(title, key,
                                     level=0 if flowable.style.name == "Heading1" else 1,
                                     closed=False)
            if flowable.style.name == "Heading1":
                self.section = title


def footer(canvas, document, section=None):
    canvas.saveState()
    canvas.setFillColor(colors.white)
    canvas.rect(0, 0, W, H, fill=1, stroke=0)
    canvas.setStrokeColor(BORDER)
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN, H - 36, W - MARGIN, H - 36)
    canvas.setFont("Body-Bold", 7.7)
    canvas.setFillColor(BLUE)
    canvas.drawString(MARGIN, H - 25, "NVIM-GO")
    canvas.setFont("Body", 7.7)
    canvas.setFillColor(MUTED)
    title = clean(section or document.section)
    if len(title) > 73:
        title = title[:70] + "..."
    canvas.drawRightString(W - MARGIN, H - 25, title)
    canvas.line(MARGIN, 37, W - MARGIN, 37)
    canvas.setFont("Body", 7.5)
    canvas.drawString(MARGIN, 23, "Getting started  /  Fedora Asahi Remix  /  Go")
    canvas.drawRightString(W - MARGIN, 23, f"{document.page:02d}")
    canvas.restoreState()


def cover_background(canvas, document):
    canvas.setFillColor(DARK)
    canvas.rect(0, 0, W, H, fill=1, stroke=0)
    canvas.setFillColor(colors.HexColor("#2ac3de"))
    canvas.rect(0, H - 7, W, 7, fill=1, stroke=0)


def parse_markdown(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    flow = []
    index = 0
    boundary = re.compile(r"^(?:#|```|\||!\[|\d+\.\s|[-*]\s)")
    while index < len(lines):
        line = lines[index].strip()
        if not line or line.startswith("# "):
            index += 1
            continue
        if line.startswith("```"):
            block = []
            index += 1
            while index < len(lines) and not lines[index].strip().startswith("```"):
                block.append(lines[index])
                index += 1
            index += 1
            flow.append(codebox("\n".join(block)))
            continue
        if line.startswith("|"):
            rows = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                row = [value.strip() for value in lines[index].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", value.replace(" ", "")) for value in row):
                    rows.append(row)
                index += 1
            rendered_table = make_table(rows)
            if len(rows) <= 8:
                # Keep short reference tables, and their introduction, together.
                context = []
                if flow and isinstance(flow[-1], Paragraph):
                    context.insert(0, flow.pop())
                    if flow and isinstance(flow[-1], Paragraph) and flow[-1].style.name in ("Heading1", "Heading2"):
                        context.insert(0, flow.pop())
                flow.append(KeepTogether(context + [rendered_table]))
            else:
                flow.append(rendered_table)
            continue
        if line.startswith("## ") or line.startswith("### "):
            heading, style = (line[3:], "h1") if line.startswith("## ") else (line[4:], "h2")
            flow.append(paragraph(heading, style))
            index += 1
            continue
        image_match = re.fullmatch(r"!\[([^\]]*)\]\(([^)]+)\)", line)
        if image_match:
            image_path = path.parent / image_match[2]
            screenshot = Image(str(image_path))
            scale = min(WIDTH / screenshot.imageWidth, 240 / screenshot.imageHeight)
            screenshot.drawWidth = screenshot.imageWidth * scale
            screenshot.drawHeight = screenshot.imageHeight * scale
            screenshot.hAlign = "LEFT"
            flow.append(KeepTogether([screenshot, paragraph(image_match[1], "small")]))
            index += 1
            continue
        list_match = re.match(r"^(\d+\.|[-*])\s+(.+)$", line)
        if list_match:
            marker = "-" if list_match[1] in ("-", "*") else list_match[1]
            flow.append(paragraph(marker + "  " + list_match[2], "list"))
            index += 1
            continue
        block = [line]
        index += 1
        while index < len(lines) and lines[index].strip() and not boundary.match(lines[index].strip()):
            block.append(lines[index].strip())
            index += 1
        flow.append(paragraph(" ".join(block)))
    return flow


def build(output):
    register_fonts()
    output.parent.mkdir(parents=True, exist_ok=True)
    document = GuideDoc(
        str(output), pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=53, bottomMargin=49, title="Go IDE for Neovim - Getting started and shortcuts",
        author="Personal Go workspace", subject="Installation, custom snippets, Go editing, tests and debugging",
        creator="scripts/build-guide-pdf.py / ReportLab", pageCompression=1,
    )
    main = Frame(MARGIN, 49, WIDTH, H - 102, id="main",
                 leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    cover = Frame(MARGIN, 40, WIDTH, H - 80, id="cover",
                  leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    document.addPageTemplates([
        PageTemplate(id="Cover", frames=[cover], onPage=cover_background),
        PageTemplate(id="Main", frames=[main], onPage=footer),
        PageTemplate(id="Reference", frames=[main],
                     onPage=lambda canvas, doc: footer(canvas, doc, "SHORTCUT REFERENCE")),
    ])
    story = [Cover(), NextPageTemplate("Main"), PageBreak()]
    story += parse_markdown(GUIDE)
    story += [NextPageTemplate("Reference"), PageBreak(), paragraph("Shortcut reference", "h1")]
    story += parse_markdown(SHORTCUTS)

    def stable_canvas(*args, **kwargs):
        kwargs["invariant"] = True
        return Canvas(*args, **kwargs)

    document.build(story, canvasmaker=stable_canvas)
    print(f"Built {output} from docs/GETTING_STARTED.md and docs/SHORTCUTS.md")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "nvim-go-getting-started.pdf")
    args = parser.parse_args()
    build(args.output.resolve())


if __name__ == "__main__":
    main()
