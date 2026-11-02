package com.scratch.iosclock;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Vibrator;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Full-screen ring: shows over the lock screen, plays the alarm sound with vibration; snooze or stop. */
public class RingActivity extends Activity {
    private MediaPlayer player;
    private Vibrator vib;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private boolean stopped;
    private String label;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        Window w = getWindow();
        w.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        float d = getResources().getDisplayMetrics().density;
        label = getIntent().getStringExtra("label");
        boolean night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        int text = night ? Color.WHITE : 0xFF14123A;

        FrameLayout root = new FrameLayout(this);
        View sc = new View(this);
        sc.setBackgroundColor(night ? 0x8014123A : 0x66F6F5FF);
        root.addView(sc, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL);
        col.setPadding((int) (24 * d), (int) (80 * d), (int) (24 * d), (int) (48 * d));

        TextView time = new TextView(this);
        time.setText(new SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date()));
        time.setTextColor(text);
        time.setTextSize(TypedValue.COMPLEX_UNIT_SP, 84);
        time.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        col.addView(time);
        TextView lab = new TextView(this);
        lab.setText(label);
        lab.setTextColor(night ? 0xB3FFFFFF : 0x9914123A);
        lab.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        lab.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        col.addView(lab);
        col.addView(new View(this), new LinearLayout.LayoutParams(1, 0, 1f));

        TextView snooze = button("Posponer 10 min", night ? 0x33FFFFFF : 0xB3FFFFFF, text, d);
        snooze.setOnClickListener(v -> { Alarms.scheduleSnooze(this, label, 10); stop(); });
        col.addView(snooze, new LinearLayout.LayoutParams(-1, (int) (56 * d)));
        TextView off = button("Detener", night ? 0xFF4F6BFF : 0xFF3B6BEA, Color.WHITE, d);
        off.setOnClickListener(v -> stop());
        LinearLayout.LayoutParams op = new LinearLayout.LayoutParams(-1, (int) (56 * d));
        op.topMargin = (int) (12 * d);
        col.addView(off, op);
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);

        start();
        ui.postDelayed(this::stop, 5 * 60 * 1000L);           // give up after five minutes
    }

    private TextView button(String s, int fill, int color, float d) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        t.setGravity(Gravity.CENTER);
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(28 * d);
        t.setBackground(g);
        return t;
    }

    private void start() {
        try {
            Uri u = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM);
            if (u == null) u = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
            if (u == null) u = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            player = new MediaPlayer();
            player.setAudioStreamType(AudioManager.STREAM_ALARM);
            player.setDataSource(this, u);
            player.setLooping(true);
            player.prepare();
            player.start();
        } catch (Exception e) { player = null; }
        vib = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        if (vib != null) vib.vibrate(new long[]{0, 600, 500}, 0);
    }

    private void stop() {
        if (stopped) return;
        stopped = true;
        if (player != null) { try { player.stop(); } catch (Exception ignored) { } player.release(); player = null; }
        if (vib != null) vib.cancel();
        finish();
    }

    @Override protected void onDestroy() { stop(); super.onDestroy(); }
    @Override public void onBackPressed() { /* must be stopped with the buttons */ }
}
