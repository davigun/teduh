#!/usr/bin/env python3
"""Teduh app icon: a cream cross rising from a full open book, over warm clay.
Rendered at 4x and downsampled (LANCZOS) for smooth anti-aliased edges."""
import os
from PIL import Image, ImageDraw

S = 4
N = 1024
R = N * S

CREAM       = (245, 239, 228, 255)
CREAM_SHADE = (223, 207, 184, 255)   # gutter, page lines, page-stack thickness
CLAY_TOP    = (201, 112, 72, 255)
CLAY_BOT    = (163, 71, 40, 255)
SHADOW      = (110, 47, 27, 80)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def P(x, y):
    return (x * S, y * S)

def poly(d, pts, fill):
    d.polygon([P(x, y) for x, y in pts], fill=fill)

def line(d, a, b, fill, w):
    d.line([P(*a), P(*b)], fill=fill, width=int(w * S))

def rrect(d, box, radius, fill):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0*S, y0*S, x1*S, y1*S], radius=radius*S, fill=fill)

# open-book geometry (1024 space)
SP_T, SP_B = (512, 662), (512, 802)          # spine top / bottom
LT, LB = (164, 612), (140, 754)              # left outer top / bottom
RT, RB = (860, 612), (884, 754)              # right outer top / bottom

def page_lines(d, top_a, top_b):
    """3 strokes parallel to a page's top edge, stepped down the page."""
    for off in (40, 72, 104):
        a = (top_a[0] + (top_b[0]-top_a[0])*0.20, top_a[1] + (top_b[1]-top_a[1])*0.20 + off)
        b = (top_a[0] + (top_b[0]-top_a[0])*0.80, top_a[1] + (top_b[1]-top_a[1])*0.80 + off)
        line(d, a, b, CREAM_SHADE, 7)

def draw(foreground_only: bool) -> Image.Image:
    img = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if not foreground_only:
        for y in range(R):
            d.line([(0, y), (R, y)], fill=lerp(CLAY_TOP, CLAY_BOT, y / R))

    # soft shadow under the book
    poly(d, [SP_T, (LT[0]+8, LT[1]+14), (LB[0]+6, LB[1]+22), (SP_B[0], SP_B[1]+18)], SHADOW)
    poly(d, [SP_T, (RT[0]-8, RT[1]+14), (RB[0]-6, RB[1]+22), (SP_B[0], SP_B[1]+18)], SHADOW)

    # page-stack thickness (a darker band under each bottom edge)
    poly(d, [LB, SP_B, (SP_B[0], SP_B[1]+20), (LB[0]+12, LB[1]+18)], CREAM_SHADE)
    poly(d, [RB, SP_B, (SP_B[0], SP_B[1]+20), (RB[0]-12, RB[1]+18)], CREAM_SHADE)

    # the two pages
    poly(d, [SP_T, LT, LB, SP_B], CREAM)
    poly(d, [SP_T, RT, RB, SP_B], CREAM)

    # gutter + page text lines
    line(d, SP_T, SP_B, CREAM_SHADE, 8)
    page_lines(d, SP_T, LT)
    page_lines(d, SP_T, RT)

    # cross on top (base rises out of the book's centre)
    rrect(d, (470, 168, 554, 700), 30, CREAM)   # vertical beam
    rrect(d, (344, 326, 680, 410), 30, CREAM)   # horizontal beam

    return img.resize((N, N), Image.LANCZOS)

out = "assets/icon"
os.makedirs(out, exist_ok=True)
draw(False).convert("RGB").save(os.path.join(out, "icon_full.png"))

# Android adaptive foreground: motif on transparent, scaled into the 66% safe zone
fg = draw(True)
inner = int(N * 0.66)
canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
small = fg.resize((inner, inner), Image.LANCZOS)
canvas.paste(small, ((N - inner)//2, (N - inner)//2), small)
canvas.save(os.path.join(out, "icon_fg.png"))
print("wrote icon_full.png + icon_fg.png")
