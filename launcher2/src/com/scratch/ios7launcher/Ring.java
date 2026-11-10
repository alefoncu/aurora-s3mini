package com.scratch.ios7launcher;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.*;
import android.view.View;
import android.view.animation.DecelerateInterpolator;

/** Thin progress ring with the percentage in the middle; the sweep animates to each new value. */
final class Ring extends View {
    private final Paint track = new Paint(Paint.ANTI_ALIAS_FLAG), arc = new Paint(Paint.ANTI_ALIAS_FLAG), txt = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF box = new RectF();
    private float shown, target = -1;
    private final int c1, c2;
    private ValueAnimator anim;

    Ring(Context c, float d, int trackColor, int textColor, int c1, int c2) { this(c, d, trackColor, textColor, c1, c2, 5f, 17f); }

    Ring(Context c, float d, int trackColor, int textColor, int c1, int c2, float strokeDp, float textSp) {
        super(c);
        this.c1 = c1; this.c2 = c2;
        track.setStyle(Paint.Style.STROKE); track.setStrokeWidth(strokeDp * d); track.setColor(trackColor);
        arc.setStyle(Paint.Style.STROKE); arc.setStrokeWidth(strokeDp * d); arc.setStrokeCap(Paint.Cap.ROUND);
        txt.setColor(textColor); txt.setTextAlign(Paint.Align.CENTER); txt.setTextSize(textSp * d);
        txt.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
    }

    void set(float frac) {
        frac = Math.max(0f, Math.min(1f, frac));
        if (Math.abs(frac - target) < 0.002f) return;
        target = frac;
        if (anim != null) anim.cancel();
        anim = ValueAnimator.ofFloat(shown, frac);
        anim.setDuration(700);
        anim.setInterpolator(new DecelerateInterpolator(2f));
        anim.addUpdateListener(a -> { shown = (Float) a.getAnimatedValue(); invalidate(); });
        anim.start();
    }

    @Override protected void onSizeChanged(int w, int h, int ow, int oh) {
        float in = track.getStrokeWidth() / 2f + 1;
        box.set(in, in, w - in, h - in);
        arc.setShader(new SweepGradient(w / 2f, h / 2f, new int[]{c1, c2, c1}, null));
    }

    @Override protected void onDraw(Canvas c) {
        c.drawOval(box, track);
        c.save();
        c.rotate(-90, getWidth() / 2f, getHeight() / 2f);
        if (shown > 0.005f) c.drawArc(box, 0, 360f * shown, false, arc);
        c.restore();
        c.drawText(Math.round(shown * 100) + "%", getWidth() / 2f, getHeight() / 2f + txt.getTextSize() * 0.35f, txt);
    }
}
