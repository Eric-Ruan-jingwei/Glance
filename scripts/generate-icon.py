#!/usr/bin/env python3
"""Generate a simple AppIcon.icns for Glance without third-party deps."""

from __future__ import annotations

import os
import struct
import subprocess
import sys
import tempfile
import zlib


def write_png(path: str, size: int, rgba) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgba[y * size * 4 : (y + 1) * size * 4] for y in range(size))
    png = b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(raw, 9)),
            chunk(b"IEND", b""),
        ]
    )
    with open(path, "wb") as handle:
        handle.write(png)


def clamp(value: int) -> int:
    return 0 if value < 0 else 255 if value > 255 else value


def mix(a, b, t: float):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(4))


def rounded_rect(px: float, py: float, cx: float, cy: float, w: float, h: float, r: float) -> bool:
    dx = abs(px - cx) - w / 2 + r
    dy = abs(py - cy) - h / 2 + r
    if dx <= 0 and abs(py - cy) <= h / 2:
        return True
    if dy <= 0 and abs(px - cx) <= w / 2:
        return True
    if dx > 0 and dy > 0:
        return dx * dx + dy * dy <= r * r
    return False


def render(size: int) -> bytes:
    bg = (28, 27, 25, 255)
    panel = (244, 241, 233, 255)
    pin = (196, 92, 58, 255)
    shadow = (0, 0, 0, 70)
    pixels = bytearray(size * size * 4)
    s = float(size)
    for y in range(size):
        for x in range(size):
            px = (x + 0.5) / s
            py = (y + 0.5) / s
            color = bg
            # outer rounded app icon
            if not rounded_rect(px, py, 0.5, 0.5, 0.92, 0.92, 0.22):
                color = (0, 0, 0, 0)
            else:
                # panel shadow
                if rounded_rect(px, py, 0.53, 0.55, 0.52, 0.38, 0.08):
                    color = mix(bg, shadow, 0.35)
                if rounded_rect(px, py, 0.50, 0.52, 0.52, 0.38, 0.08):
                    color = panel
                # pin head
                dx = px - 0.50
                dy = py - 0.30
                if dx * dx + dy * dy <= 0.045 * 0.045:
                    color = pin
                # pin needle
                if abs(px - 0.50) < 0.018 and 0.30 < py < 0.58:
                    color = pin
            i = (y * size + x) * 4
            pixels[i : i + 4] = bytes(clamp(c) for c in color)
    return bytes(pixels)


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    out_icns = os.path.join(root, "Resources", "AppIcon.icns")
    os.makedirs(os.path.dirname(out_icns), exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)
        sizes = {
            16: "icon_16x16.png",
            32: "icon_16x16@2x.png",
            32: "icon_32x32.png",  # noqa: F601
            64: "icon_32x32@2x.png",
            128: "icon_128x128.png",
            256: "icon_128x128@2x.png",
            256: "icon_256x256.png",  # noqa: F601
            512: "icon_256x256@2x.png",
            512: "icon_512x512.png",  # noqa: F601
            1024: "icon_512x512@2x.png",
        }
        # dict can't hold duplicate keys; write explicitly
        mapping = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        cache = {}
        for size, name in mapping:
            if size not in cache:
                cache[size] = render(size)
            write_png(os.path.join(iconset, name), size, cache[size])
        result = subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out_icns], capture_output=True, text=True)
        if result.returncode != 0:
            print(result.stderr, file=sys.stderr)
            # Fallback: keep a 1024 png next to the app if iconutil is missing
            fallback = os.path.join(root, "Resources", "AppIcon.png")
            write_png(fallback, 1024, cache[1024])
            print(f"iconutil failed; wrote {fallback}")
            return 0
    print(f"Wrote {out_icns}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
