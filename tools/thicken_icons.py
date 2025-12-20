from PIL import Image, ImageFilter
import numpy as np
from pathlib import Path

def thicken_and_blacken(src: Path, dst: Path, dilate_px: int = 1, gray_keep_threshold: int = 245):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    rgb = arr[..., :3].astype(np.uint8)
    a   = arr[..., 3].astype(np.uint8)

    # Ink = pixels that are visible (alpha) and not near-white
    gray = (0.299*rgb[...,0] + 0.587*rgb[...,1] + 0.114*rgb[...,2]).astype(np.uint8)
    ink = (a > 10) & (gray < gray_keep_threshold)

    mask = Image.fromarray((ink.astype(np.uint8) * 255), mode="L")

    # Dilation: dilate_px=1 => filter size 3; dilate_px=2 => size 5, etc.
    size = dilate_px * 2 + 1
    mask2 = mask.filter(ImageFilter.MaxFilter(size=size))

    out = np.zeros_like(arr)
    m = np.array(mask2) > 0
    out[m, 3] = 255  # alpha
    # RGB left as 0 => pure black
    Image.fromarray(out, mode="RGBA").save(dst)

def main():
    root = Path(__file__).resolve().parents[1]
    icons = root / "assets" / "icons"
    for name in ["icons_l.png", "icons_t.png", "icons_r.png"]:
        p = icons / name
        if not p.exists():
            raise FileNotFoundError(str(p))
        tmp = icons / (name + ".tmp")
        thicken_and_blacken(p, tmp, dilate_px=1)
        tmp.replace(p)
        print("Updated", p)

if __name__ == "__main__":
    main()
