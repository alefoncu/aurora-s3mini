package com.scratch.iosweather;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;

/** Small, resolution-independent outline weather symbols. Size is in canvas pixels. */
public final class WeatherGlyph {
    private WeatherGlyph() { }

    public static String kind(int code, boolean isDay) {
        if (code == 0 || code == 1) return isDay ? "sun" : "moon";
        if (code == 2) return isDay ? "partly" : "partly_night";
        if (code == 3) return "cloud";
        if (code == 45 || code == 48) return "fog";
        if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67)
                || (code >= 80 && code <= 82)) return "rain";
        if ((code >= 71 && code <= 77) || code == 85 || code == 86) return "snow";
        if (code >= 95) return "storm";
        return "cloud";
    }

    public static void draw(Canvas canvas, String kind, float cx, float cy, float size, int color) {
        if (canvas == null || !(size > 0) || Float.isInfinite(size)) return;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(0.065f);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStrokeJoin(Paint.Join.ROUND);
        canvas.save();
        canvas.translate(cx, cy);
        canvas.scale(size, size);
        if ("sun".equals(kind)) sun(canvas, p, 0, 0, 0.19f);
        else if ("moon".equals(kind)) moon(canvas, p, 0, 0, 0.32f);
        else {
            boolean partly = "partly".equals(kind) || "partly_night".equals(kind);
            boolean rain = "rain".equals(kind), snow = "snow".equals(kind);
            boolean storm = "storm".equals(kind), fog = "fog".equals(kind);
            if (partly) {
                if ("partly_night".equals(kind)) moon(canvas, p, -0.18f, -0.18f, 0.22f);
                else sun(canvas, p, -0.18f, -0.18f, 0.125f);
            }
            float cloudY = rain || snow || storm || fog ? -0.11f : 0.05f;
            cloud(canvas, p, cloudY);
            if (rain) {
                for (int i = 0; i < 3; i++) {
                    float x = -0.20f + 0.20f * i;
                    canvas.drawLine(x + 0.035f, 0.20f, x - 0.035f, 0.34f, p);
                }
            } else if (snow) {
                p.setStyle(Paint.Style.FILL);
                for (int i = 0; i < 3; i++) canvas.drawCircle(-0.21f + 0.21f * i, 0.27f, 0.025f, p);
            } else if (storm) {
                Path bolt = new Path();
                bolt.moveTo(0.05f, 0.16f); bolt.lineTo(-0.07f, 0.29f);
                bolt.lineTo(0.04f, 0.29f); bolt.lineTo(-0.05f, 0.43f);
                canvas.drawPath(bolt, p);
            } else if (fog) {
                canvas.drawLine(-0.30f, 0.24f, 0.30f, 0.24f, p);
                canvas.drawLine(-0.23f, 0.35f, 0.23f, 0.35f, p);
            }
        }
        canvas.restore();
    }

    private static void sun(Canvas c, Paint p, float x, float y, float radius) {
        c.drawCircle(x, y, radius, p);
        for (int i = 0; i < 8; i++) {
            double angle = i * Math.PI / 4;
            float co = (float) Math.cos(angle), si = (float) Math.sin(angle);
            c.drawLine(x + co * (radius + 0.07f), y + si * (radius + 0.07f),
                    x + co * (radius + 0.145f), y + si * (radius + 0.145f), p);
        }
    }

    private static void moon(Canvas c, Paint p, float x, float y, float r) {
        // A single outline avoids opaque cutouts, preserving the wallpaper behind it.
        Path moon = new Path();
        moon.moveTo(x + r * 0.40f, y - r * 0.88f);
        moon.cubicTo(x - r * 0.95f, y - r * 1.05f, x - r * 1.22f, y + r * 0.70f, x - r * 0.16f, y + r * 0.94f);
        moon.cubicTo(x + r * 0.44f, y + r * 1.10f, x + r * 0.94f, y + r * 0.68f, x + r * 0.96f, y + r * 0.23f);
        moon.cubicTo(x + r * 0.01f, y + r * 0.47f, x - r * 0.24f, y - r * 0.36f, x + r * 0.40f, y - r * 0.88f);
        moon.close(); c.drawPath(moon, p);
    }

    private static void cloud(Canvas c, Paint p, float y) {
        Path cloud = new Path();
        cloud.moveTo(-0.25f, y + 0.15f);
        cloud.cubicTo(-0.48f, y + 0.15f, -0.47f, y - 0.14f, -0.27f, y - 0.16f);
        cloud.cubicTo(-0.20f, y - 0.43f, 0.17f, y - 0.43f, 0.25f, y - 0.15f);
        cloud.cubicTo(0.48f, y - 0.16f, 0.50f, y + 0.15f, 0.27f, y + 0.15f);
        cloud.close(); c.drawPath(cloud, p);
    }
}
