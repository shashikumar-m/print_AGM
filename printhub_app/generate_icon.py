"""
Generates PrintHub app icons using Pillow.
Run: python generate_icon.py
"""
from PIL import Image, ImageDraw
import os

os.makedirs('assets/icon', exist_ok=True)

SIZE = 1024
INDIGO = (79, 70, 229)
WHITE  = (255, 255, 255)
LIGHT  = (199, 210, 254)   # indigo-200
GREEN  = (52, 211, 153)    # emerald
GREY   = (224, 231, 255)   # indigo-100

def draw_printer(draw, size, bg_alpha=255):
    s = size / 1024

    def sc(v):
        """Scale a 1024-space value."""
        return int(v * s)

    def srect(x, y, w, h):
        return [sc(x), sc(y), sc(x+w), sc(y+h)]

    # ── Printer body ──────────────────────────────────────────
    body_color = WHITE
    draw.rounded_rectangle(srect(180, 310, 664, 360), radius=sc(56), fill=body_color)

    # ── Paper coming out of top ───────────────────────────────
    paper_color = (248, 250, 255)
    draw.rounded_rectangle(srect(330, 130, 364, 210), radius=sc(14), fill=paper_color)
    # Lines on paper
    for ly in [175, 210, 245]:
        draw.rounded_rectangle(srect(370, ly, 284, 14), radius=sc(7), fill=LIGHT)

    # ── Top slot (paper exit) ─────────────────────────────────
    draw.rounded_rectangle(srect(290, 298, 444, 28), radius=sc(8), fill=LIGHT)

    # ── Ventilation slots on body ─────────────────────────────
    for vx in range(220, 540, 44):
        draw.rounded_rectangle(srect(vx, 390, 20, 90), radius=sc(10), fill=GREY)

    # ── Control panel area ────────────────────────────────────
    draw.rounded_rectangle(srect(560, 370, 240, 130), radius=sc(20), fill=GREY)
    # Status LED (green)
    draw.ellipse(srect(590, 400, 44, 44), fill=GREEN)
    # Two grey dots
    draw.ellipse(srect(660, 400, 44, 44), fill=LIGHT)
    draw.ellipse(srect(720, 400, 44, 44), fill=LIGHT)
    # Small line
    draw.rounded_rectangle(srect(590, 460, 174, 16), radius=sc(8), fill=LIGHT)

    # ── Paper input tray (bottom) ─────────────────────────────
    draw.rounded_rectangle(srect(240, 658, 544, 56), radius=sc(12), fill=GREY)
    draw.rounded_rectangle(srect(260, 672, 504, 28), radius=sc(8), fill=LIGHT)


def make_full_icon(size):
    """Full icon with indigo circle background."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Circle background
    draw.ellipse([0, 0, size-1, size-1], fill=(*INDIGO, 255))

    draw_printer(draw, size)
    return img


def make_fg_icon(size):
    """Foreground only (transparent bg) for adaptive icon."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_printer(draw, size)
    return img


print("Generating app_icon.png (1024×1024)...")
full = make_full_icon(SIZE)
full.save('assets/icon/app_icon.png', 'PNG')
print(f"  Saved assets/icon/app_icon.png")

print("Generating app_icon_fg.png (foreground for adaptive)...")
fg = make_fg_icon(SIZE)
fg.save('assets/icon/app_icon_fg.png', 'PNG')
print(f"  Saved assets/icon/app_icon_fg.png")

print("\nDone! Now run:")
print("  flutter pub get")
print("  dart run flutter_launcher_icons")
