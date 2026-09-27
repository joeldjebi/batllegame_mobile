"""Generates the onboarding Lottie animations (assets/lottie/*.json).

Drawn for the violet onboarding background: white, lavender (Brand c300) and the
« like » pink, flat colors. Run from the app folder: python3 tool/onboarding_lottie.py
"""

import json
from pathlib import Path

FPS = 60
SIZE = 400
WHITE = [1, 1, 1, 1]
LAVENDER = [0xC4 / 255, 0xB0 / 255, 1, 1]
PINK = [1, 0x3D / 255, 0x6E / 255, 1]
EASE = {"i": {"x": [0.3], "y": [1]}, "o": {"x": [0.6], "y": [0]}}


def static(value):
    return {"a": 0, "k": value}


def anim(*keys):
    """keys: (frame, value) pairs, eased; the last one holds."""
    frames = []
    for t, value in keys:
        frames.append({"t": t, "s": value if isinstance(value, list) else [value], **EASE})
    return {"a": 1, "k": frames}


def transform(p=(0, 0), a=(0, 0), s=100, r=0, o=100, shape=True):
    s = s if isinstance(s, dict) else static([s, s] if shape else [s, s, 100])
    r = r if isinstance(r, dict) else static(r)
    o = o if isinstance(o, dict) else static(o)
    p = p if isinstance(p, dict) else static(list(p) if shape else [*p, 0])
    a = a if isinstance(a, dict) else static(list(a) if shape else [*a, 0])
    t = {"p": p, "a": a, "s": s, "r": r, "o": o}
    return {"ty": "tr", **t} if shape else t


def group(*items, **tr):
    return {"ty": "gr", "it": [*items, transform(**tr)]}


def fill(color, o=100):
    return {"ty": "fl", "c": static(color), "o": static(o) if not isinstance(o, dict) else o, "r": 1}


def stroke(color, width, o=100):
    return {"ty": "st", "c": static(color), "o": static(o) if not isinstance(o, dict) else o, "w": static(width), "lc": 2, "lj": 2}


def rect(w, h, r, p=(0, 0)):
    return {"ty": "rc", "p": static(list(p)), "s": static([w, h]), "r": static(r)}


def ellipse(w, h=None, p=(0, 0)):
    size = w if isinstance(w, dict) else static([w, h or w])
    return {"ty": "el", "p": static(list(p)), "s": size}


def path(vertices, ins=None, outs=None, closed=False):
    n = len(vertices)
    return {
        "ty": "sh",
        "ks": static({"v": vertices, "i": ins or [[0, 0]] * n, "o": outs or [[0, 0]] * n, "c": closed}),
    }


def trim(end, start=None):
    return {"ty": "tm", "s": start or static(0), "e": end, "o": static(0), "m": 1}


def layer(index, name, shapes, **tr):
    return {
        "ddd": 0, "ind": index, "ty": 4, "nm": name, "sr": 1, "ao": 0, "bm": 0,
        "ks": transform(shape=False, **tr), "shapes": shapes, "ip": 0, "op": 10_000, "st": 0,
    }


def animation(name, frames, layers):
    """[layers] from back to front (Lottie draws the first layer on top)."""
    layers = layers[::-1]
    for i, l in enumerate(layers):
        l["op"] = frames
        l["ind"] = i + 1
    return {"v": "5.7.4", "fr": FPS, "ip": 0, "op": frames, "w": SIZE, "h": SIZE, "nm": name, "ddd": 0, "assets": [], "layers": layers}


def microphone(color=WHITE, detail=LAVENDER):
    """A microphone standing on (0, 0): grille, capsule head, holder, stem, base."""
    return [
        group(*(rect(40, 5, 2.5, p=(0, y)) for y in (-172, -158, -144)), fill(detail)),
        group(rect(64, 96, 32, p=(0, -150)), fill(color)),
        group(
            path([[-46, -150], [0, -96], [46, -150]], ins=[[0, 0], [-30, 0], [0, 30]], outs=[[0, 30], [30, 0], [0, 0]]),
            stroke(color, 9),
        ),
        group(rect(10, 60, 5, p=(0, -66)), fill(color)),
        group(rect(64, 12, 6, p=(0, -36)), fill(color)),
    ]


def burst(count, inner, outer, width, color, start, frames=30, o=100):
    """Rays growing out of the center, then fading (starts at frame [start])."""
    rays = []
    for k in range(count):
        rays.append(group(path([[0, -inner], [0, -outer]]), stroke(color, width), r=k * 360 / count))
    return rays + [
        trim(anim((start, 0), (start + frames * 0.6, 100)), anim((start + frames * 0.3, 0), (start + frames, 100))),
    ]


