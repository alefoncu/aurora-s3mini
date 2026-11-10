package com.scratch.ios7launcher;

import android.app.WallpaperManager;
import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.Drawable;
import android.view.View;

import java.util.ArrayList;
import java.util.List;

/**
 * Frosted glass: draws the part of a pre-blurred copy of the wallpaper that sits right under the view,
 * then a tint, a top highlight and a hairline. The wallpaper is blurred once at 1/6 scale (box blur),
 * so per frame it is only one bitmap blit: cheap enough for a 1 GHz Cortex-A9.
 */
final class Glass extends Drawable {
    private static final int SCALE = 6;
    private static Bitmap blur;
    private static int wallW, wallH;       // wallpaper size in px, as drawn at screen height
    private static int screenW, screenH;
    private static float offset = 0.5f;    // wallpaper x offset 0..1 (parallax)
    private static final List<java.lang.ref.WeakReference<Glass>> live = new ArrayList<>();

    private final View owner;
    private final float radius;
    private final float[] radii;
    private final int tint, stroke;
    private final float hair;
    boolean dark;   // white text on top: darken the glass when the wallpaper under it is bright
    private final Paint veil = new Paint();
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Path clip = new Path();
    private final int[] loc = new int[2];
    private final RectF rf = new RectF(), in = new RectF();
    private final Rect src = new Rect();
    private final Paint f = new Paint(Paint.ANTI_ALIAS_FLAG), s = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path sp = new Path();
    private LinearGradient hl;

    @Override protected void onBoundsChange(Rect b) {
        rf.set(b);
        clip.rewind();
        if (radii != null) clip.addRoundRect(rf, radii, Path.Direction.CW); else clip.addRoundRect(rf, radius, radius, Path.Direction.CW);
        in.set(rf); in.inset(hair / 2, hair / 2);
        sp.rewind();
        if (radii != null) sp.addRoundRect(in, radii, Path.Direction.CW); else sp.addRoundRect(in, radius, radius, Path.Direction.CW);
        hl = (radius <= 0 && radii == null) ? null : new LinearGradient(0, b.top, 0, b.top + b.height() * 0.55f, 0x4AFFFFFF, 0x00FFFFFF, Shader.TileMode.CLAMP);
        s.setStyle(Paint.Style.STROKE); s.setStrokeWidth(hair); s.setColor(stroke);
    }

    Glass(View owner, float radius, float[] radii, int tint, int stroke, float hair) {
        this.owner = owner; this.radius = radius; this.radii = radii; this.tint = tint; this.stroke = stroke; this.hair = hair;
        ColorMatrix cm = sat(1.4f); cm.postConcat(new ColorMatrix(new float[]{1.18f,0,0,0,10, 0,1.18f,0,0,10, 0,0,1.18f,0,10, 0,0,0,1,0}));
        p.setColorFilter(new ColorMatrixColorFilter(cm));
        live.add(new java.lang.ref.WeakReference<>(this));
    }

    private static ColorMatrix sat(float s) { ColorMatrix m = new ColorMatrix(); m.setSaturation(s); return m; }

    static void release() { live.clear(); }

    /** Rebuild the blurred wallpaper (call on start and whenever the wallpaper changes). */
    static void rebuild(final Context ctx, final int screenWpx, final int screenHpx) {
        screenW = screenWpx; screenH = screenHpx;
        final android.os.Handler ui = new android.os.Handler(android.os.Looper.getMainLooper());
        new Thread(new Runnable() { public void run() {
            final Object[] r = build(ctx, screenWpx, screenHpx);
            if (r != null) ui.post(new Runnable() { public void run() {
                blur = (Bitmap) r[0]; wallW = (Integer) r[1]; wallH = (Integer) r[2]; screenW = screenWpx;
                invalidateAll();
            } });
        } }).start();
    }

