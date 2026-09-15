from pathlib import Path
import math
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont

W, H, FPS, SECONDS = 1280, 720, 25, 5
FRAME_DIR = Path(".build/iosclaw-demo-frames")
OUTPUT = Path("media/iosclaw-indiedev-demo.mp4")
GIF_OUTPUT = Path("media/iosclaw-indiedev-demo.gif")
FONT = "/System/Library/Fonts/SFNS.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


REGULAR = font(FONT, 22)
SMALL = font(FONT, 17)
LABEL = font(FONT, 20)
TITLE = font(FONT, 60)
MONO_FONT = font(MONO, 18)
MONO_SMALL = font(MONO, 15)


def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def center(draw, box, value, typeface, fill):
    x1, y1, x2, y2 = box
    bounds = draw.textbbox((0, 0), value, font=typeface)
    draw.text(((x1 + x2) / 2, (y1 + y2) / 2 - (bounds[3] - bounds[1]) / 2), value, font=typeface, fill=fill, anchor="ma")


def background():
    image = Image.new("RGBA", (W, H))
    pixels = image.load()
    for y in range(H):
        for x in range(W):
            blend = 0.35 * x / W + 0.15 * y / H
            pixels[x, y] = (int(8 + 8 * blend), int(16 + 13 * blend), int(30 + 24 * blend), 255)
    return image


def phone(draw, stage, pulse):
    x, y, w, h = 820, 48, 344, 622
    rounded(draw, (x + 8, y + 12, x + w + 8, y + h + 12), 38, (0, 0, 0, 90))
    rounded(draw, (x, y, x + w, y + h), 38, (22, 28, 40), (98, 111, 131), 2)
    rounded(draw, (x + 12, y + 14, x + w - 12, y + h - 14), 29, (247, 248, 250))
    rounded(draw, (x + 126, y + 25, x + 218, y + 49), 14, (11, 14, 20))
    draw.text((x + 32, y + 78), "iosClaw test app", font=font(FONT, 20), fill=(18, 26, 38))
    draw.text((x + 32, y + 108), "Checkout smoke flow", font=SMALL, fill=(97, 108, 123))
    rounded(draw, (x + 24, y + 148, x + w - 24, y + 234), 18, (237, 241, 247))
    draw.text((x + 42, y + 171), "Cart total", font=SMALL, fill=(94, 106, 123))
    draw.text((x + 42, y + 196), "$24.00", font=font(FONT, 29), fill=(18, 26, 38))
    bx1, by1, bx2, by2 = x + 38, y + 275, x + w - 38, y + 331
    rounded(draw, (bx1, by1, bx2, by2), 16, (29, 91, 214))
    center(draw, (bx1, by1, bx2, by2), "Continue to payment", font(FONT, 17), (255, 255, 255))
    rounded(draw, (x + 38, y + 358, x + w - 38, y + 414), 16, (249, 250, 252), (220, 225, 232))
    draw.text((x + 58, y + 377), "Saved address", font=SMALL, fill=(77, 89, 105))
    draw.text((x + w - 54, y + 377), "›", font=font(FONT, 26), fill=(77, 89, 105), anchor="ra")
    if stage == 0:
        alpha = int(150 + 80 * math.sin(pulse * math.pi * 2))
        rounded(draw, (bx1 - 7, by1 - 7, bx2 + 7, by2 + 7), 20, (45, 119, 248, alpha), (45, 119, 248, 220), 3)
        rounded(draw, (x + 42, y + 460, x + w - 42, y + 500), 14, (232, 237, 245))
        draw.text((x + 58, y + 473), "Target: Continue to payment", font=MONO_SMALL, fill=(48, 68, 98))
    elif stage == 1:
        draw.text((x + 42, y + 468), "✓ semantic target compiled", font=MONO_SMALL, fill=(24, 132, 88))
        draw.text((x + 42, y + 496), "✓ postcondition recorded", font=MONO_SMALL, fill=(24, 132, 88))
    else:
        rounded(draw, (x + 42, y + 451, x + w - 42, y + 514), 16, (224, 247, 237))
        draw.text((x + 60, y + 468), "✓ replay verified", font=font(FONT, 20), fill=(20, 118, 76))
        draw.text((x + 60, y + 495), "Checkout flow passed", font=SMALL, fill=(49, 103, 78))
    rounded(draw, (x + 120, y + h - 36, x + 224, y + h - 28), 5, (24, 29, 36))