def rings(center, color, start, period, count=2, size=260):
    """Soft rings pulsing out from [center]."""
    items = []
    for k in range(count):
        t0 = start + k * period / count
        items.append(
            layer(0, f"ring {k}", [group(ellipse(size), stroke(color, 4))],
                  p=center, s=anim((t0, [40, 40, 100]), (t0 + period, [120, 120, 100])),
                  o=anim((t0, 0), (t0 + period * 0.2, 45), (t0 + period, 0)))
        )
    return items


def battles():
    """Two microphones clash in the middle, a spark between them."""
    frames = 150
    tilt = lambda sign: anim((0, 0), (38, sign * 16), (50, sign * 8), (62, sign * 16), (110, sign * 16), (140, 0))
    left = layer(0, "left mic", microphone(), p=(120, 330), r=tilt(1))
    right = layer(0, "right mic", microphone(), p=(280, 330), r=tilt(-1))
    spark = layer(0, "spark", [group(*burst(8, 48, 92, 8, PINK, 36, 45))], p=(200, 185))
    return animation("battles", frames, [*rings((200, 190), WHITE, 40, 90), left, right, spark])


HEART = path(
    [[0, 50], [55, -12], [0, -26], [-55, -12]],
    ins=[[-26, -22], [0, 28], [6, -28], [0, -32]],
    outs=[[26, -22], [0, -32], [-6, -28], [0, 28]],
    closed=True,
)


def vote():
    """« Maintenir pour voter »: the pill fills while pressed, then a heart pops."""
    frames = 180
    bar = [[-110, 0], [110, 0]]
    track = group(path(bar), stroke(WHITE, 64, 28))
    fill_bar = group(path(bar), trim(anim((10, 0), (75, 100), (150, 100), (151, 0))), stroke(WHITE, 64))
    button = layer(0, "button", [fill_bar, track], p=(200, 290), s=anim((0, [100, 100, 100]), (10, [96, 96, 100]), (75, [96, 96, 100]), (85, [100, 100, 100])))
    finger = layer(0, "finger", [group(ellipse(44), fill(LAVENDER))], p=(130, 290),
                   s=anim((0, [0, 0, 100]), (8, [100, 100, 100]), (75, [100, 100, 100]), (85, [0, 0, 100])),
                   o=static(90))
    heart = layer(0, "heart", [group(HEART, fill(PINK))], p=(200, 140),
                  s=anim((75, [0, 0, 100]), (90, [125, 125, 100]), (100, [100, 100, 100]), (150, [100, 100, 100]), (165, [0, 0, 100])))
    spark = layer(0, "spark", [group(*burst(10, 70, 100, 6, WHITE, 80, 40))], p=(200, 140))
    return animation("vote", frames, [button, finger, spark, heart])


def stage():
    """A microphone on stage: sound waves, a spotlight and twinkling stars."""
    frames = 150
    spot = layer(0, "spotlight", [group(ellipse(300, 60), fill(WHITE, 16))], p=(200, 350),
                 s=anim((0, [90, 90, 100]), (75, [105, 105, 100]), (150, [90, 90, 100])))
    mic = layer(0, "mic", microphone(), p=(200, 340), s=static([110, 110, 100]),
                r=anim((0, -4), (75, 4), (150, -4)))
    waves = []
    for side in (-1, 1):
        for k in range(3):
            radius = 60 + k * 28
            t0 = k * 14
            arc = path(
                [[side * radius * 0.55, -radius * 0.8], [side * radius, 0], [side * radius * 0.55, radius * 0.8]],
                ins=[[0, 0], [0, -radius * 0.45], [side * radius * 0.25, -radius * 0.2]],
                outs=[[side * radius * 0.25, radius * 0.2], [0, radius * 0.45], [0, 0]],
            )
            waves.append(layer(0, f"wave {side} {k}", [group(arc, stroke(WHITE, 7))], p=(200, 175),
                               o=anim((t0, 0), (t0 + 20, 100), (t0 + 60, 0), (frames, 0))))
    stars = []
    for k, (x, y, t0) in enumerate([(70, 80, 0), (330, 70, 40), (350, 220, 80), (50, 230, 110)]):
        star = path([[0, -14], [0, 14]]), path([[-14, 0], [14, 0]])
        stars.append(layer(0, f"star {k}", [group(*star, stroke(LAVENDER, 5))], p=(x, y),
                           s=anim((t0, [0, 0, 100]), (t0 + 20, [100, 100, 100]), (t0 + 40, [0, 0, 100])),
                           o=anim((0, 0), (t0, 0), (t0 + 1, 100), (t0 + 39, 100), (t0 + 40, 0))))
    return animation("stage", frames, [spot, *waves, *stars, mic])


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "assets" / "lottie"
    out.mkdir(parents=True, exist_ok=True)
    for build in (battles, vote, stage):
        data = build()
        (out / f"onboarding_{data['nm']}.json").write_text(json.dumps(data, separators=(",", ":")))
        print(f"onboarding_{data['nm']}.json")
