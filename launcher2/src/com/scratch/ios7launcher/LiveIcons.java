package com.scratch.ios7launcher;

import android.graphics.*;
import java.util.Calendar;
import java.util.Locale;

/** Icons that show live data: the calendar shows today's date, the clock shows the real time. */
final class LiveIcons {
    static final String CALENDAR = "com.scratch.ioscalendar", CLOCK = "com.scratch.iosclock";

    static boolean isLive(String pkg) { return CALENDAR.equals(pkg) || CLOCK.equals(pkg); }

    static Bitmap make(String pkg, int s, int[] grad, Path sq, float d) {
        return CALENDAR.equals(pkg) ? calendar(s, sq, d) : clock(s, grad, sq, d);
    }

    private static Bitmap calendar(int s, Path sq, float d) {
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new LinearGradient(0, 0, 0, s, 0xFFFFFFFF, 0xFFE9E6FA, Shader.TileMode.CLAMP));
        c.drawPath(sq, p);
        p.setShader(null);
        p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(Math.max(1f, d * 0.75f)); p.setColor(0x40FFFFFF);
        c.drawPath(sq, p);
        Calendar now = Calendar.getInstance();
        String wd = now.getDisplayName(Calendar.DAY_OF_WEEK, Calendar.SHORT, new Locale("es")).replace(".", "").toUpperCase(new Locale("es"));
        p.setStyle(Paint.Style.FILL);
        p.setTextAlign(Paint.Align.CENTER);
        p.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        p.setColor(0xFFFF3B5C);
        p.setTextSize(s * 0.2f);
        p.setLetterSpacing(0.12f);
        c.drawText(wd, s / 2f, s * 0.31f, p);
        p.setLetterSpacing(0f);
        p.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        p.setColor(0xFF14123A);
        p.setTextSize(s * 0.56f);
        c.drawText(String.valueOf(now.get(Calendar.DAY_OF_MONTH)), s / 2f, s * 0.80f, p);
        return b;
    }

    private static Bitmap clock(int s, int[] g, Path sq, float d) {
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new LinearGradient(0, 0, 0, s, g[0], g[1], Shader.TileMode.CLAMP));
        c.drawPath(sq, p);
        p.setShader(null);
        p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(Math.max(1f, d * 0.75f)); p.setColor(0x40FFFFFF);
        c.drawPath(sq, p);
        float cx = s / 2f, cy = s / 2f, r = s * 0.34f;
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStrokeWidth(Math.max(1.5f, s * 0.035f));
        p.setColor(Color.WHITE);
        c.drawCircle(cx, cy, r, p);
        // 12 hairline ticks
        p.setStrokeWidth(Math.max(1f, s * 0.02f));
        p.setColor(0xB3FFFFFF);
        for (int i = 0; i < 12; i++) {
            double a = Math.toRadians(i * 30);
            float r1 = r * (i % 3 == 0 ? 0.80f : 0.88f), r2 = r * 0.95f;
            c.drawLine(cx + (float) Math.sin(a) * r1, cy - (float) Math.cos(a) * r1, cx + (float) Math.sin(a) * r2, cy - (float) Math.cos(a) * r2, p);
        }
        Calendar t = Calendar.getInstance();
        float m = t.get(Calendar.MINUTE), h = t.get(Calendar.HOUR) + m / 60f;
        p.setColor(Color.WHITE);
        p.setStrokeWidth(Math.max(2f, s * 0.045f));
        hand(c, p, cx, cy, h * 30f, r * 0.5f);
        p.setStrokeWidth(Math.max(1.5f, s * 0.03f));
        hand(c, p, cx, cy, m * 6f, r * 0.76f);
        p.setStyle(Paint.Style.FILL);
        p.setColor(0xFFFF3B5C);
        c.drawCircle(cx, cy, s * 0.035f, p);
        return b;
    }

    private static void hand(Canvas c, Paint p, float cx, float cy, float deg, float len) {
        double a = Math.toRadians(deg);
        c.drawLine(cx, cy, cx + (float) Math.sin(a) * len, cy - (float) Math.cos(a) * len, p);
    }
}
