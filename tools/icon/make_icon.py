"""Draws the app icon from the panel's own parts: the ring and the standing figure.

    python3 tools/icon/make_icon.py

Writes package/contents/screenshot.png, which Plasma's Add Widgets list shows in place of
the theme icon - and which, unlike that icon, ships inside the package, so it shows for a
store install too - and screenshots/logo.png for the KDE Store.
"""
import math
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
FIGURE = ROOT / "package/contents/icons/person-stand.svg"


def figure_paths(colour):
    svg = FIGURE.read_text()
    shapes = [l.strip() for l in svg.splitlines() if l.strip().startswith(("<circle", "<path"))]
    return "\n".join(re.sub(r'class="[^"]*" ', "", s).replace("currentColor", colour) for s in shapes)


def icon_svg(size, corner, fraction=0.62):
    c = size / 2
    r = size * 0.36
    stroke = size * 0.06
    end = -math.pi / 2 + 2 * math.pi * fraction
    x, y = c + r * math.cos(end), c + r * math.sin(end)
    scale = size * 0.026
    offset = c - 8 * scale
    background = (f'<rect width="{size}" height="{size}" rx="{size * corner}" fill="#2a2e32"/>'
                  if corner is not None else f'<rect width="{size}" height="{size}" fill="#2a2e32"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
 {background}
 <circle cx="{c}" cy="{c}" r="{r}" fill="none" stroke="#4d5257" stroke-width="{stroke}"/>
 <path d="M {c} {c - r} A {r} {r} 0 1 1 {x:.2f} {y:.2f}" fill="none" stroke="#3daee9"
       stroke-width="{stroke}" stroke-linecap="round"/>
 <g transform="translate({offset:.2f} {offset:.2f}) scale({scale:.4f})">
{figure_paths("#eff0f1")}
 </g>
</svg>'''


def render(svg, out):
    subprocess.run(["rsvg-convert", "-o", str(out)], input=svg.encode(), check=True)


# Rounded like an app icon, transparent outside, for the widget list.
render(icon_svg(256, corner=0.22), ROOT / "package/contents/screenshot.png")
# Square for the store, which crops its own corners.
render(icon_svg(342, corner=None), ROOT / "screenshots/logo.png")
