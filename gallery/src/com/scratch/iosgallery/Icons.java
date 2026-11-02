package com.scratch.iosgallery;

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
        c.save();
        c.scale(size / 48f, size / 48f);
        p.setStrokeWidth(strokeUnits * 1.2f);
        switch (kind) {
            case "back":
                c.drawLine(30, 10, 14, 24, p);
                c.drawLine(14, 24, 30, 38, p);
                break;
            case "share":
                c.drawLine(24, 28, 24, 8, p);
                c.drawLine(24, 8, 16, 16, p);
                c.drawLine(24, 8, 32, 16, p);
                c.drawRoundRect(new RectF(11, 22, 37, 41), 5, 5, p);
                break;
            case "trash":
                c.drawLine(10, 14, 38, 14, p);
                c.drawLine(19, 14, 19, 9, p);
                c.drawLine(19, 9, 29, 9, p);
                c.drawLine(29, 9, 29, 14, p);
                c.drawRoundRect(new RectF(13, 14, 35, 41), 4, 4, p);
                c.drawLine(20, 21, 20, 34, p);
                c.drawLine(28, 21, 28, 34, p);
                break;
            case "play": {
                p.setStyle(Paint.Style.FILL);
                Path t = new Path();
                t.moveTo(17, 11); t.lineTo(37, 24); t.lineTo(17, 37); t.close();
                c.drawPath(t, p);
                break;
            }
            default:
                break;
        }
        c.restore();
    }
}
