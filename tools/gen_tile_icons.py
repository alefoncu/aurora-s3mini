#!/usr/bin/env python3
"""Thin versions of the animated quick-settings tile icons (airplane, location).

The stock vectors animate only root / mask / cross_1 (alpha, clip and slash), never the glyph
path, so the glyph can be swapped from a solid fill to a hairline outline while every group and
path name stays as the animations expect.

usage: gen_tile_icons.py <decoded stock SystemUI res/drawable> <work/sysui/res/drawable>
(the stock dir comes from `apktool d -s backup/SystemUI.apk`)
"""
import re, sys

src, dst = sys.argv[1], sys.argv[2]
STROKE = ('android:fillColor="#00000000" android:strokeColor="#ffffffff" android:strokeWidth="2.2" '
          'android:strokeLineCap="round" android:strokeLineJoin="round"')

for name, glyph in (("airplane", "plane_1"), ("location", "pin")):
    for state in ("enable", "disable"):
        f = "ic_signal_%s_%s.xml" % (name, state)
        xml = open("%s/%s" % (src, f)).read()
        pat = re.compile(r'(<path android:name="%s" )android:fillColor="#ffffffff"( android:pathData="[^"]*") android:fillAlpha="1.0"' % glyph)
        xml, n = pat.subn(r'\1' + STROKE + r'\2', xml)
        assert n == 1, f
        open("%s/%s" % (dst, f), "w").write(xml)
        print("wrote", f)
