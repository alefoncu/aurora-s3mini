package com.scratch.iosgallery;

import android.content.Context;
import android.graphics.*;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;
import android.view.*;
import android.widget.FrameLayout;

import java.util.Locale;

/**
 * Video playback for the viewer: own MediaPlayer on a TextureView with thin Aurora controls.
 *
 * Why not VideoView: on this device releasing a player that still feeds a live surface can deadlock
 * inside mediaserver (OMX.ST.VFM.H264Dec) and VideoView does that on the UI thread, which ends in an
 * ANR. Here a MediaPlayer is only ever released from a worker thread; if that call never returns the
 * player is simply abandoned (the next one gets the software decoder) and the UI never notices.
 */
public class VideoPane extends FrameLayout implements TextureView.SurfaceTextureListener {
    private final float d;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final TextureView tv;
    private final Controls controls;
    private SurfaceTexture st;
    private Surface surface;
    private MediaPlayer mp;
    private String path;
    private boolean prepared, finished;
    private int vw, vh, lastPos;

    public VideoPane(Context c) {
        super(c);
        d = c.getResources().getDisplayMetrics().density;
        tv = new TextureView(c);
        tv.setSurfaceTextureListener(this);
        addView(tv, new LayoutParams(-1, -1, Gravity.CENTER));
        controls = new Controls(c);
        addView(controls, new LayoutParams(-1, (int) (150 * d), Gravity.BOTTOM));
        setVisibility(GONE);
    }

    // ---- public API (UI thread) ----------------------------------------------------------

    public void open(String p) {
        release();
        path = p;
        finished = false;
        lastPos = 0;
        setVisibility(VISIBLE);
        if (st != null) start();
    }

    /** Stops and hides; the actual release happens off the UI thread. */
    public void close() {
        release();
        path = null;
        setVisibility(GONE);
    }

    public void pause() {
        if (mp != null && prepared && mp.isPlaying()) mp.pause();
        controls.invalidate();
    }

    public void setControlsVisible(boolean on) {
        controls.animate().alpha(on ? 1f : 0f).setDuration(160).start();
        controls.setEnabled(on);
    }

    // ---- player --------------------------------------------------------------------------

    private void start() {
        if (path == null || st == null) return;
        final MediaPlayer m = new MediaPlayer();
        mp = m;
        prepared = false;
        try {
            m.setDataSource(path);
            surface = new Surface(st);
            m.setSurface(surface);
            m.setOnVideoSizeChangedListener((p, w, h) -> { if (mp == m) fit(w, h); });
            m.setOnPreparedListener(p -> {
                if (mp != m) return;
                prepared = true;
                fit(p.getVideoWidth(), p.getVideoHeight());
                p.start();
                tick();
            });
            m.setOnCompletionListener(p -> { if (mp == m) controls.invalidate(); });
            m.setOnErrorListener((p, what, extra) -> { if (mp == m) { finished = true; controls.invalidate(); } return true; });
            m.prepareAsync();
        } catch (Exception e) {
            finished = true;
            controls.invalidate();
        }
    }

    private void release() {
        final MediaPlayer m = mp;
        final Surface s = surface;
        mp = null;
        surface = null;
        prepared = false;
        if (m == null) return;
        new Thread(() -> {
            try { m.release(); } catch (Exception ignored) { }
            if (s != null) s.release();
        }, "video-release").start();
    }

    private void fit(int w, int h) {
        if (w <= 0 || h <= 0) return;
        vw = w; vh = h;
        int pw = getWidth(), ph = getHeight();
        if (pw == 0 || ph == 0) return;
        float k = Math.min(pw / (float) w, ph / (float) h);
        LayoutParams lp = new LayoutParams((int) (w * k), (int) (h * k), Gravity.CENTER);
        tv.setLayoutParams(lp);
    }

    @Override protected void onSizeChanged(int w, int h, int ow, int oh) { super.onSizeChanged(w, h, ow, oh); fit(vw, vh); }

    private void tick() {
        controls.invalidate();
        ui.removeCallbacks(ticker);
        if (mp != null) ui.postDelayed(ticker, 250);
    }

    private final Runnable ticker = this::tick;

    private void toggle() {
        if (mp == null || !prepared) { if (path != null) { release(); finished = false; start(); } return; }
        if (mp.isPlaying()) mp.pause();
        else {
            int dur = mp.getDuration();
            if (dur > 0 && controls.pos() >= dur - 400) { mp.seekTo(0); lastPos = 0; }   // at the end: play again from the start
            mp.start();
        }
        tick();
    }

