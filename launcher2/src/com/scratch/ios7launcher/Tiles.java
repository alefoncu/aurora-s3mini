package com.scratch.ios7launcher;

import android.graphics.*;

/** Hairline glyphs for the Control Center tiles (drawn in a 48-unit box). */
final class Tiles {
    static Bitmap make(String kind, int size, int color) {
        Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        float u = size / 48f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color); p.setStyle(Paint.Style.STROKE); p.setStrokeCap(Paint.Cap.ROUND); p.setStrokeJoin(Paint.Join.ROUND);
        p.setStrokeWidth(Math.max(1.6f, 2.2f * u));
        switch (kind) {
            case "wifi": {
                float cx = 24 * u, cy = 36 * u;
                for (int i = 1; i <= 3; i++) {
                    float r = i * 9 * u;
                    c.drawArc(new RectF(cx - r, cy - r, cx + r, cy + r), 225, 90, false, p);
                }
                p.setStyle(Paint.Style.FILL);
                c.drawCircle(cx, cy, 2.6f * u, p);
                break;
            }
            case "bt": {
                Path q = new Path();
                q.moveTo(16 * u, 17 * u); q.lineTo(32 * u, 31 * u); q.lineTo(24 * u, 38 * u); q.lineTo(24 * u, 10 * u);
                q.lineTo(32 * u, 17 * u); q.lineTo(16 * u, 31 * u);
                c.drawPath(q, p);
                break;
            }
            case "torch": {
                Path q = new Path();
                q.moveTo(17 * u, 9 * u); q.lineTo(31 * u, 9 * u); q.lineTo(29 * u, 18 * u); q.lineTo(19 * u, 18 * u); q.close();
                c.drawPath(q, p);
                c.drawRoundRect(new RectF(19 * u, 18 * u, 29 * u, 40 * u), 4 * u, 4 * u, p);
                c.drawLine(24 * u, 24 * u, 24 * u, 29 * u, p);
                break;
            }
            case "sun": case "moon": case "partly": case "cloud": case "rain": case "snow": case "storm": case "fog": {
                weather(c, p, kind, u);
                break;
            }
            case "mute": {
                Path bell = new Path();
                bell.moveTo(14.5f * u, 31 * u); bell.lineTo(14.5f * u, 23 * u); bell.cubicTo(14.5f * u, 13 * u, 33.5f * u, 13 * u, 33.5f * u, 23 * u); bell.lineTo(33.5f * u, 31 * u);
                c.drawPath(bell, p);
                c.drawLine(11 * u, 31 * u, 37 * u, 31 * u, p);
                c.drawArc(new RectF(20.5f * u, 29 * u, 27.5f * u, 38 * u), 20, 140, false, p);
                c.drawLine(10 * u, 10 * u, 38 * u, 40 * u, p);
                break;
            }
            case "aurora": {
                for (int k = 0; k < 3; k++) {
                    Path w = new Path();
                    float y = (16 + k * 8) * u;
                    w.moveTo(9 * u, y);
                    w.cubicTo(17 * u, y - 6 * u, 21 * u, y + 6 * u, 29 * u, y);
                    w.cubicTo(33 * u, y - 3 * u, 36 * u, y - 2 * u, 39 * u, y - 1 * u);
                    c.drawPath(w, p);
                }
                break;
            }
            case "rot": {
                // one clean circular arrow with a small phone inside
                c.drawRoundRect(new RectF(19.4f * u, 14.2f * u, 28.6f * u, 33.8f * u), 2.4f * u, 2.4f * u, p);
                arrowArc(c, p, 24 * u, 24 * u, 18.5f * u, -50, 284, u * 1.4f);
                break;
            }
        }
        return b;
    }

    private static void cloud(Canvas c, Paint p, float u, float dy) {
        Path q = new Path();
        q.moveTo(14 * u, 32 * u + dy);
        q.cubicTo(6 * u, 32 * u + dy, 6 * u, 20 * u + dy, 15 * u, 20 * u + dy);
        q.cubicTo(17 * u, 11 * u + dy, 32 * u, 11 * u + dy, 34 * u, 21 * u + dy);
        q.cubicTo(43 * u, 20 * u + dy, 43 * u, 32 * u + dy, 35 * u, 32 * u + dy);
        q.close();
        c.drawPath(q, p);
    }

    private static void rays(Canvas c, Paint p, float cx, float cy, float r1, float r2) {
        for (int i = 0; i < 8; i++) {
            double a = Math.toRadians(i * 45);
            c.drawLine(cx + (float) Math.sin(a) * r1, cy - (float) Math.cos(a) * r1, cx + (float) Math.sin(a) * r2, cy - (float) Math.cos(a) * r2, p);
        }
    }

    static void weather(Canvas c, Paint p, String kind, float u) {
        switch (kind) {
            case "sun": c.drawCircle(24 * u, 24 * u, 8 * u, p); rays(c, p, 24 * u, 24 * u, 13 * u, 19 * u); break;
            case "moon": {
                // crescent = big circle minus an offset circle (the weather glyph for clear nights and the "dark mode" tile)
                Path big = new Path(), cut = new Path(), cres = new Path();
                big.addCircle(23 * u, 25 * u, 14 * u, Path.Direction.CW);
                cut.addCircle(31 * u, 19 * u, 12.5f * u, Path.Direction.CW);
                if (android.os.Build.VERSION.SDK_INT >= 19 && cres.op(big, cut, Path.Op.DIFFERENCE)) c.drawPath(cres, p);
                else c.drawPath(big, p);
                break;
            }
            case "partly": c.save(); c.translate(-2 * u, 2 * u); c.drawCircle(18 * u, 16 * u, 6 * u, p); rays(c, p, 18 * u, 16 * u, 9.5f * u, 13 * u); c.restore(); cloud(c, p, u, 4 * u); break;
            case "cloud": cloud(c, p, u, 0); break;
            case "fog": cloud(c, p, u, -5 * u); c.drawLine(12 * u, 33 * u, 36 * u, 33 * u, p); c.drawLine(16 * u, 39 * u, 32 * u, 39 * u, p); break;
            case "rain": cloud(c, p, u, -5 * u); for (int i = 0; i < 3; i++) c.drawLine((17 + i * 7) * u, 34 * u, (14 + i * 7) * u, 41 * u, p); break;
            case "snow": cloud(c, p, u, -5 * u); p.setStyle(Paint.Style.FILL); for (int i = 0; i < 3; i++) c.drawCircle((16 + i * 8) * u, (37 + (i % 2) * 3) * u, 1.8f * u, p); break;
            case "storm": {
                cloud(c, p, u, -5 * u);
                Path z = new Path();
                z.moveTo(26 * u, 28 * u); z.lineTo(20 * u, 37 * u); z.lineTo(26 * u, 37 * u); z.lineTo(21 * u, 45 * u);
                c.drawPath(z, p);
                break;
            }
        }
    }

    /** Arc from {@code start} degrees sweeping clockwise, ending in a small open arrowhead. */
    private static void arrowArc(Canvas c, Paint p, float cx, float cy, float r, float start, float sweep, float u) {
        c.drawArc(new RectF(cx - r, cy - r, cx + r, cy + r), start, sweep, false, p);
        double a = Math.toRadians(start + sweep);
        float px = cx + (float) Math.cos(a) * r, py = cy + (float) Math.sin(a) * r;
        float tx = (float) -Math.sin(a), ty = (float) Math.cos(a);        // clockwise tangent
        float nx = (float) Math.cos(a), ny = (float) Math.sin(a);         // radial
        float len = 4.2f * u, wing = 3.6f * u;
        Path h = new Path();
        h.moveTo(px - tx * len * 0.2f + nx * wing, py - ty * len * 0.2f + ny * wing);
        h.lineTo(px + tx * len, py + ty * len);
        h.lineTo(px - tx * len * 0.2f - nx * wing, py - ty * len * 0.2f - ny * wing);
        c.drawPath(h, p);
    }
}
