"""Carscape app icon: a sand car front whose windshield holds a keyhole."""
from PIL import Image, ImageDraw

BLUE = (0x00, 0x2C, 0x5F, 255)      # Hyundai Blue
SAND = (0xE4, 0xDC, 0xD3, 255)      # Hyundai Sand
WARM = (0xF2, 0xAF, 0x71, 255)      # story accent
DEEP = (0x00, 0x1E, 0x42, 255)      # windshield, a shade under the blue
SS = 4                              # supersampling


def inset(points, r):
    """Offset a convex counter-clockwise-or-clockwise polygon inward by r."""
    import math
    n = len(points)
    # Signed area tells winding.
    area = sum(points[i][0] * points[(i + 1) % n][1] - points[(i + 1) % n][0] * points[i][1] for i in range(n))
    sign = 1 if area > 0 else -1
    lines = []
    for i in range(n):
        (x1, y1), (x2, y2) = points[i], points[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy)
        nx, ny = -dy / length * sign, dx / length * sign  # inward normal
        lines.append(((x1 + nx * r, y1 + ny * r), (dx, dy)))
    out = []
    for i in range(n):
        (p, d), (q, e) = lines[i - 1], lines[i]
        det = d[0] * e[1] - d[1] * e[0]
        t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / det
        out.append((p[0] + d[0] * t, p[1] + d[1] * t))
    return out


def rounded_poly(draw, points, r, fill):
    """Convex polygon with circular corners: the inset core grown by r,
    traced as one outline so there are no seams."""
    import math
    core = inset(points, r)
    n = len(core)
    cx = sum(x for x, _ in core) / n
    cy = sum(y for _, y in core) / n

    def normal(a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        nx, ny = -dy, dx
        mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
        if nx * mx + ny * my < 0:
            nx, ny = -nx, -ny
        return math.atan2(ny, nx)

    outline = []
    for i in range(n):
        start = normal(core[i - 1], core[i])
        end = normal(core[i], core[(i + 1) % n])
        sweep = (end - start + math.pi) % (2 * math.pi) - math.pi
        for k in range(25):
            angle = start + sweep * k / 24
            outline.append((core[i][0] + r * math.cos(angle), core[i][1] + r * math.sin(angle)))
    draw.polygon(outline, fill=fill)


def mark(draw, ox, oy, size):
    """Draw the mark inside the square (ox, oy, size)."""
    P = lambda x, y: (ox + x * size, oy + y * size)
    S = lambda v: v * size

    def rrect(x0, y0, x1, y1, r, fill):
        draw.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=S(r), fill=fill)

    # Mirrors and wheels sit behind the body.
    rrect(0.03, 0.385, 0.22, 0.465, 0.035, SAND)
    rrect(0.78, 0.385, 0.97, 0.465, 0.035, SAND)
    rrect(0.13, 0.70, 0.31, 0.88, 0.05, SAND)
    rrect(0.69, 0.70, 0.87, 0.88, 0.05, SAND)
    # Cabin and body.
    rounded_poly(draw, [P(0.27, 0.13), P(0.73, 0.13), P(0.86, 0.53), P(0.14, 0.53)], S(0.07), SAND)
    rrect(0.06, 0.45, 0.94, 0.79, 0.10, SAND)
    # Windshield.
    rounded_poly(draw, [P(0.325, 0.205), P(0.675, 0.205), P(0.785, 0.475), P(0.215, 0.475)], S(0.045), DEEP)
    # Keyhole, glowing like the story's warm light.
    cx, cy, r = 0.5, 0.30, 0.062
    draw.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=WARM)
    rounded_poly(draw, [P(0.47, 0.31), P(0.53, 0.31), P(0.556, 0.43), P(0.444, 0.43)], S(0.012), WARM)
    # Headlights and grille.
    rrect(0.135, 0.545, 0.315, 0.625, 0.04, BLUE)
    rrect(0.685, 0.545, 0.865, 0.625, 0.04, BLUE)
    rrect(0.38, 0.655, 0.62, 0.715, 0.03, BLUE)


def render(px, *, background, content, corner=0.0):
    """background: None (transparent) or a color; content: mark size as a
    fraction of the canvas; corner: rounded-square radius as a fraction."""
    big = px * SS
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if background is not None:
        if corner > 0:
            draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=corner * big, fill=background)
        else:
            draw.rectangle([0, 0, big, big], fill=background)
    size = big * content
    # Optical centering: the wheels make the mark bottom-heavy.
    mark(draw, (big - size) / 2, (big - size) / 2 + size * 0.01, size)
    return image.resize((px, px), Image.LANCZOS)


def generate(root):
    """Write every app icon from the one drawing above."""
    import os

    def save(image, path):
        path = os.path.join(root, path)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        image.save(path, optimize=True)

    # In-app logo (home screen) and the source for everything else.
    save(render(512, background=BLUE, content=0.66, corner=0.225), "assets/brand/app_icon.png")
    # Android: adaptive foreground (108dp canvas, mark inside the 66dp safe
    # circle) on a solid Hyundai Blue background, plus legacy squares.
    for folder, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)]:
        save(render(round(48 * scale), background=BLUE, content=0.66, corner=0.225),
             f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")
        save(render(round(108 * scale), background=None, content=0.5),
             f"android/app/src/main/res/mipmap-{folder}/ic_launcher_foreground.png")
    # Web: regular, maskable (mark inside the 80% safe zone) and favicon.
    for px in (192, 512):
        save(render(px, background=BLUE, content=0.66, corner=0.225), f"web/icons/Icon-{px}.png")
        save(render(px, background=BLUE, content=0.62), f"web/icons/Icon-maskable-{px}.png")
    save(render(32, background=BLUE, content=0.8, corner=0.2), "web/favicon.png")


if __name__ == "__main__":
    # Usage: python3 tool/make_app_icon.py   (from the repository root)
    import os
    generate(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
