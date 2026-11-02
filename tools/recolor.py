import re, os, sys
W = os.path.expanduser('~/ios-reskin/work')
BG, SURFACE, ACCENT, ACCENT_D = '#14123A', '#1E1B4B', '#3B82F6', '#2563EB'
def kind(name):
    n = name.lower()
    if 'underline' in n: return ACCENT
    if 'dark' in n or 'statusbar' in n or 'status_bar' in n or n == 'primarydark' or 'darker' in n or 'blue_focused' in n:
        return ACCENT_D if ('blue' in n) else BG
    if any(k in n for k in ('action', 'toolbar', 'primary', 'theme_color', 'action_bar', 'actionbar', 'contextual', 'people_app')) :
        return SURFACE
    return ACCENT
for app in ('messaging', 'contacts', 'gallery', 'clock', 'dialer', 'settings'):
    p = f'{W}/{app}/res/values/colors.xml'
    s = open(p).read()
    s = re.sub(r'(<color name="([^"]+)">)#[0-9A-Fa-f]{6}(</color>)', lambda m: m.group(1) + kind(m.group(2)) + m.group(3) if re.search(r'#(2E9CF3|1F86DC)', m.group(0)) else m.group(0), s) if False else s
    def sub(m):
        name, val = m.group(2), m.group(3).upper()
        if val in ('#2E9CF3', '#1F86DC'): return f'{m.group(1)}{kind(name)}{m.group(4)}'
        return m.group(0)
    s = re.sub(r'(<color name="([^"]+)">)(#[0-9A-Fa-f]{6})(</color>)', sub, s)
    open(p, 'w').write(s)
sp = f'{W}/settings/res/values/styles.xml'
s = open(sp).read()
s = s.replace('#2E9CF3</item>\n  <item name="android:colorPrimary">#2E9CF3', f'{ACCENT}</item>\n  <item name="android:colorPrimary">{SURFACE}')
s = s.replace('colorPrimaryDark">#1F86DC', f'colorPrimaryDark">{BG}').replace('colorControlActivated">#2E9CF3', f'colorControlActivated">{ACCENT}')
open(sp, 'w').write(s)
open(f'{W}/calc/res/values/colors.xml', 'w').write(f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="calculator_accent_color">{ACCENT}</color>
    <color name="display_background_color">{BG}</color>
    <color name="display_formula_text_color">#8A8A93</color>
    <color name="display_result_text_color">#F2F2F5</color>
    <color name="pad_numeric_background_color">{SURFACE}</color>
    <color name="pad_operator_background_color">{ACCENT}</color>
    <color name="pad_advanced_background_color">#202026</color>
    <color name="pad_button_text_color">#F2F2F5</color>
    <color name="pad_button_advanced_text_color">#8A8A93</color>
</resources>
''')