    // ---- surface -------------------------------------------------------------------------

    @Override public void onSurfaceTextureAvailable(SurfaceTexture s, int w, int h) { st = s; if (path != null && mp == null) start(); }
    @Override public void onSurfaceTextureSizeChanged(SurfaceTexture s, int w, int h) { }
    @Override public boolean onSurfaceTextureDestroyed(SurfaceTexture s) { release(); st = null; return true; }
    @Override public void onSurfaceTextureUpdated(SurfaceTexture s) { }

    @Override protected void onDetachedFromWindow() { super.onDetachedFromWindow(); ui.removeCallbacks(ticker); }

    // ---- controls: play/pause glyph, hairline progress, time -----------------------------

    private class Controls extends View {
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Rect r = new Rect();

        Controls(Context c) { super(c); }

        // this ROM reports 0 from getCurrentPosition() while paused: remember the last real value
        int pos() {
            try {
                if (mp == null || !prepared) return 0;
                int q = mp.getCurrentPosition();
                if (q > 0) lastPos = q;
                else if (!mp.isPlaying()) q = lastPos;
                return q;
            } catch (Exception e) { return lastPos; }
        }
        private int dur() { try { return mp != null && prepared ? mp.getDuration() : 0; } catch (Exception e) { return 0; } }

        private String time(int ms) {
            int s = Math.max(0, ms / 1000);
            return String.format(Locale.US, "%d:%02d", s / 60, s % 60);
        }

        @Override protected void onDraw(Canvas cv) {
            int w = getWidth(), h = getHeight();
            boolean playing = mp != null && prepared && mp.isPlaying();
            // glyph
            float cx = w / 2f, cy = h - 96 * d, rad = 22 * d;
            p.setStyle(Paint.Style.FILL);
            p.setColor(0x33FFFFFF);
            cv.drawCircle(cx, cy, rad, p);
            p.setColor(Color.WHITE);
            if (playing) {
                cv.drawRoundRect(new RectF(cx - 7 * d, cy - 8 * d, cx - 2.5f * d, cy + 8 * d), d, d, p);
                cv.drawRoundRect(new RectF(cx + 2.5f * d, cy - 8 * d, cx + 7 * d, cy + 8 * d), d, d, p);
            } else {
                Path t = new Path();
                t.moveTo(cx - 5 * d, cy - 9 * d); t.lineTo(cx + 9 * d, cy); t.lineTo(cx - 5 * d, cy + 9 * d); t.close();
                cv.drawPath(t, p);
            }
            // progress
            float x0 = 20 * d, x1 = w - 20 * d, y = h - 52 * d;
            int dur = dur(), pos = pos();
            p.setStrokeCap(Paint.Cap.ROUND);
            p.setStrokeWidth(2.5f * d);
            p.setColor(0x44FFFFFF);
            cv.drawLine(x0, y, x1, y, p);
            if (dur > 0) {
                float fx = x0 + (x1 - x0) * Math.min(1f, pos / (float) dur);
                p.setColor(Color.WHITE);
                cv.drawLine(x0, y, fx, y, p);
                cv.drawCircle(fx, y, 5 * d, p);
            }
            p.setStyle(Paint.Style.FILL);
            p.setTextSize(11 * d);
            p.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            p.setColor(0xCCFFFFFF);
            String l = time(pos), rt = time(dur);
            p.getTextBounds(rt, 0, rt.length(), r);
            cv.drawText(l, x0, y + 20 * d, p);
            cv.drawText(rt, x1 - r.width(), y + 20 * d, p);
        }

        @Override public boolean onTouchEvent(MotionEvent e) {
            if (!isEnabled() || getAlpha() < 0.5f) return false;
            float x = e.getX(), y = e.getY();
            boolean onGlyph = Math.hypot(x - getWidth() / 2f, y - (getHeight() - 96 * d)) < 44 * d;
            boolean onBar = y > getHeight() - 76 * d && y < getHeight() - 28 * d;
            if (!onGlyph && !onBar) return false;
            if (e.getAction() == MotionEvent.ACTION_UP) {
                if (onGlyph) toggle();
                else if (mp != null && prepared && dur() > 0) {
                    float f = Math.max(0f, Math.min(1f, (x - 20 * d) / (getWidth() - 40 * d)));
                    lastPos = (int) (f * dur());
                    mp.seekTo(lastPos);
                    tick();
                }
            }
            return true;
        }
    }
}
