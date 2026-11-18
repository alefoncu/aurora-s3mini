package com.scratch.ios7launcher;

import android.graphics.*;

/**
 * Hairline icons for text-only controls ({@link #glyph}) and small empty-state illustrations ({@link #doodle}).
 * Same language as {@link Tiles}: 48-unit box, round caps, one stroke weight. No assets, drawn in code.
 */
final class Icons {
    private Icons() { }

    private static Paint pen(int color, float u) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color); p.setStyle(Paint.Style.STROKE); p.setStrokeCap(Paint.Cap.ROUND); p.setStrokeJoin(Paint.Join.ROUND);
        p.setStrokeWidth(Math.max(1.5f, 2.2f * u));
        return p;
    }

    private static Path moon(float u, float cx, float cy, float r) {
        Path a = new Path(), b = new Path();
        a.addCircle(cx * u, cy * u, r * u, Path.Direction.CW);
        b.addCircle((cx + r * 0.55f) * u, (cy - r * 0.35f) * u, r * 0.9f * u, Path.Direction.CW);
        a.op(b, Path.Op.DIFFERENCE);
        return a;
    }

    private static void star(Canvas c, Paint p, float x, float y, float r) {
        c.drawLine(x - r, y, x + r, y, p); c.drawLine(x, y - r, x, y + r, p);
    }

    /** Small single-colour icon for a button or settings row. */
    static Bitmap glyph(String kind, int size, int color) {
        Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        float u = size / 48f;
        Paint p = pen(color, u);
        switch (kind) {
            case "ok": { Path q = new Path(); q.moveTo(11 * u, 25 * u); q.lineTo(20 * u, 34 * u); q.lineTo(37 * u, 14 * u); c.drawPath(q, p); break; }
            case "close": c.drawLine(13 * u, 13 * u, 35 * u, 35 * u, p); c.drawLine(35 * u, 13 * u, 13 * u, 35 * u, p); break;
            case "next": { Path q = new Path(); q.moveTo(18 * u, 11 * u); q.lineTo(31 * u, 24 * u); q.lineTo(18 * u, 37 * u); c.drawPath(q, p); break; }
            case "open": {
                c.drawRoundRect(new RectF(9 * u, 15 * u, 33 * u, 39 * u), 5 * u, 5 * u, p);
                c.drawLine(24 * u, 24 * u, 39 * u, 9 * u, p); c.drawLine(28 * u, 9 * u, 39 * u, 9 * u, p); c.drawLine(39 * u, 9 * u, 39 * u, 20 * u, p);
                break;
            }
            case "split": c.drawRoundRect(new RectF(9 * u, 9 * u, 39 * u, 39 * u), 6 * u, 6 * u, p); c.drawLine(9 * u, 24 * u, 39 * u, 24 * u, p); break;
            case "eye": {
                Path q = new Path();
                q.moveTo(6 * u, 24 * u); q.cubicTo(14 * u, 11 * u, 34 * u, 11 * u, 42 * u, 24 * u); q.cubicTo(34 * u, 37 * u, 14 * u, 37 * u, 6 * u, 24 * u);
                c.drawPath(q, p); c.drawCircle(24 * u, 24 * u, 5 * u, p);
                break;
            }
            case "contrast": {
                c.drawCircle(24 * u, 24 * u, 15 * u, p);
                p.setStyle(Paint.Style.FILL);
                c.drawArc(new RectF(9 * u, 9 * u, 39 * u, 39 * u), 90, 180, true, p);
                break;
            }
            case "text": {
                Paint t = new Paint(Paint.ANTI_ALIAS_FLAG); t.setColor(color); t.setTypeface(Typeface.create("sans-serif", Typeface.BOLD)); t.setTextAlign(Paint.Align.CENTER);
                t.setTextSize(30 * u); c.drawText("A", 18 * u, 36 * u, t);
                t.setTextSize(20 * u); c.drawText("a", 36 * u, 36 * u, t);
                break;
            }
            case "motion": for (int k = 0; k < 3; k++) { Path w = new Path(); float y = (16 + k * 8) * u; w.moveTo(9 * u, y); w.cubicTo(17 * u, y - 6 * u, 21 * u, y + 6 * u, 29 * u, y); w.cubicTo(33 * u, y - 3 * u, 36 * u, y - 2 * u, 39 * u, y - u); c.drawPath(w, p); } break;
            case "haptic": {
                c.drawRoundRect(new RectF(18 * u, 8 * u, 30 * u, 40 * u), 3.5f * u, 3.5f * u, p);
                c.drawArc(new RectF(4 * u, 16 * u, 14 * u, 32 * u), 120, 120, false, p); c.drawArc(new RectF(34 * u, 16 * u, 44 * u, 32 * u), -60, 120, false, p);
                break;
            }
            case "sound": {
                Path q = new Path(); q.moveTo(9 * u, 20 * u); q.lineTo(16 * u, 20 * u); q.lineTo(25 * u, 12 * u); q.lineTo(25 * u, 36 * u); q.lineTo(16 * u, 28 * u); q.lineTo(9 * u, 28 * u); q.close();
                c.drawPath(q, p); c.drawArc(new RectF(24 * u, 16 * u, 36 * u, 32 * u), -50, 100, false, p); c.drawArc(new RectF(24 * u, 10 * u, 44 * u, 38 * u), -50, 100, false, p);
                break;
            }
            case "lock": {
                c.drawRoundRect(new RectF(11 * u, 21 * u, 37 * u, 40 * u), 4 * u, 4 * u, p);
                c.drawArc(new RectF(16 * u, 7 * u, 32 * u, 31 * u), 180, 180, false, p); c.drawLine(16 * u, 19 * u, 16 * u, 21 * u, p); c.drawLine(32 * u, 19 * u, 32 * u, 21 * u, p);
                p.setStyle(Paint.Style.FILL); c.drawCircle(24 * u, 30 * u, 2.2f * u, p);
                break;
            }
            case "season": {
                Path q = new Path(); q.moveTo(12 * u, 36 * u); q.cubicTo(8 * u, 18 * u, 22 * u, 8 * u, 38 * u, 10 * u); q.cubicTo(40 * u, 26 * u, 30 * u, 38 * u, 12 * u, 36 * u);
                c.drawPath(q, p); c.drawLine(12 * u, 36 * u, 28 * u, 20 * u, p);
                break;
            }
            case "tap": c.drawCircle(24 * u, 24 * u, 4 * u, p); c.drawCircle(24 * u, 24 * u, 11 * u, p); c.drawCircle(24 * u, 24 * u, 18 * u, p); break;
            case "focus": {
                c.drawCircle(24 * u, 24 * u, 15 * u, p); c.drawLine(24 * u, 5 * u, 24 * u, 13 * u, p); c.drawLine(24 * u, 35 * u, 24 * u, 43 * u, p);
                c.drawLine(5 * u, 24 * u, 13 * u, 24 * u, p); c.drawLine(35 * u, 24 * u, 43 * u, 24 * u, p);
                p.setStyle(Paint.Style.FILL); c.drawCircle(24 * u, 24 * u, 3 * u, p);
                break;
            }
            case "simple": for (int i = 0; i < 4; i++) c.drawRoundRect(new RectF((9 + (i % 2) * 17) * u, (9 + (i / 2) * 17) * u, (22 + (i % 2) * 17) * u, (22 + (i / 2) * 17) * u), 4 * u, 4 * u, p); break;
            case "cards": c.drawRoundRect(new RectF(13 * u, 8 * u, 40 * u, 30 * u), 5 * u, 5 * u, p); c.drawRoundRect(new RectF(8 * u, 18 * u, 35 * u, 40 * u), 5 * u, 5 * u, p); break;
            case "chart": { Path q = new Path(); q.moveTo(8 * u, 34 * u); q.cubicTo(16 * u, 34 * u, 18 * u, 14 * u, 26 * u, 14 * u); q.cubicTo(33 * u, 14 * u, 34 * u, 30 * u, 41 * u, 30 * u); c.drawPath(q, p); c.drawLine(8 * u, 41 * u, 41 * u, 41 * u, p); break; }
            case "tour": {
                c.drawCircle(24 * u, 24 * u, 17 * u, p);
                c.drawArc(new RectF(18 * u, 14 * u, 30 * u, 26 * u), 180, 230, false, p); c.drawLine(24 * u, 26 * u, 24 * u, 29 * u, p);
                p.setStyle(Paint.Style.FILL); c.drawCircle(24 * u, 34 * u, 1.8f * u, p);
                break;
            }
            case "day": { c.drawLine(18 * u, 8 * u, 18 * u, 40 * u, p); for (int i = 0; i < 3; i++) { c.drawCircle(18 * u, (14 + i * 10) * u, 3 * u, p); c.drawLine(26 * u, (14 + i * 10) * u, 40 * u, (14 + i * 10) * u, p); } break; }
            case "moon": c.drawPath(moon(u, 24, 24, 15), p); break;
            case "sparkle": star(c, p, 24 * u, 24 * u, 14 * u); star(c, p, 24 * u, 24 * u, 0.1f * u); c.drawLine(15 * u, 15 * u, 33 * u, 33 * u, p); c.drawLine(33 * u, 15 * u, 15 * u, 33 * u, p); break;
            case "grid": for (int i = 0; i < 4; i++) c.drawCircle((15 + (i % 2) * 18) * u, (15 + (i / 2) * 18) * u, 5 * u, p); break;
            case "bell": c.drawArc(new RectF(14 * u, 10 * u, 34 * u, 32 * u), 180, 180, false, p); c.drawLine(14 * u, 21 * u, 14 * u, 32 * u, p); c.drawLine(34 * u, 21 * u, 34 * u, 32 * u, p); c.drawLine(10 * u, 32 * u, 38 * u, 32 * u, p); c.drawArc(new RectF(20 * u, 30 * u, 28 * u, 40 * u), 20, 140, false, p); break;
            default: c.drawCircle(24 * u, 24 * u, 12 * u, p);
        }
        return b;
    }

    /** Larger two-colour illustration for an empty state: hairline in ink, one soft accent shape. */
    static Bitmap doodle(String kind, int size, int ink, int accent) {
        Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        float u = size / 48f;
        Paint p = pen(ink, u), f = new Paint(Paint.ANTI_ALIAS_FLAG);
        f.setColor((accent & 0xFFFFFF) | 0x66000000);
        switch (kind) {
            case "sleep": {            // crescent moon, three z, two stars
                c.drawCircle(21 * u, 26 * u, 14 * u, f);
                c.drawPath(moon(u, 21, 26, 14), p);
                Paint t = new Paint(Paint.ANTI_ALIAS_FLAG); t.setColor(ink); t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
                t.setTextSize(11 * u); c.drawText("z", 33 * u, 22 * u, t); t.setTextSize(15 * u); c.drawText("z", 37 * u, 15 * u, t); t.setTextSize(7 * u); c.drawText("z", 30 * u, 28 * u, t);
                star(c, p, 9 * u, 11 * u, 2.4f * u); star(c, p, 40 * u, 38 * u, 2f * u);
                break;
            }
            case "freeday": {          // sun over a calm horizon
                c.drawCircle(24 * u, 22 * u, 10 * u, f);
                c.drawCircle(24 * u, 22 * u, 10 * u, p);
                for (int i = 0; i < 8; i++) { double a = Math.PI * i / 4; c.drawLine((float) (24 + 14 * Math.cos(a)) * u, (float) (22 + 14 * Math.sin(a)) * u, (float) (24 + 18 * Math.cos(a)) * u, (float) (22 + 18 * Math.sin(a)) * u, p); }
                c.drawLine(6 * u, 41 * u, 42 * u, 41 * u, p);
                break;
            }
            case "notes": {            // page with lines and a pencil
                c.drawRoundRect(new RectF(9 * u, 8 * u, 33 * u, 40 * u), 4 * u, 4 * u, f);
                c.drawRoundRect(new RectF(9 * u, 8 * u, 33 * u, 40 * u), 4 * u, 4 * u, p);
                for (int i = 0; i < 3; i++) c.drawLine(14 * u, (18 + i * 7) * u, 28 * u, (18 + i * 7) * u, p);
                c.drawLine(40 * u, 15 * u, 28 * u, 33 * u, p); c.drawLine(37 * u, 13 * u, 43 * u, 17 * u, p); c.drawLine(28 * u, 33 * u, 27 * u, 38 * u, p); c.drawLine(27 * u, 38 * u, 32 * u, 35 * u, p);
                break;
            }
            case "recents": {          // three stacked cards
                c.drawRoundRect(new RectF(14 * u, 7 * u, 40 * u, 33 * u), 5 * u, 5 * u, p);
                c.drawRoundRect(new RectF(10 * u, 12 * u, 36 * u, 38 * u), 5 * u, 5 * u, p);
                c.drawRoundRect(new RectF(6 * u, 17 * u, 32 * u, 43 * u), 5 * u, 5 * u, f);
                c.drawRoundRect(new RectF(6 * u, 17 * u, 32 * u, 43 * u), 5 * u, 5 * u, p);
                break;
            }
            case "offline": {          // cloud with a slash
                Path q = new Path();
                q.moveTo(14 * u, 34 * u); q.cubicTo(6 * u, 34 * u, 6 * u, 22 * u, 15 * u, 22 * u); q.cubicTo(16 * u, 12 * u, 33 * u, 12 * u, 34 * u, 24 * u); q.cubicTo(42 * u, 24 * u, 42 * u, 34 * u, 34 * u, 34 * u); q.close();
                c.drawPath(q, f); c.drawPath(q, p); c.drawLine(10 * u, 41 * u, 38 * u, 9 * u, p);
                break;
            }
            case "inbox": {            // tray with a check
                Path q = new Path();
                q.moveTo(7 * u, 26 * u); q.lineTo(14 * u, 12 * u); q.lineTo(34 * u, 12 * u); q.lineTo(41 * u, 26 * u); q.lineTo(41 * u, 38 * u); q.lineTo(7 * u, 38 * u); q.close();
                c.drawPath(q, f); c.drawPath(q, p); c.drawPath(inboxLip(u), p);
                Path ck = new Path(); ck.moveTo(18 * u, 21 * u); ck.lineTo(22 * u, 25 * u); ck.lineTo(30 * u, 16 * u); c.drawPath(ck, p);
                break;
            }
            case "chart": {            // axes with a dotted unknown curve
                c.drawLine(8 * u, 8 * u, 8 * u, 40 * u, p); c.drawLine(8 * u, 40 * u, 42 * u, 40 * u, p);
                for (int i = 0; i < 6; i++) c.drawPoint((12 + i * 5.4f) * u, (34 - (float) Math.sin(i * 0.9) * 10 - i * 1.5f) * u, p);
                c.drawCircle(36 * u, 14 * u, 4 * u, f);
                break;
            }
            default: c.drawCircle(24 * u, 24 * u, 14 * u, p);
        }
        return b;
    }

    private static Path inboxLip(float u) { Path q = new Path(); q.moveTo(7 * u, 26 * u); q.lineTo(18 * u, 26 * u); q.lineTo(20 * u, 30 * u); q.lineTo(28 * u, 30 * u); q.lineTo(30 * u, 26 * u); q.lineTo(41 * u, 26 * u); return q; }
}
