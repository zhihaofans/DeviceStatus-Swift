#!/usr/bin/env python3
"""生成 DeviceStatus 的占位 App 图标（iOS / macOS / watchOS 三平台）。

这是**占位图**，只为让三个平台都能正常构建、且满足上架对图标完整性的要求。
正式图标请用 Icon Composer 或设计稿替换 AppIcon.appiconset 里的 PNG（文件名保持不变即可）。

用法：
    python3 Scripts/generate-appicons.py
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
ICONSET = REPO_ROOT / "DeviceStatus" / "Assets.xcassets" / "AppIcon.appiconset"
MASTER_SIZE = 1024

# 品牌渐变：深蓝 -> 青绿
TOP_COLOR = (27, 78, 216)
BOTTOM_COLOR = (16, 185, 165)


def _lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def render_master() -> Image.Image:
    """画一张 1024x1024 的全出血母版（无 alpha，圆形裁切下也安全）。"""
    img = Image.new("RGB", (MASTER_SIZE, MASTER_SIZE))
    draw = ImageDraw.Draw(img)

    # 垂直渐变背景
    for y in range(MASTER_SIZE):
        t = y / (MASTER_SIZE - 1)
        draw.line(
            [(0, y), (MASTER_SIZE, y)],
            fill=tuple(_lerp(TOP_COLOR[i], BOTTOM_COLOR[i], t) for i in range(3)),
        )

    # 居中的设备轮廓 + 两条状态条，全部收在内容安全区（内切圆）内
    cx = cy = MASTER_SIZE / 2
    box_w, box_h = 430, 560
    left, top = cx - box_w / 2, cy - box_h / 2
    right, bottom = cx + box_w / 2, cy + box_h / 2

    draw.rounded_rectangle(
        [left, top, right, bottom],
        radius=76,
        outline=(255, 255, 255),
        width=34,
    )

    bar_h = 44
    bar_x = left + 78
    for index, width_ratio in enumerate((1.0, 0.55)):
        y = top + 150 + index * (bar_h + 46)
        draw.rounded_rectangle(
            [bar_x, y, bar_x + (box_w - 156) * width_ratio, y + bar_h],
            radius=bar_h / 2,
            fill=(255, 255, 255),
        )

    return img


def macos_variant(master: Image.Image) -> Image.Image:
    """macOS 图标：四周留白 + 圆角 + alpha 透明。"""
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    inset = 100
    inner = MASTER_SIZE - inset * 2

    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, inner - 1, inner - 1], radius=185, fill=255
    )

    art = master.resize((inner, inner), Image.LANCZOS).convert("RGBA")
    art.putalpha(mask)
    canvas.alpha_composite(art, (inset, inset))
    return canvas


# (文件名, 像素边长, 是否需要 alpha)
IOS_IMAGES = [("AppIcon-ios-1024.png", 1024, False)]

MACOS_IMAGES = [
    ("AppIcon-mac-16.png", 16, True),
    ("AppIcon-mac-16@2x.png", 32, True),
    ("AppIcon-mac-32.png", 32, True),
    ("AppIcon-mac-32@2x.png", 64, True),
    ("AppIcon-mac-128.png", 128, True),
    ("AppIcon-mac-128@2x.png", 256, True),
    ("AppIcon-mac-256.png", 256, True),
    ("AppIcon-mac-256@2x.png", 512, True),
    ("AppIcon-mac-512.png", 512, True),
    ("AppIcon-mac-512@2x.png", 1024, True),
]

# watchOS 的 slot 列表（size, scale, role, subtype, 文件名, 像素边长）。
# 这份表是 watchOS 26 认得的完整集合，抄自 Xcode 真实生成的 AppIcon：
#   - companionSettings 带 subtype 会被判为 unassigned，所以它是空字符串
#   - notificationCenter 仍然需要（24 / 27.5 / 33）
#   - 45x45 appLauncher 41mm 已被 46x46 取代，留着会被判为 unassigned
WATCH_SLOTS: list[tuple[str, str, str, str, str, int]] = [
    ("24x24", "2x", "notificationCenter", "38mm", "AppIcon-watch-48.png", 48),
    ("27.5x27.5", "2x", "notificationCenter", "42mm", "AppIcon-watch-55.png", 55),
    ("29x29", "2x", "companionSettings", "", "AppIcon-watch-58.png", 58),
    ("29x29", "3x", "companionSettings", "", "AppIcon-watch-87.png", 87),
    ("33x33", "2x", "notificationCenter", "45mm", "AppIcon-watch-66.png", 66),
    ("40x40", "2x", "appLauncher", "38mm", "AppIcon-watch-80.png", 80),
    ("44x44", "2x", "appLauncher", "40mm", "AppIcon-watch-88.png", 88),
    ("46x46", "2x", "appLauncher", "41mm", "AppIcon-watch-92.png", 92),
    ("50x50", "2x", "appLauncher", "44mm", "AppIcon-watch-100.png", 100),
    ("51x51", "2x", "appLauncher", "45mm", "AppIcon-watch-102.png", 102),
    ("54x54", "2x", "appLauncher", "49mm", "AppIcon-watch-108.png", 108),
    ("86x86", "2x", "quickLook", "38mm", "AppIcon-watch-172.png", 172),
    ("98x98", "2x", "quickLook", "42mm", "AppIcon-watch-196.png", 196),
    ("108x108", "2x", "quickLook", "44mm", "AppIcon-watch-216.png", 216),
    ("117x117", "2x", "quickLook", "45mm", "AppIcon-watch-234.png", 234),
    ("129x129", "2x", "quickLook", "49mm", "AppIcon-watch-258.png", 258),
]

WATCH_MARKETING_IMAGE = ("AppIcon-watch-marketing-1024.png", 1024)

WATCH_IMAGES = [
    (filename, pixel, False) for *_slot, filename, pixel in WATCH_SLOTS
] + [(WATCH_MARKETING_IMAGE[0], WATCH_MARKETING_IMAGE[1], False)]


def build_images() -> None:
    master = render_master()
    macos = macos_variant(master)

    expected = {
        name for name, _size, _alpha in IOS_IMAGES + MACOS_IMAGES + WATCH_IMAGES
    }
    for stale in ICONSET.glob("*.png"):
        if stale.name not in expected:
            stale.unlink()

    for filename, size, _has_alpha in IOS_IMAGES + WATCH_IMAGES:
        master.resize((size, size), Image.LANCZOS).save(ICONSET / filename)

    for filename, size, _has_alpha in MACOS_IMAGES:
        macos.resize((size, size), Image.LANCZOS).save(ICONSET / filename)


def build_contents() -> None:
    images: list[dict[str, object]] = []

    for filename, _size, _alpha in IOS_IMAGES:
        images.append(
            {
                "filename": filename,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        )

    mak_keys = [
        ("16x16", "1x", "AppIcon-mac-16.png"),
        ("16x16", "2x", "AppIcon-mac-16@2x.png"),
        ("32x32", "1x", "AppIcon-mac-32.png"),
        ("32x32", "2x", "AppIcon-mac-32@2x.png"),
        ("128x128", "1x", "AppIcon-mac-128.png"),
        ("128x128", "2x", "AppIcon-mac-128@2x.png"),
        ("256x256", "1x", "AppIcon-mac-256.png"),
        ("256x256", "2x", "AppIcon-mac-256@2x.png"),
        ("512x512", "1x", "AppIcon-mac-512.png"),
        ("512x512", "2x", "AppIcon-mac-512@2x.png"),
    ]
    for size, scale, filename in mak_keys:
        images.append(
            {"filename": filename, "idiom": "mac", "scale": scale, "size": size}
        )

    # watchOS 的 slot 见上面 WATCH_SLOTS 的注释
    for size, scale, role, subtype, filename, _pixel in WATCH_SLOTS:
        entry: dict[str, object] = {
            "filename": filename,
            "idiom": "watch",
            "role": role,
            "scale": scale,
            "size": size,
        }
        if subtype:
            entry["subtype"] = subtype
        images.append(entry)

    images.append(
        {
            "filename": WATCH_MARKETING_IMAGE[0],
            "idiom": "watch-marketing",
            "scale": "1x",
            "size": "1024x1024",
        }
    )

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (ICONSET / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    os.makedirs(ICONSET, exist_ok=True)
    build_images()
    build_contents()
    count = len(IOS_IMAGES) + len(MACOS_IMAGES) + len(WATCH_IMAGES)
    print(f"wrote {count} placeholder icons to {ICONSET.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
