package com.scratch.iosphone;

import android.graphics.*;

/** Line glyphs on a 48-unit grid, drawn in code (same style as the launcher set). */
final class Icons {
    private Icons() { }

    static void draw(Canvas c, String kind, float size, int color, float strokeUnits) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStrokeJoin(Paint.Join.ROUND);
        float u = size / 48f;
        c.save();
        c.scale(u, u);
        p.setStrokeWidth(strokeUnits * 1.2f);
        switch (kind) {
            case "clock":
                c.drawCircle(24, 24, 16, p);
                c.drawLine(24, 24, 24, 13, p);
                c.drawLine(24, 24, 31, 28, p);
                break;
            case "person":
                c.drawCircle(24, 17, 7, p);
                c.drawArc(new RectF(10, 28, 38, 56), 180, 180, false, p);
                break;
            case "keypad": {
                p.setStyle(Paint.Style.FILL);
                float[] xs = {14, 24, 34};
                for (float y : new float[]{12, 22, 32, 42}) for (float x : xs) c.drawCircle(x, y, 2.6f, p);
                break;
            }
            case "phone": {
                Path h = new Path();
                h.moveTo(14, 10);
                h.lineTo(19.5f, 10);
                h.lineTo(21.5f, 17);
                h.lineTo(18, 19.5f);
                h.cubicTo(20, 24, 24, 28, 28.5f, 30);
                h.lineTo(31, 26.5f);
                h.lineTo(38, 28.5f);
                h.lineTo(38, 34);
                h.cubicTo(38, 36, 36.5f, 37.5f, 34.5f, 37.5f);
                h.cubicTo(22, 37, 11, 26, 10.5f, 13.5f);
                h.cubicTo(10.5f, 11.5f, 12, 10, 14, 10);
                h.close();
                c.drawPath(h, p);
                break;
            }
            case "backspace": {
                Path b = new Path();
                b.moveTo(5, 24);
                b.lineTo(16, 11);
                b.lineTo(40, 11);
                b.lineTo(40, 37);
                b.lineTo(16, 37);
                b.close();
                c.drawPath(b, p);
                c.drawLine(22, 18, 32, 30, p);
                c.drawLine(32, 18, 22, 30, p);
                break;
            }
            case "out":
                c.drawLine(13, 35, 35, 13, p);
                c.drawLine(21, 13, 35, 13, p);
                c.drawLine(35, 13, 35, 27, p);
                break;
            default: // "in" and "missed"
                c.drawLine(35, 13, 13, 35, p);
                c.drawLine(13, 21, 13, 35, p);
                c.drawLine(13, 35, 27, 35, p);
                break;
        }
        c.restore();
    }
}