    private static Object[] build(Context ctx, int screenWpx, int screenHpx) {
        try {
            WallpaperManager wm = WallpaperManager.getInstance(ctx);
            Drawable dr = wm.getDrawable();
            if (dr == null) return null;
            int iw = Math.max(1, dr.getIntrinsicWidth()), ih = Math.max(1, dr.getIntrinsicHeight());
            float sc = screenHpx / (float) ih;                 // wallpaper is scaled to the screen height
            int ww = Math.round(iw * sc), wh = screenHpx;
            int bw = Math.max(8, ww / SCALE), bh = Math.max(8, wh / SCALE);
            Bitmap b = Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888);
            Canvas c = new Canvas(b);
            dr.setBounds(0, 0, bw, bh);
            dr.draw(c);
            boxBlur(b, 5, 3);
            return new Object[]{b, ww, wh};
        } catch (Throwable t) { return null; /* no wallpaper: the tint alone is drawn */ }
    }

    static void setOffset(float o) {
        o = Math.max(0f, Math.min(1f, o));
        if (Math.abs(o - offset) < 0.0005f) return;
        offset = o;
        invalidateAll();
    }

    static float offset() { return offset; }

    static void invalidateAll() {
        for (int i = live.size() - 1; i >= 0; i--) {
            Glass gl = live.get(i).get();
            if (gl == null) { live.remove(i); continue; }
            if (gl.owner.isShown()) gl.owner.invalidate();
        }
    }

    private static void boxBlur(Bitmap b, int r, int passes) {
        int w = b.getWidth(), h = b.getHeight();
        int[] a = new int[w * h], t = new int[w * h];
        b.getPixels(a, 0, w, 0, 0, w, h);
        for (int k = 0; k < passes; k++) {
            blurLine(a, t, w, h, r, true);
            blurLine(t, a, w, h, r, false);
        }
        b.setPixels(a, 0, w, 0, 0, w, h);
    }

    private static void blurLine(int[] src, int[] dst, int w, int h, int r, boolean horiz) {
        int len = horiz ? w : h, lines = horiz ? h : w, div = 2 * r + 1;
        for (int l = 0; l < lines; l++) {
            int sa = 0, sr = 0, sg = 0, sb = 0;
            for (int i = -r; i <= r; i++) {
                int px = src[idx(l, clamp(i, len), w, horiz)];
                sa += px >>> 24; sr += (px >> 16) & 255; sg += (px >> 8) & 255; sb += px & 255;
            }
            for (int i = 0; i < len; i++) {
                dst[idx(l, i, w, horiz)] = ((sa / div) << 24) | ((sr / div) << 16) | ((sg / div) << 8) | (sb / div);
                int add = src[idx(l, clamp(i + r + 1, len), w, horiz)], rem = src[idx(l, clamp(i - r, len), w, horiz)];
                sa += (add >>> 24) - (rem >>> 24);
                sr += ((add >> 16) & 255) - ((rem >> 16) & 255);
                sg += ((add >> 8) & 255) - ((rem >> 8) & 255);
                sb += (add & 255) - (rem & 255);
            }
        }
    }

    private static int idx(int line, int i, int w, boolean horiz) { return horiz ? line * w + i : i * w + line; }
    private static int clamp(int i, int len) { return i < 0 ? 0 : (i >= len ? len - 1 : i); }

    @Override public void draw(Canvas c) {
        Rect b = getBounds();
        if (b.width() <= 0 || b.height() <= 0) return;
        c.save();
        c.clipPath(clip);
        Bitmap live = AuroraField.front;
        boolean useLive = live != null && android.os.SystemClock.uptimeMillis() - AuroraField.lastFrame < 2000;
        Bitmap srcBmp = useLive ? live : blur;
        if (srcBmp != null) {
            owner.getLocationInWindow(loc);
            float wx = useLive ? 0f : offset * Math.max(0, wallW - screenW);
            final float scx = useLive ? screenW / (float) srcBmp.getWidth() : SCALE, scy = useLive ? screenH / (float) srcBmp.getHeight() : SCALE;
            float sx = (wx + loc[0] + b.left) / scx, sy = (loc[1] + b.top) / scy;
            src.set(Math.round(sx), Math.round(sy), Math.round(sx + b.width() / scx), Math.round(sy + b.height() / scy));
            if (src.right > srcBmp.getWidth()) src.offset(srcBmp.getWidth() - src.right, 0);
            if (src.left < 0) src.offset(-src.left, 0);
            c.drawBitmap(srcBmp, src, b, p);
        }
        f.setShader(null);
        f.setColor(tint);
        c.drawRect(rf, f);
        if (dark && srcBmp != null) {
            int cx = Math.max(0, Math.min(srcBmp.getWidth() - 1, (src.left + src.right) / 2)), cy = Math.max(0, Math.min(srcBmp.getHeight() - 1, (src.top + src.bottom) / 2));
            int px = srcBmp.getPixel(cx, cy);
            float lum = (0.299f * ((px >> 16) & 255) + 0.587f * ((px >> 8) & 255) + 0.114f * (px & 255)) / 255f;
            float a = Math.max(0f, Math.min(0.62f, (lum - 0.38f) * 1.9f));
            if (a > 0.01f) { veil.setColor(Color.argb((int) (a * 255), 0x14, 0x12, 0x38)); c.drawRect(rf, veil); }
        }
        if (hl != null) { f.setShader(hl); c.drawRect(rf, f); }
        c.restore();
        c.drawPath(sp, s);
    }

    @Override public void setAlpha(int a) { }
    @Override public void setColorFilter(ColorFilter cf) { }
    @Override public int getOpacity() { return PixelFormat.TRANSLUCENT; }
}
