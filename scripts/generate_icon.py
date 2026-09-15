#!/usr/bin/env python3
"""Generate a simple landscape app icon as macOS AppIcon PNG sizes."""
from __future__ import annotations

import math
import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(
    ROOT,
    "SimpleImageViewer",
    "Assets.xcassets",
    "AppIcon.appiconset",
)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(lerp(a, b, t)) for a, b in zip(c1, c2))


def in_circle(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def pixel(x, y, n):
    # y=0 at top of image
    u = x / (n - 1)
    v = y / (n - 1)

    sky_top = (36, 64, 112)
    sky_bot = (168, 198, 226)
    col = mix(sky_top, sky_bot, v)

    # sun
    cx, cy, r = 0.72, 0.28, 0.13
    if in_circle(u, v, cx, cy, r):
        d = math.sqrt((u - cx) ** 2 + (v - cy) ** 2) / r
        col = mix((255, 236, 170), (255, 196, 92), d)

    # back mountain
    peak = 0.22 + 0.55 * abs(u - 0.32)
    if v > peak:
        t = min(1.0, (v - peak) / 0.35)
        col = mix((92, 118, 148), (58, 78, 104), t)

    # front mountain
    peak2 = 0.42 + 0.62 * abs(u - 0.62)
    if v > peak2:
        t = min(1.0, (v - peak2) / 0.4)
        col = mix((46, 72, 58), (24, 40, 32), t)

    # foreground slope
    ground = 0.78 + 0.08 * math.sin(u * math.pi)
    if v > ground:
        col = mix((34, 48, 36), (18, 26, 20), (v - ground) / 0.22)

    return col + (255,)


def write_png(path, w, h, rgba):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * stride : (y + 1) * stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def render(n):
    buf = bytearray(n * n * 4)
    i = 0
    for y in range(n):
        for x in range(n):
            r, g, b, a = pixel(x, y, n)
            buf[i] = r
            buf[i + 1] = g
            buf[i + 2] = b
            buf[i + 3] = a
            i += 4
    return buf


def downsample(src, src_n, dst_n):
    scale = src_n / dst_n
    out = bytearray(dst_n * dst_n * 4)
    for y in range(dst_n):
        y0 = int(y * scale)
        y1 = int((y + 1) * scale)
        for x in range(dst_n):
            x0 = int(x * scale)
            x1 = int((x + 1) * scale)
            r = g = b = a = count = 0
            for yy in range(y0, max(y1, y0 + 1)):
                row = yy * src_n * 4
                for xx in range(x0, max(x1, x0 + 1)):
                    p = row + xx * 4
                    r += src[p]
                    g += src[p + 1]
                    b += src[p + 2]
                    a += src[p + 3]
                    count += 1
            o = (y * dst_n + x) * 4
            out[o] = r // count
            out[o + 1] = g // count
            out[o + 2] = b // count
            out[o + 3] = a // count
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    hi = render(1024)
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in sizes.items():
        data = hi if size == 1024 else downsample(hi, 1024, size)
        write_png(os.path.join(OUT, name), size, size, data)
        print("wrote", name, size)


if __name__ == "__main__":
    main()
