#!/usr/bin/env python3
"""Render docs/demo.gif — the 30-second dsh-plugin-hub demo.

Every line of terminal output below was captured from a real run in a sandbox
home directory (see demo-sandbox.ps1); the only edit is the user-profile
prefix, rewritten to the documentation placeholder C:\\Users\\you. Nothing in
the frames is invented output.

Requires: Pillow. Usage:  python make-demo-gif.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
W, H = 960, 600
TICK = 80  # ms per animation tick (12.5 fps)

# ---- palette (matches docs/doctor-demo.png) --------------------------------
BG_WIN = (23, 25, 31)
BG_BAR = (29, 32, 40)
BG_TERM = (16, 18, 22)
BORDER = (42, 45, 54)
TXT = (201, 209, 217)
DIM = (139, 148, 158)
PROMPT = (111, 207, 151)
PASS = (74, 222, 128)
WARN = (245, 158, 11)
ACCENT = (126, 231, 135)
BLUE = (88, 166, 255)
RED_DOT, YEL_DOT, GRN_DOT = (255, 95, 86), (255, 189, 46), (39, 201, 63)

FONT_DIR = "C:/Windows/Fonts/"
F_REG = ImageFont.truetype(FONT_DIR + "consola.ttf", 17)
F_BOLD = ImageFont.truetype(FONT_DIR + "consolab.ttf", 17)
F_TITLE = ImageFont.truetype(FONT_DIR + "consola.ttf", 14)
F_BIG = ImageFont.truetype(FONT_DIR + "consolab.ttf", 26)
F_BIG_REG = ImageFont.truetype(FONT_DIR + "consola.ttf", 19)

PAD_X, PAD_TOP, LINE = 44, 96, 25
CONTENT_W = W - 2 * PAD_X

# ---- captured output (see module docstring) --------------------------------
INSTALL_CMD = ".\\install.ps1"

INSTALL_OUT = [
    ("hdr", "== dsh-plugin-hub install =="),
    ("txt", "hub files -> C:\\Users\\you\\.dsh-hub\\dsh-plugin-hub"),
    ("txt", "config.ps1 created from example \u2014 edit paths to fit your machine"),
    ("txt", "ps1 files normalized to UTF-8 BOM"),
    ("txt", "junction created: C:\\Users\\you\\.dsh\\skills\\dsh-plugin-hub -> C:\\Users\\you\\.dsh-hub\\dsh-plugin-hub"),
    ("gap", ""),
    ("txt", "Done. Next steps:"),
    ("txt", "  1. Edit C:\\Users\\you\\.dsh-hub\\dsh-plugin-hub\\config.ps1"),
    ("txt", "  2. Restart DSH (or reload its Web UI) so the skill hot-loads"),
    ("txt", "  3. In a DSH session, ask: which plugins are installed / how do I use memory?"),
]

DOCTOR_CMD = ".\\doctor.ps1"
DOCTOR_OUT = [
    ("pass", "[PASS] config.ps1 present, UTF-8 BOM ok"),
    ("pass", "[PASS] dsh CLI found"),
    ("dim", "       D:\\Program Files (x86)\\deepseek harness\\resources\\runtime\\cli\\bin\\dsh.cmd"),
    ("pass", "[PASS] dsh plugin list exits 0 (no peer-dependency breakage)"),
    ("pass", "[PASS] junction points here"),
    ("dim", "       C:\\Users\\you\\.dsh\\skills\\dsh-plugin-hub -> C:\\Users\\you\\.dsh-hub\\dsh-plugin-hub"),
    ("pass", "[PASS] SKILL.md present (installed layout)"),
    ("warn", "[WARN] hindsight DOWN on port 8888"),
    ("dim", "       memory tools will fake-fail; start the service, then re-check."),
    ("pass", "[PASS] tool agent-browser: C:\\Users\\you\\.dsh-hub\\skills\\agent-browser\\ab.cmd"),
    ("pass", "[PASS] tool whisper: C:\\Users\\you\\.dsh-hub\\skills\\local-whisper\\whisper-cli.exe"),
    ("pass", "[PASS] tool skill-scanner: C:\\Users\\you\\.dsh-hub\\skills\\skill-scanner\\scan-skill.cmd"),
    ("gap", ""),
    ("ok", "doctor: no FAIL items."),
]

PAIN = [
    "7 plugins. 3 skill directories.",
    "Built-in tools you forgot about.",
    "",
    "Which one does what \u2014",
    "and is it actually running?",
]

PAYOFF = [
    ("head", "hub routing table + status, in one answer"),
    ("gap", ""),
    ("q", 'you  \u203a which plugin handles long-term memory?'),
    ("gap", ""),
    ("a", "hub  \u203a dsh-hindsight \u2014 hindsight_* tools  (routing table row)"),
    ("a2", "       service :8888  DOWN  \u2014 memory calls would fake-succeed"),
    ("a2", "       rule: confirm status first, never pretend a call succeeded"),
    ("gap", ""),
    ("ok", "\u2192 the agent answers with the truth, not a guess."),
]

CTA = [
    ("url", "github.com/Charles950311/dsh-plugin-hub"),
    ("sub", "MIT \u00b7 install.ps1 \u00b7 status.ps1 \u00b7 doctor.ps1 \u00b7 provenance"),
    ("sub2", "TaintLens Studio"),
]


def base_window() -> Image.Image:
    img = Image.new("RGB", (W, H), BG_WIN)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W - 1, H - 1], 14, fill=BG_WIN, outline=BORDER, width=1)
    d.rounded_rectangle([1, 1, W - 2, 44], 13, fill=BG_BAR)
    d.rectangle([1, 30, W - 2, 44], fill=BG_BAR)
    for i, c in enumerate((RED_DOT, YEL_DOT, GRN_DOT)):
        cx = 26 + i * 22
        d.ellipse([cx - 6, 16, cx + 6, 28], fill=c)
    d.text((W // 2, 22), "Windows PowerShell \u2014 dsh-plugin-hub",
           font=F_TITLE, fill=(150, 158, 170), anchor="mm")
    d.rounded_rectangle([16, 56, W - 16, H - 16], 10, fill=BG_TERM)
    return img


COLORS = {"pass": PASS, "warn": WARN, "dim": DIM, "hdr": BLUE, "txt": TXT,
          "gap": TXT, "ok": ACCENT}


def draw_terminal(prompt: str, typed: str, shown: list[tuple[str, str]],
                  cursor: bool = True) -> Image.Image:
    img = base_window()
    d = ImageDraw.Draw(img)
    y = PAD_TOP
    # The prompt line stays pinned; history below it scrolls once it would
    # run past the terminal floor.
    if prompt:
        d.text((PAD_X, y), prompt, font=F_BOLD, fill=PROMPT)
        px = PAD_X + d.textlength(prompt, font=F_BOLD) + 8
        if typed:
            d.text((px, y), typed, font=F_REG, fill=TXT)
        if cursor:
            cx = px + d.textlength(typed, font=F_REG) + 2
            d.rectangle([cx, y + 2, cx + 9, y + 19], fill=TXT)
        y += LINE
    capacity = max(1, (H - 16 - y) // LINE)
    visible = shown
    if len(visible) > capacity:
        visible = visible[len(visible) - capacity:]
    # when scrolled, keep the first visible line flush with the top
    if len(shown) > capacity:
        y -= 2
    for kind, text in visible:
        if kind == "gap":
            y += LINE - 6
            continue
        d.text((PAD_X, y), text, font=F_REG, fill=COLORS.get(kind, TXT))
        y += LINE
    return img


def draw_card(lines: list[tuple[str, str]], sub: str = "") -> Image.Image:
    """Full-terminal card: centered blocks with per-line style."""
    img = base_window()
    d = ImageDraw.Draw(img)
    heights = [LINE + 10 for _ in lines]
    total = sum(heights) + (34 if sub else 0)
    y = (H - 56 - total) // 2 + 56
    for (kind, text), h in zip(lines, heights):
        if not text:
            y += h
            continue
        if kind == "big":
            font, color = F_BIG, TXT
        elif kind == "head":
            font, color = F_BOLD, DIM
        elif kind == "q":
            font, color = F_BOLD, PROMPT
        elif kind == "a":
            font, color = F_REG, TXT
        elif kind == "a2":
            font, color = F_REG, DIM
        elif kind == "ok":
            font, color = F_BOLD, ACCENT
        elif kind == "url":
            font, color = F_BIG, ACCENT
        elif kind == "sub":
            font, color = F_REG, DIM
        elif kind == "sub2":
            font, color = F_REG, BLUE
        else:
            font, color = F_BIG_REG, TXT
        d.text((PAD_X, y), text, font=font, fill=color)
        y += h
    if sub:
        d.text((PAD_X, y + 10), sub, font=F_REG, fill=DIM)
    return img


def main() -> int:
    frames: list[tuple[Image.Image, int]] = []

    def hold(img: Image.Image, ms: int):
        frames.append((img, ms))

    def type_cmd(prompt: str, cmd: str, shown: list[tuple[str, str]],
                 per_tick: int = 2, pause_ms: int = 200):
        for n in range(per_tick, len(cmd) + per_tick, per_tick):
            hold(draw_terminal(prompt, cmd[:n], shown, cursor=True), TICK)
        hold(draw_terminal(prompt, cmd, shown, cursor=True), pause_ms)

    # --- S1 pain card -------------------------------------------------------
    hold(draw_card([("big", l) for l in PAIN]), 3200)

    # --- S2 install ---------------------------------------------------------
    shown: list[tuple[str, str]] = []
    type_cmd("PS C:\\dsh-plugin-hub>", INSTALL_CMD, shown)
    for line in INSTALL_OUT:
        shown = shown + [line]
        hold(draw_terminal("PS C:\\dsh-plugin-hub>", "", shown, cursor=True),
             170 if line[0] != "gap" else 90)
    hold(draw_terminal("PS C:\\dsh-plugin-hub>", "", shown, cursor=True), 1100)

    # --- S3 doctor ----------------------------------------------------------
    shown = shown + [("gap", "")]
    type_cmd("PS C:\\dsh-plugin-hub>", DOCTOR_CMD, shown)
    for line in DOCTOR_OUT:
        shown = shown + [line]
        hold(draw_terminal("PS C:\\dsh-plugin-hub>", "", shown, cursor=True),
             250 if line[0] in ("pass", "warn", "ok") else 90)
    hold(draw_terminal("PS C:\\dsh-plugin-hub>", "", shown, cursor=True), 2400)

    # --- S4 payoff ----------------------------------------------------------
    hold(draw_card([(k, t) for k, t in PAYOFF]), 3600)

    # --- S5 CTA -------------------------------------------------------------
    hold(draw_card([(k, t) for k, t in CTA]), 3200)

    # ---- palette: one shared palette avoids shimmering between frames ------
    sample = [img for img, _ in frames[::7]]
    strip = Image.new("RGB", (W, H * len(sample)))
    for i, img in enumerate(sample):
        strip.paste(img, (0, i * H))
    palette = strip.quantize(colors=160, method=Image.MEDIANCUT)

    pal_frames = [img.quantize(palette=palette, dither=Image.NONE)
                  for img, _ in frames]
    durations = [ms for _, ms in frames]
    out = HERE / "demo.gif"
    pal_frames[0].save(out, save_all=True, append_images=pal_frames[1:],
                       duration=durations, loop=0, optimize=True,
                       disposal=1)
    total_ms = sum(durations)
    print(f"wrote {out} ({out.stat().st_size/1024:.0f} KB, "
          f"{len(pal_frames)} frames, {total_ms/1000:.1f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
