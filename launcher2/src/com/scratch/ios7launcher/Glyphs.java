package com.scratch.ios7launcher;

import android.graphics.*;

/** Line-icon set drawn in code (48-unit grid, round caps), so no image assets are needed. */
final class Glyphs {
    private Glyphs() { }

    /** Maps a package name to a glyph key; null means "use the first letter". */
    static String kindFor(String pkg) {
        switch (pkg) {
            case "com.android.dialer":
            case "com.scratch.iosphone": return "phone";
            case "com.android.messaging": return "message";
            case "com.scratch.ioscamera":
            case "org.cyanogenmod.snap": return "camera";
            case "com.android.contacts": return "contacts";
            case "com.android.settings": return "settings";
            case "com.android.gallery3d":
            case "com.scratch.iosgallery": return "gallery";
            case "com.android.deskclock": return "clock";
            case "com.android.calculator2": return "calc";
            case "com.android.documentsui": return "folder";
            case "com.android.email": return "mail";
            case "com.google.android.calendar":
            case "com.android.calendar": return "calendar";
            case "com.cyanogenmod.eleven": return "music";
            case "org.lineageos.recorder": return "mic";
            case "com.android.vending": return "store";
            case "org.lineageos.jelly":
            case "com.android.chrome": return "globe";
            default: return null;
        }
    }

    /** Tile gradient (top, bottom) per glyph kind, from design/tokens.md. */
    static int[] gradientFor(String kind, String pkg) {
        if (kind == null) {
            int[][] others = {{0xFFC4B5FD, 0xFF6D28D9}, {0xFF67E8F9, 0xFF0E7490}, {0xFFFDBA74, 0xFFC2410C}, {0xFFA7F3D0, 0xFF047857}};
            return others[Math.abs(pkg.hashCode()) % others.length];
        }
        switch (kind) {
            case "phone": return new int[]{0xFF34D399, 0xFF059669};
            case "message": return new int[]{0xFF60A5FA, 0xFF2563EB};
            case "camera": return new int[]{0xFFF9A8D4, 0xFFDB2777};
            case "contacts": return new int[]{0xFFFDBA74, 0xFFEA580C};
            case "settings": return new int[]{0xFF94A3B8, 0xFF475569};
            case "gallery": return new int[]{0xFFF0ABFC, 0xFFC026D3};
            case "clock": return new int[]{0xFFA5B4FC, 0xFF4F46E5};
            case "calc": return new int[]{0xFFFDE68A, 0xFFD97706};
            case "folder": return new int[]{0xFFFCD34D, 0xFFB45309};
            case "mail": return new int[]{0xFF7DD3FC, 0xFF0284C7};
            case "calendar": return new int[]{0xFFFCA5A5, 0xFFDC2626};
            case "music": return new int[]{0xFFF9A8D4, 0xFFBE185D};
            case "mic": return new int[]{0xFFFDA4AF, 0xFFE11D48};
            case "store": return new int[]{0xFF5EEAD4, 0xFF0D9488};
            default: return new int[]{0xFF93C5FD, 0xFF1D4ED8};
        }
    }

