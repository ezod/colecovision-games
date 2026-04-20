#!/usr/bin/env python3

import argparse
from PIL import Image

SPRITE_SIZE = 32
HALF = 16


def extract_8x8(img, x, y):
    out = []
    for row in range(8):
        b = 0
        for col in range(8):
            if img.getpixel((x + col, y + row)) == 0:
                b |= 1 << (7 - col)
        out.append(b)
    return out


def extract_16x16_cv(img, x, y):
    return (
        extract_8x8(img, x,     y) +      # UL
        extract_8x8(img, x,     y + 8) +  # LL
        extract_8x8(img, x + 8, y) +      # UR
        extract_8x8(img, x + 8, y + 8)    # LR
    )


def format_asm(data, label="SPDATA", bytes_per_line=8):
    lines = [f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        values = ",".join(f"{b:03X}h" for b in chunk)
        lines.append(f"\tdb {values}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Convert a black-on-white PNG sprite sheet into ColecoVision ASM sprite data."
    )
    parser.add_argument("png", help="Path to black-on-white PNG sprite sheet")
    args = parser.parse_args()

    img = Image.open(args.png).convert("L")
    width, height = img.size

    if width % SPRITE_SIZE != 0 or height % SPRITE_SIZE != 0:
        raise ValueError(
            f"Image size {width}x{height} is not divisible by {SPRITE_SIZE}x{SPRITE_SIZE}."
        )

    cols = width // SPRITE_SIZE
    rows = height // SPRITE_SIZE

    spdata = []

    for row in range(rows):
        for col in range(cols):
            bx = col * SPRITE_SIZE
            by = row * SPRITE_SIZE
            spdata.extend(extract_16x16_cv(img, bx,         by))         # TL
            spdata.extend(extract_16x16_cv(img, bx,         by + HALF))  # BL
            spdata.extend(extract_16x16_cv(img, bx + HALF,  by))         # TR
            spdata.extend(extract_16x16_cv(img, bx + HALF,  by + HALF))  # BR

    print(format_asm(spdata, "SPDATA"))


if __name__ == "__main__":
    main()
