package com.scratch.ioscalc;

import android.app.Activity;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;

/** Own Calculator: glass keypad over the wallpaper, thin display, follows day/night. */
public class CalcActivity extends Activity {
    private static final String[][] KEYS = {
        {"AC", "±", "%", "÷"}, {"7", "8", "9", "×"}, {"4", "5", "6", "−"}, {"1", "2", "3", "+"}, {"0", ",", "="}};
    private float d;
    private boolean night;
    private int text, fn, num, op, opOn, opTextOn;
    private TextView display;
    private final java.util.Map<String, TextView> btn = new java.util.HashMap<>();

    // state
    private String cur = "0";
    private BigDecimal acc;
    private char pending = 0;
    private boolean fresh = false, error = false;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        num = night ? 0x2EFFFFFF : 0xB3FFFFFF;
        fn = night ? 0x52FFFFFF : 0x80FFFFFF;
        op = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        opOn = night ? Color.WHITE : 0xFF14123A;
        opTextOn = night ? 0xFF14123A : Color.WHITE;

        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        FrameLayout root = new FrameLayout(this);
        View sc = new View(this);
        sc.setBackgroundColor(night ? 0xB314123A : 0x80F6F5FF);
        root.addView(sc, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (12 * d);
        col.setPadding(pad, (int) (24 * d), pad, pad);
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));

        display = new TextView(this);
        display.setTextColor(text);
        display.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        display.setGravity(Gravity.RIGHT | Gravity.BOTTOM);
        display.setSingleLine(true);
        display.setPadding((int) (12 * d), 0, (int) (12 * d), (int) (10 * d));
        col.addView(display, new LinearLayout.LayoutParams(-1, 0, 2.2f));

        for (String[] row : KEYS) {
            LinearLayout r = new LinearLayout(this);
            r.setOrientation(LinearLayout.HORIZONTAL);
            for (String k : row) {
                TextView t = key(k);
                btn.put(k, t);
                float w = k.equals("0") ? 2f : 1f;
                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -1, w);
                int m = (int) (4 * d);
                lp.setMargins(m, m, m, m);
                r.addView(t, lp);
            }
            col.addView(r, new LinearLayout.LayoutParams(-1, 0, 1f));
        }
        setContentView(root);
        show();
    }

    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }

    private boolean isOp(String k) { return "÷×−+".contains(k) || k.equals("="); }

    private void style(TextView t, String k, boolean active) {
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(1000 * d);
        int fill = isOp(k) ? (active ? opOn : op) : (k.equals("AC") || k.equals("±") || k.equals("%")) ? fn : num;
        g.setColor(fill);
        g.setStroke((int) Math.max(1, d), night ? 0x38FFFFFF : 0xE6FFFFFF);
        t.setBackground(g);
        t.setTextColor(isOp(k) ? (active ? opTextOn : Color.WHITE) : text);
    }

    private TextView key(final String k) {
        final TextView t = new TextView(this);
        t.setText(k);
        t.setGravity(k.equals("0") ? Gravity.CENTER_VERTICAL | Gravity.LEFT : Gravity.CENTER);
        if (k.equals("0")) t.setPadding((int) (34 * d), 0, 0, 0);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, isOp(k) ? 34 : 28);
        style(t, k, false);
        t.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) v.setAlpha(0.6f);
            else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) v.setAlpha(1f);
            return false;
        });
        t.setOnClickListener(v -> press(k));
        return t;
    }

    // ---- logic -------------------------------------------------------------------

    private void press(String k) {
        if (error && !k.equals("AC")) return;
        switch (k) {
            case "AC": acc = null; pending = 0; cur = "0"; fresh = false; error = false; break;
            case "±": if (!cur.equals("0")) cur = cur.startsWith("-") ? cur.substring(1) : "-" + cur; break;
            case "%": cur = fmt(new BigDecimal(cur).divide(BigDecimal.valueOf(100))); fresh = true; break;
            case ",": if (fresh) { cur = "0."; fresh = false; } else if (!cur.contains(".")) cur += "."; break;
            case "=": if (pending != 0) { compute(); pending = 0; acc = null; fresh = true; } break;
            case "÷": case "×": case "−": case "+": setOp(k.charAt(0)); break;
            default: // digit
                if (fresh) { cur = k; fresh = false; }
                else if (cur.equals("0")) cur = k;
                else if (cur.replace("-", "").replace(".", "").length() < 9) cur += k;
        }
        show();
    }

    private void setOp(char c) {
        if (pending != 0 && !fresh) compute(); else acc = new BigDecimal(cur);
        pending = c; fresh = true;
    }

    private void compute() {
        BigDecimal b = new BigDecimal(cur), r;
        switch (pending) {
            case '+': r = acc.add(b); break;
            case '−': r = acc.subtract(b); break;
            case '×': r = acc.multiply(b); break;
            default:
                if (b.signum() == 0) { error = true; cur = "Error"; acc = null; pending = 0; return; }
                r = acc.divide(b, new MathContext(12, RoundingMode.HALF_EVEN));
        }
        acc = r; cur = fmt(r);
    }

    private String fmt(BigDecimal v) {
        BigDecimal r = v.round(new MathContext(9, RoundingMode.HALF_EVEN));
        if (r.signum() == 0) return "0";
        r = r.stripTrailingZeros();
        int mag = r.precision() - r.scale();
        if (mag > 9 || mag < -5) return String.format(java.util.Locale.US, "%.5e", r.doubleValue()).replace("e+0", "e").replace("e+", "e");
        return r.toPlainString();
    }

    private String pretty(String s) {
        if (error) return s;
        boolean neg = s.startsWith("-");
        if (neg) s = s.substring(1);
        if (s.contains("e")) return (neg ? "-" : "") + s.replace('.', ',');
        String ip = s, fp = "";
        int dot = s.indexOf('.');
        if (dot >= 0) { ip = s.substring(0, dot); fp = "," + s.substring(dot + 1); }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < ip.length(); i++) {
            if (i > 0 && (ip.length() - i) % 3 == 0) sb.append('.');
            sb.append(ip.charAt(i));
        }
        return (neg ? "-" : "") + sb + fp;
    }

    private void show() {
        String s = pretty(cur);
        display.setText(s);
        int sp = s.length() <= 7 ? 84 : s.length() <= 9 ? 68 : s.length() <= 11 ? 54 : 44;
        display.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        TextView ac = btn.get("AC");
        ac.setText(!fresh && !cur.equals("0") && !error ? "C" : "AC");
        for (String k : new String[]{"÷", "×", "−", "+"})
            style(btn.get(k), k, pending != 0 && fresh && k.charAt(0) == pending);
    }
}
