#!/usr/bin/env python3
"""Write tiny PNG samples for Flip demos and tests (no third-party deps)."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "examples"


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, rgb_at) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b = rgb_at(x, y, width, height)
            raw.extend((r & 255, g & 255, b & 255))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def img1(x, y, w, h):
    return (40, 120 + (x * 80) // w, 200)


def img2(x, y, w, h):
    return (200, 70 + (y * 80) // h, 50)


def img10(x, y, w, h):
    # Wide "scan" that should scale down in a typical window.
    band = 255 if (y // 40) % 2 == 0 else 180
    return (30, 80, band)


def tiny(x, y, w, h):
    return (240, 200, 40) if (x + y) % 8 < 4 else (40, 40, 40)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "img1.png", 240, 180, img1)
    write_png(OUT / "img2.png", 640, 400, img2)
    write_png(OUT / "img10.png", 1920, 480, img10)
    write_png(OUT / "tiny-icon.png", 48, 48, tiny)
    print(f"wrote samples in {OUT}")


if __name__ == "__main__":
    main()
