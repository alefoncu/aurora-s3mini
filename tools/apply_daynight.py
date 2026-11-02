"""Splits each stock-app overlay into a DAY set (values/) and a NIGHT set (values-night/).
Run once per app from the 'night-ish' state produced earlier; guarded by a marker so it is idempotent."""
import os, re, subprocess, sys
W = os.path.expanduser('~/ios-reskin/work')
DAY = {'#1E1B4B': '#3D4FD1', '#14123A': '#2C3BAF', '#3B82F6': '#3B6BEA', '#2563EB': '#2F55CC', '#27235E': '#E6E8FA'}
NIGHT = {'#3B82F6': '#7BA7FF', '#2563EB': '#5B8CFF'}
def conv(text, m): 
    for a, b in m.items(): text = text.replace(a, b)
    return text
for app in ('messaging', 'contacts', 'gallery', 'clock', 'dialer', 'settings'):
    d = f'{W}/{app}/res'
    p = f'{d}/values/colors.xml'; t = open(p).read()
    if '<!-- day -->' in t: print(app, 'already split'); continue
    os.makedirs(f'{d}/values-night', exist_ok=True)
    names = set(re.findall(r'<color name="([^"]+)"', t))
    night = conv(t, NIGHT)
    open(f'{d}/values-night/colors.xml', 'w').write(night)
    open(p, 'w').write(conv(t, DAY).replace('<resources>', '<resources>\n <!-- day -->', 1))
    json = d + '/values-night/names.txt'; open(json, 'w').write('\n'.join(sorted(names)))
    print(app, 'split;', len(names), 'bar/accent colours')
