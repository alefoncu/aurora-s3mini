#!/usr/bin/env python3
"""Thin auto-rotate tile icon for SystemUI.

Stock vectors morph the device outline between two path shapes (A, B) inside four animators and
four static vectors, and fade two arrow paths. Names (arrows, arrow_top, arrow_bottom, device,
device_1, body) and every animator stay as they are; only the path *data* changes:
  - A and B (outer rounded rect + hole) are replaced by hairline rings with the same node layout
    on both ends, so the path morph still interpolates (8 c + 8 c, same order)
  - the arrow shapes are replaced by thin filled arcs with a chevron head (only fillAlpha is animated)

usage: gen_rotation_icon.py <decoded stock SystemUI res dir> <work/sysui/res>
"""
import glob, math, os, re, sys

src, dst = sys.argv[1], sys.argv[2]
T = 2.2                      # line weight, same as the other thin glyphs
K = 0.5523                   # cubic approximation of a quarter circle
S2 = math.sqrt(2)


def fmt(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def ring(hl, hw, r, clockwise):
    """Rounded rect (long axis along (1,1), centre 0,0) as 8 relative cubics, absolute M start."""
    def world(a, b):
        return ((a - b) / S2, (a + b) / S2)
    # corners in local (a, b) order; reverse for the hole so the fill rule leaves it empty
    corners = [(-hl, -hw, 1, 0), (hl, -hw, 0, 1), (hl, hw, -1, 0), (-hl, hw, 0, -1)]
    if not clockwise:
        corners = [corners[0]] + corners[:0:-1]
    pts = []   # sequence of (start tangent, control1, control2, end tangent) per corner in local coords
    for i, (ca, cb, _, _) in enumerate(corners):
        prev = corners[i - 1]
        nxt = corners[(i + 1) % 4]
        da, db = (ca - prev[0], cb - prev[1])
        n = math.hypot(da, db)
        ia, ib = (da / n, db / n)                        # incoming direction
        da, db = (nxt[0] - ca, nxt[1] - cb)
        n = math.hypot(da, db)
        oa, ob = (da / n, db / n)                        # outgoing direction
        p0 = (ca - ia * r, cb - ib * r)
        p3 = (ca + oa * r, cb + ob * r)
        c1 = (p0[0] + ia * r * K, p0[1] + ib * r * K)
        c2 = (p3[0] - oa * r * K, p3[1] - ob * r * K)
        pts.append((p0, c1, c2, p3))
    start = world(*pts[0][0])
    out = ["M %s,%s" % (fmt(start[0]), fmt(start[1]))]
    cur = start
    for i, (p0, c1, c2, p3) in enumerate(pts):
        w0 = world(*p0)
        if i:  # straight edge from the previous corner, written as a degenerate cubic
            d = (w0[0] - cur[0], w0[1] - cur[1])
            out.append("c 0,0 %s,%s %s,%s" % (fmt(d[0]), fmt(d[1]), fmt(d[0]), fmt(d[1])))
            cur = w0
        w1, w2, w3 = world(*c1), world(*c2), world(*p3)
        out.append("c %s,%s %s,%s %s,%s" % (fmt(w1[0] - cur[0]), fmt(w1[1] - cur[1]),
                                            fmt(w2[0] - cur[0]), fmt(w2[1] - cur[1]),
                                            fmt(w3[0] - cur[0]), fmt(w3[1] - cur[1])))
        cur = w3
    # closing edge back to the start
    d = (start[0] - cur[0], start[1] - cur[1])
    out.append("c 0,0 %s,%s %s,%s" % (fmt(d[0]), fmt(d[1]), fmt(d[0]), fmt(d[1])))
    return " ".join(out) + " Z"


def device(hl, hw, r):
    return ring(hl, hw, r, True) + " " + ring(hl - T, hw - T, max(r - T, 0.6), False)


# stock shape A (small) and B (large): 40x24 / 44x28 rounded rects, scaled to leave room for arrows
SHAPE_A = device(17.0, 10.5, 3.0)
SHAPE_B = device(18.7, 11.7, 3.2)

# ---- arrows: thin arc + chevron head, centre of the arrow ring in path coordinates ----
CX, CY, RC = 24.1, 24.2, 21.2


def pt(theta, radius):
    return (CX + radius * math.cos(math.radians(theta)), CY + radius * math.sin(math.radians(theta)))


def polygon(points):
    return "M " + " L ".join("%s,%s" % (fmt(x), fmt(y)) for x, y in points) + " Z"


def arm(apex, direction_deg, length):
    ux, uy = math.cos(math.radians(direction_deg)), math.sin(math.radians(direction_deg))
    nx, ny = -uy, ux
    h = T / 2
    a = (apex[0] - ux * h, apex[1] - uy * h)               # extend past the apex so the joint is closed
    b = (apex[0] + ux * length, apex[1] + uy * length)
    return polygon([(a[0] + nx * h, a[1] + ny * h), (b[0] + nx * h, b[1] + ny * h),
                    (b[0] - nx * h, b[1] - ny * h), (a[0] - nx * h, a[1] - ny * h)])


def arrow_top():
    ro, ri = RC + T / 2, RC - T / 2
    a0, a1 = -4.0, -88.0          # tail (right) to head (top), counter-clockwise on screen
    p_o0, p_o1, p_i1, p_i0 = pt(a0, ro), pt(a1, ro), pt(a1, ri), pt(a0, ri)
    arc = ("M %s,%s A %s,%s 0 0 0 %s,%s L %s,%s A %s,%s 0 0 1 %s,%s Z" %
           (fmt(p_o0[0]), fmt(p_o0[1]), fmt(ro), fmt(ro), fmt(p_o1[0]), fmt(p_o1[1]),
            fmt(p_i1[0]), fmt(p_i1[1]), fmt(ri), fmt(ri), fmt(p_i0[0]), fmt(p_i0[1])))
    apex = pt(-94.0, RC)
    # travelling left at the top; the two arms trail back at +-45 degrees
    return arc + " " + arm(apex, 45, 3.8) + " " + arm(apex, -45, 3.8)


def mirror(path):
    """Rotate every absolute coordinate pair 180 degrees around the arrow ring centre."""
    def repl(m):
        return "%s,%s" % (fmt(2 * CX - float(m.group(1))), fmt(2 * CY - float(m.group(2))))
    return re.sub(r"(-?\d+\.?\d*),(-?\d+\.?\d*)", repl, path)


def arrow_bottom():
    # arcs carry radii (also "r,r"): mirror only the coordinate pairs, not the radii
    top = arrow_top()
    out = []
    for tok in re.split(r"(A [^ ]+,[^ ]+ )", top):
        out.append(tok if tok.startswith("A ") else mirror(tok))
    return "".join(out)


ARROW_TOP, ARROW_BOTTOM = arrow_top(), arrow_bottom()

# ---- find the stock shapes A / B by their node layout and sizes, then rewrite files ----
stock = {}
for f in sorted(glob.glob(src + "/anim/ic_*rotate_animation_*.xml")):
    for m in re.finditer(r'(?:valueFrom|valueTo)="(M[^"]*)"', open(f).read()):
        stock.setdefault(m.group(1), None)
shapes = list(stock)
assert len(shapes) == 2, len(shapes)


def extent(p):
    xs = [float(v) for v in re.findall(r"M (-?[\d.]+),", p)]
    return abs(xs[0])


A_stock, B_stock = sorted(shapes, key=lambda p: len(p))   # the smaller shape is also the shorter string
NEW = {A_stock: SHAPE_A, B_stock: SHAPE_B}


def rewrite(path_in, path_out):
    t = open(path_in).read()
    for old, new in NEW.items():
        t = t.replace(old, new)
    t = re.sub(r'(<path android:name="arrow_top" [^>]*?android:pathData=")[^"]*"', lambda m: m.group(1) + ARROW_TOP + '"', t)
    t = re.sub(r'(<path android:name="arrow_bottom" [^>]*?android:pathData=")[^"]*"', lambda m: m.group(1) + ARROW_BOTTOM + '"', t)
    os.makedirs(os.path.dirname(path_out), exist_ok=True)
    open(path_out, "w").write(t)
    print("wrote", path_out)


for f in sorted(glob.glob(src + "/anim/ic_*rotate_animation_device_1.xml") + glob.glob(src + "/anim/ic_*rotate_animation_body.xml")):
    rewrite(f, os.path.join(dst, "anim", os.path.basename(f)))
for f in sorted(glob.glob(src + "/drawable/ic_*_auto_rotate.xml")):
    rewrite(f, os.path.join(dst, "drawable", os.path.basename(f)))
