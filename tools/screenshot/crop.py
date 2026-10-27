"""Cuts the popup out of a full-screen shot: the window off the black desktop, its frame
and title bar off, the content trimmed and given an even margin."""
import sys

from PIL import Image, ImageChops

shot = Image.open(sys.argv[1]).convert("RGB")
margin = int(sys.argv[3]) if len(sys.argv) > 3 else 20

def box(image, colour, threshold):
    diff = ImageChops.difference(image, Image.new("RGB", image.size, colour))
    return diff.point(lambda v: 255 if v > threshold else 0).getbbox()

window = shot.crop(box(shot, (0, 0, 0), 8))
# 1px frame at the sides, a 27px title bar, and rounded corners at the bottom.
body = window.crop((1, 27, window.width - 1, window.height - 24))
background = body.getpixel((body.width // 2, body.height - 2))
content = body.crop(box(body, background, 10))
out = Image.new("RGB", (content.width + 2 * margin, content.height + 2 * margin), background)
out.paste(content, (margin, margin))
out.save(sys.argv[2])