    /** Draws the glyph centred in a (size x size) box at (0,0). */
    static void draw(Canvas c, String kind, float size, int color) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStrokeJoin(Paint.Join.ROUND);
        float u = size / 48f;
        p.setStrokeWidth(2.4f * u);
        c.save();
        c.scale(u, u);
        p.setStrokeWidth(2.4f);
        switch (kind) {
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
            case "message": {
                Path b = new Path();
                b.addRoundRect(new RectF(9, 11, 39, 32), 8, 8, Path.Direction.CW);
                c.drawPath(b, p);
                Path t = new Path();
                t.moveTo(16, 32);
                t.lineTo(15, 39);
                t.lineTo(23, 32);
                c.drawPath(t, p);
                break;
            }
            case "camera": {
                c.drawRoundRect(new RectF(8, 16, 40, 37), 6, 6, p);
                Path bump = new Path();
                bump.moveTo(17, 16);
                bump.lineTo(19.5f, 11);
                bump.lineTo(28.5f, 11);
                bump.lineTo(31, 16);
                c.drawPath(bump, p);
                c.drawCircle(24, 26.5f, 6.5f, p);
                break;
            }
            case "contacts":
                c.drawCircle(24, 18, 6, p);
                c.drawArc(new RectF(11, 27, 37, 51), 180, 180, false, p);
                break;
            case "settings": {
                c.drawCircle(24, 24, 5, p);
                c.drawCircle(24, 24, 11, p);
                for (int i = 0; i < 8; i++) {
                    double a = Math.PI / 4 * i;
                    c.drawLine(24 + (float) Math.cos(a) * 11, 24 + (float) Math.sin(a) * 11,
                            24 + (float) Math.cos(a) * 15, 24 + (float) Math.sin(a) * 15, p);
                }
                break;
            }
            case "gallery": {
                c.drawRoundRect(new RectF(8, 10, 40, 38), 7, 7, p);
                c.drawCircle(18, 20, 3, p);
                Path m = new Path();
                m.moveTo(9, 34);
                m.lineTo(20, 25);
                m.lineTo(27, 31);
                m.lineTo(32, 27);
                m.lineTo(39, 33);
                c.drawPath(m, p);
                break;
            }
            case "clock":
                c.drawCircle(24, 24, 15, p);
                c.drawLine(24, 24, 24, 14.5f, p);
                c.drawLine(24, 24, 30.5f, 27.5f, p);
                break;
            case "calc": {
                c.drawRoundRect(new RectF(11, 7, 37, 41), 6, 6, p);
                c.drawLine(16.5f, 15, 31.5f, 15, p);
                p.setStyle(Paint.Style.FILL);
                for (int r = 0; r < 2; r++) for (int k = 0; k < 3; k++) c.drawCircle(17 + k * 7, 25 + r * 8, 1.6f, p);
                break;
            }
            case "folder": {
                Path f = new Path();
                f.moveTo(8, 15);
                f.lineTo(19, 15);
                f.lineTo(23, 20);
                f.lineTo(37, 20);
                f.cubicTo(38.7f, 20, 40, 21.3f, 40, 23);
                f.lineTo(40, 35);
                f.cubicTo(40, 36.7f, 38.7f, 38, 37, 38);
                f.lineTo(11, 38);
                f.cubicTo(9.3f, 38, 8, 36.7f, 8, 35);
                f.close();
                c.drawPath(f, p);
                break;
            }
            case "mail": {
                c.drawRoundRect(new RectF(8, 13, 40, 35), 5, 5, p);
                Path v = new Path();
                v.moveTo(9.5f, 16);
                v.lineTo(24, 26.5f);
                v.lineTo(38.5f, 16);
                c.drawPath(v, p);
                break;
            }
            case "calendar": {
                c.drawRoundRect(new RectF(9, 11, 39, 39), 6, 6, p);
                c.drawLine(9, 20, 39, 20, p);
                c.drawLine(17, 7.5f, 17, 14, p);
                c.drawLine(31, 7.5f, 31, 14, p);
                p.setStyle(Paint.Style.FILL);
                c.drawCircle(24, 29.5f, 2.2f, p);
                break;
            }
            case "music": {
                c.drawCircle(17, 35, 4, p);
                c.drawCircle(33, 31, 4, p);
                c.drawLine(21, 35, 21, 14, p);
                c.drawLine(37, 31, 37, 10, p);
                c.drawLine(21, 14, 37, 10, p);
                break;
            }
            case "mic": {
                c.drawRoundRect(new RectF(19, 8, 29, 27), 5, 5, p);
                c.drawArc(new RectF(14, 17, 34, 35), 0, 180, false, p);
                c.drawLine(24, 35, 24, 41, p);
                break;
            }
            case "store": {
                Path t = new Path();
                t.moveTo(16, 11);
                t.lineTo(37, 24);
                t.lineTo(16, 37);
                t.close();
                c.drawPath(t, p);
                break;
            }
            case "globe": {
                c.drawCircle(24, 24, 15, p);
                c.drawOval(new RectF(17.5f, 9, 30.5f, 39), p);
                c.drawLine(9, 24, 39, 24, p);
                break;
            }
            default:
                break;
        }
        c.restore();
    }

    /** First letter on the tile, for apps without a glyph. */
    static void letter(Canvas c, String label, float size, int color) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color);
        p.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        p.setTextSize(size * 0.5f);
        p.setTextAlign(Paint.Align.CENTER);
        String s = label.isEmpty() ? "?" : label.substring(0, 1).toUpperCase();
        Rect b = new Rect();
        p.getTextBounds(s, 0, 1, b);
        c.drawText(s, size / 2f, size / 2f + b.height() / 2f, p);
    }
}
