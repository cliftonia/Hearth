"""Draws the app icon: a ring of embers on pine. Run with `python3 Tools/make_icon.py`."""
from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4
side = SIZE * SCALE
image = Image.new("RGB", (side, side), (0x2C, 0x6B, 0x5A))
draw = ImageDraw.Draw(image)
for step in range(side):
    shade = step / side
    draw.line([(0, step), (side, step)], fill=(int(0x34 - 0x12 * shade), int(0x7A - 0x24 * shade), int(0x67 - 0x20 * shade)))
center, radius, stroke = side / 2, side * 0.23, side * 0.085
draw.ellipse([center - radius, center - radius, center + radius, center + radius], outline=(255, 255, 255), width=int(stroke))
image.resize((SIZE, SIZE), Image.LANCZOS).save("App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
