package com.scratch.ios7launcher;

import android.graphics.Bitmap;

import java.util.Calendar;

/**
 * The aurora: a flowing colour field computed per pixel at 40x67 (1/12 of the screen) and stretched with bilinear
 * filtering. The live wallpaper draws it; the launcher's glass reads the very same bitmap, so the frosted panels
 * always show exactly what is moving behind them. Palette follows the clock continuously and reacts to the weather.
 */
final class AuroraField {
    static final int W = 40, H = 67;

    /** Latest finished frame (shared with Glass). Written by the wallpaper thread, read on the UI thread. */
    static volatile Bitmap front;
    static volatile boolean launcherVisible;
    static volatile long lastFrame;
    /** Reduced motion: the wallpaper redraws once a second instead of ~15 times (saves battery, calmer). */
    static volatile boolean reduced;

    private static final float[] SIN = new float[1024];
    static { for (int i = 0; i < 1024; i++) SIN[i] = (float) Math.sin(i * 2 * Math.PI / 1024); }
    private static float sin(float x) { return SIN[((int) (x * 162.97466f)) & 1023]; }

    // palette: top, bottom, accent A, accent B, accent C
    private static final int[][] NIGHT = {{0x090D2E, 0x2B1255, 0x2DD4BF, 0xA855F7, 0x3B82F6}};
    private static final int[][] DAWN  = {{0x5B6CD6, 0xF9A8B8, 0xFDBA74, 0xC084FC, 0x7DD3FC}};
    private static final int[][] DAY   = {{0x5A8CF0, 0xF3B9E6, 0xA5B4FC, 0xFFD1A8, 0x93C5FD}};
    private static final int[][] DUSK  = {{0x3B3A9E, 0xF472B6, 0xFB923C, 0xA855F7, 0x38BDF8}};

    /** Palette for a fractional hour of the day, blended between keyframes so nothing ever "switches". */
    static void palette(float hour, int[] out) {
        float[] h = {0f, 5f, 7f, 10f, 16f, 18.5f, 21f, 24f};
        int[][][] k = {NIGHT, NIGHT, DAWN, DAY, DAY, DUSK, NIGHT, NIGHT};
        int i = 0;
        while (i < h.length - 2 && hour >= h[i + 1]) i++;
        float f = (hour - h[i]) / (h[i + 1] - h[i]);
        f = f * f * (3 - 2 * f);
        for (int c = 0; c < 5; c++) out[c] = mix(k[i][0][c], k[i + 1][0][c], f);
    }

    static int mix(int a, int b, float f) {
        int r = (int) (((a >> 16) & 255) * (1 - f) + ((b >> 16) & 255) * f);
        int g = (int) (((a >> 8) & 255) * (1 - f) + ((b >> 8) & 255) * f);
        int bl = (int) ((a & 255) * (1 - f) + (b & 255) * f);
        return (r << 16) | (g << 8) | bl;
    }

    /** Weather tint: rain and storms darken and desaturate, fog and cloud wash out, snow whitens. Returns the animation speed factor. */
    static float applyWeather(String kind, int[] pal) {
        if (kind == null) return 1f;
        int target; float amt, speed = 1f;
        switch (kind) {
            case "rain": case "storm": target = 0x34405E; amt = 0.38f; speed = 0.75f; break;
            case "snow": target = 0xF0F4FF; amt = 0.28f; speed = 0.6f; break;
            case "fog": target = 0xC9CEDA; amt = 0.32f; speed = 0.5f; break;
            case "cloud": target = 0x8A93AD; amt = 0.07f; speed = 0.85f; break;
            default: return 1f;
        }
        for (int c = 0; c < 5; c++) pal[c] = mix(pal[c], target, amt);
        return speed;
    }

    static float hourNow() {
        Calendar c = Calendar.getInstance();
        return c.get(Calendar.HOUR_OF_DAY) + c.get(Calendar.MINUTE) / 60f + c.get(Calendar.SECOND) / 3600f;
    }

    /** Fills px (W*H) with the field at time t seconds. pan: page offset 0..1, tx/ty: device tilt in g (about -1..1). */
    static void render(int[] px, float t, float pan, float tx, float ty, int[] pal, float speed) {
        final float tt = t * speed;
        final float tr = (pal[0] >> 16) & 255, tg = (pal[0] >> 8) & 255, tb = pal[0] & 255;
        final float br = (pal[1] >> 16) & 255, bg = (pal[1] >> 8) & 255, bb = pal[1] & 255;
        final float ar = (pal[2] >> 16) & 255, ag = (pal[2] >> 8) & 255, ab = pal[2] & 255;
        final float cr = (pal[3] >> 16) & 255, cg = (pal[3] >> 8) & 255, cb = pal[3] & 255;
        final float dr = (pal[4] >> 16) & 255, dg = (pal[4] >> 8) & 255, db = pal[4] & 255;
        int i = 0;
        for (int y = 0; y < H; y++) {
            final float v = y / (float) (H - 1) + ty * 0.10f;
            final float mask = Math.max(0f, 1f - Math.abs(v - 0.34f) * 1.55f);
            final float bgr = tr + (br - tr) * (y / (float) (H - 1)), bgg = tg + (bg - tg) * (y / (float) (H - 1)), bgb = tb + (bb - tb) * (y / (float) (H - 1));
            final float s1 = sin(v * 5.5f + tt * 0.21f) * 1.3f, s2 = sin(v * 3.7f - tt * 0.17f) * 1.6f;
            for (int x = 0; x < W; x++, i++) {
                final float u = x / (float) (W - 1) + pan * 0.7f + tx * 0.18f;
                final float a1 = sin(u * 9.4f + tt * 0.30f + s1);
                final float a2 = sin(u * 16f - tt * 0.22f + s2);
                final float a3 = sin((u + v * 0.45f) * 6f + tt * 0.13f);
                float w1 = (a1 * 0.6f + a3 * 0.4f) * 0.5f + 0.5f;
                w1 = w1 * w1 * (0.30f + 0.70f * mask) * 1.05f;
                float w2 = a2 * 0.5f + 0.5f;
                w2 = w2 * w2 * w2 * (0.20f + 0.80f * mask) * 0.85f;
                float w3 = (a1 * a2) * 0.5f + 0.5f;
                w3 = w3 * w3 * w3 * w3 * 0.55f * (0.4f + 0.6f * mask);
                float r = bgr + (ar - bgr) * w1;  float g = bgg + (ag - bgg) * w1;  float b = bgb + (ab - bgb) * w1;
                r += (cr - r) * w2; g += (cg - g) * w2; b += (cb - b) * w2;
                r += (dr - r) * w3; g += (dg - g) * w3; b += (db - b) * w3;
                final float l = 0.30f * r + 0.59f * g + 0.11f * b;      // saturation boost: the glass and the sky look richer
                r = l + (r - l) * 1.38f; g = l + (g - l) * 1.38f; b = l + (b - l) * 1.38f;
                final int ri = r < 0 ? 0 : r > 255 ? 255 : (int) r, gi = g < 0 ? 0 : g > 255 ? 255 : (int) g, bi = b < 0 ? 0 : b > 255 ? 255 : (int) b;
                px[i] = 0xFF000000 | (ri << 16) | (gi << 8) | bi;
            }
        }
    }
}