def make_frame(index):
    seconds = index / FPS
    if seconds < 1.55:
        stage, progress = 0, seconds / 1.55
    elif seconds < 3.15:
        stage, progress = 1, (seconds - 1.55) / 1.60
    else:
        stage, progress = 2, (seconds - 3.15) / 1.85
    accents = [(71, 152, 255), (151, 116, 255), (40, 196, 135)]
    accent = accents[stage]
    image = background()
    draw = ImageDraw.Draw(image)
    icon = Path("iosclaw-logo/logo-icon.png")
    if icon.exists():
        image.alpha_composite(Image.open(icon).convert("RGBA").resize((42, 42)), (50, 40))
    draw.text((102, 48), "iosClaw", font=font(FONT, 27), fill=(236, 243, 252))
    rounded(draw, (102, 84, 262, 116), 16, (21, 42, 72), (62, 100, 158))
    center(draw, (102, 84, 262, 116), "LOCAL • MAC + iPHONE", MONO_SMALL, (171, 205, 247))
    labels = [("1 / 3  OBSERVE", "See the state.", "iosClaw reads the mirrored screen\nand finds the semantic target."), ("2 / 3  COMPILE", "Compile once.", "The LLM helps with intent.\nThe runtime keeps the flow."), ("3 / 3  REPLAY", "Run it fast.", "Known work replays locally\nwith no model call between taps.")]
    kicker, title, body = labels[stage]
    draw.text((62, 190), kicker, font=MONO_FONT, fill=accent)
    draw.text((58, 226), title, font=TITLE, fill=(245, 247, 251))
    draw.multiline_text((62, 312), body, font=REGULAR, fill=(174, 187, 205), spacing=8)
    rounded(draw, (58, 430, 654, 566), 22, (15, 27, 45), (44, 64, 92))
    cards = [("TARGET RESOLUTION", "accessibility → visual fallback", "ambiguous state = stop"), ("COMPILED FLOW", "intent → action → postcondition", "one planning call, reusable steps"), ("REPLAY RESULT", "0 LLM calls on the hot path", "fast, local, auditable")]
    card_kicker, card_title, card_body = cards[stage]
    draw.text((84, 452), card_kicker, font=MONO_SMALL, fill=accent)
    draw.text((84, 478), card_title, font=LABEL, fill=(228, 235, 246))
    draw.text((84, 520), card_body, font=SMALL, fill=(165, 181, 200))
    draw.text((62, 655), "Run with an LLM • automate device tasks • QA your device", font=SMALL, fill=(108, 130, 157))
    phone(draw, stage, progress)
    rounded(draw, (58, 610, 654, 616), 3, (34, 51, 73))
    rounded(draw, (58, 610, 58 + 596 * min(1, seconds / SECONDS), 616), 3, accent)
    return image.convert("RGB")


def main():
    if FRAME_DIR.exists():
        shutil.rmtree(FRAME_DIR)
    FRAME_DIR.mkdir(parents=True)
    for index in range(FPS * SECONDS):
        make_frame(index).save(FRAME_DIR / f"frame_{index:04d}.png", quality=95)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-framerate", str(FPS), "-i", str(FRAME_DIR / "frame_%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["ffmpeg", "-y", "-i", str(OUTPUT), "-vf", "fps=12,scale=640:-1:flags=lanczos", str(GIF_OUTPUT)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"created {OUTPUT} and {GIF_OUTPUT}")


if __name__ == "__main__":
    main()
