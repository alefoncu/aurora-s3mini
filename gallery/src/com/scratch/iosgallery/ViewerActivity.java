package com.scratch.iosgallery;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/** Full-screen viewer: swipe between items, pinch / double-tap zoom, share, delete, video playback. */
public class ViewerActivity extends Activity {
    private float d;
    private List<Media.Item> list;
    private int pos;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private ImageView iv;
    private VideoPane vv;
    private View top, bottom;
    private TextView dateView;
    private float scale = 1f, tx, ty;
    private boolean barsOn = true;
    private int token;
    private GestureDetector gestures;
    private ScaleGestureDetector scaler;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        list = Media.current;
        pos = getIntent().getIntExtra("pos", 0);
        Uri data = getIntent().getData();
        if (data != null) {
            String path = pathOf(data);
            if (path == null) { finish(); return; }
            list = new ArrayList<>();
            boolean video = path.toLowerCase(Locale.US).matches(".*\\.(mp4|3gp|mkv|webm)$");
            list.add(new Media.Item(0, path, video ? Media.VIDEO : Media.IMAGE, new File(path).lastModified()));
            pos = 0;
        }
        if (list == null || list.isEmpty()) { finish(); return; }

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        iv = new ImageView(this);
        iv.setScaleType(ImageView.ScaleType.FIT_CENTER);
        root.addView(iv, new FrameLayout.LayoutParams(-1, -1));
        vv = new VideoPane(this);
        FrameLayout.LayoutParams vlp = new FrameLayout.LayoutParams(-1, -1, Gravity.CENTER);
        vlp.bottomMargin = (int) (64 * d);   // above the action bar
        root.addView(vv, vlp);

        top = bar(true);
        bottom = bar(false);
        root.addView(top, new FrameLayout.LayoutParams(-1, (int) (56 * d), Gravity.TOP));
        root.addView(bottom, new FrameLayout.LayoutParams(-1, (int) (64 * d), Gravity.BOTTOM));
        setContentView(root);

        gestures = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override public boolean onSingleTapConfirmed(MotionEvent e) { toggleBars(); return true; }
            @Override public boolean onDoubleTap(MotionEvent e) { setZoom(scale > 1.01f ? 1f : 2.5f); return true; }
            @Override public boolean onScroll(MotionEvent a, MotionEvent c, float dx, float dy) {
                if (scale > 1.01f && !scaler.isInProgress()) { tx -= dx; ty -= dy; clampAndApply(); return true; }
                return false;
            }
            @Override public boolean onFling(MotionEvent a, MotionEvent c, float vx, float vy) {
                if (scale <= 1.01f && Math.abs(vx) > 600 && Math.abs(vx) > Math.abs(vy) * 1.5f) { go(vx < 0 ? 1 : -1); return true; }
                return false;
            }
        });
        scaler = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override public boolean onScale(ScaleGestureDetector s) { setZoomKeep(scale * s.getScaleFactor()); return true; }
        });
        root.setOnTouchListener((v, e) -> {
            if (list.get(pos).type == Media.VIDEO) return gestures.onTouchEvent(e);
            scaler.onTouchEvent(e);
            gestures.onTouchEvent(e);
            return true;
        });
        show();
    }

    private String pathOf(Uri u) {
        if ("file".equals(u.getScheme())) return u.getPath();
        Cursor c = null;
        try {
            c = getContentResolver().query(u, new String[]{MediaStore.MediaColumns.DATA}, null, null, null);
            if (c != null && c.moveToFirst()) return c.getString(0);
        } catch (Exception ignored) { } finally { if (c != null) c.close(); }
        return null;
    }

    private View bar(boolean isTop) {
        LinearLayout bar = new LinearLayout(this);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setBackgroundColor(0x99000000);
        if (isTop) {
            bar.setPadding((int) (4 * d), (int) (24 * d), (int) (16 * d), 0);
            bar.addView(icon("back", () -> finish()), new LinearLayout.LayoutParams((int) (48 * d), (int) (48 * d)));
            dateView = new TextView(this);
            dateView.setTextColor(Color.WHITE);
            dateView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
            dateView.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            bar.addView(dateView);
        } else {
            bar.setGravity(Gravity.CENTER);
            bar.addView(icon("share", this::share), new LinearLayout.LayoutParams((int) (64 * d), (int) (56 * d)));
            View gap = new View(this);
            bar.addView(gap, new LinearLayout.LayoutParams((int) (80 * d), 1));
            bar.addView(icon("trash", this::confirmDelete), new LinearLayout.LayoutParams((int) (64 * d), (int) (56 * d)));
        }
        return bar;
    }

    private View icon(final String kind, final Runnable action) {
        View v = new View(this) {
            @Override protected void onDraw(Canvas cv) {
                float s = 26 * d;
                cv.save();
                cv.translate((getWidth() - s) / 2f, (getHeight() - s) / 2f);
                Icons.draw(cv, kind, s, Color.WHITE, 2f);
                cv.restore();
            }
        };
        v.setOnClickListener(x -> action.run());
        return v;
    }

    private void toggleBars() {
        barsOn = !barsOn;
        float a = barsOn ? 1f : 0f;
        top.animate().alpha(a).setDuration(160).start();
        bottom.animate().alpha(a).setDuration(160).start();
        top.setEnabled(barsOn);
        bottom.setEnabled(barsOn);
        vv.setControlsVisible(barsOn);
    }

    // ---- showing ---------------------------------------------------------------------

    private void show() {
        final Media.Item it = list.get(pos);
        dateView.setText(new SimpleDateFormat("d MMM yyyy · HH:mm", Locale.getDefault()).format(new Date(it.date)));
        scale = 1f; tx = ty = 0; apply();
        final int my = ++token;
        if (it.type == Media.VIDEO) {
            iv.setImageBitmap(null);
            iv.setVisibility(View.GONE);
            vv.open(it.path);
            return;
        }
        vv.close();
        iv.setVisibility(View.VISIBLE);
        new Thread(() -> {
            final Bitmap bm = Media.decode(it.path, 1100, false);
            ui.post(() -> {
                if (my != token || bm == null) return;
                iv.setImageBitmap(bm);
                iv.setAlpha(0f);
                iv.animate().alpha(1f).setDuration(160).start();
            });
        }).start();
    }

    private void go(int delta) {
        int n = pos + delta;
        if (n < 0 || n >= list.size()) return;
        pos = n;
        show();
    }

    // ---- zoom -------------------------------------------------------------------------

    private void setZoom(float s) { scale = Math.max(1f, Math.min(4f, s)); if (scale <= 1.01f) tx = ty = 0; clampAndApply(); }
    private void setZoomKeep(float s) { setZoom(s); }

    private void clampAndApply() {
        float maxX = iv.getWidth() * (scale - 1f) / 2f, maxY = iv.getHeight() * (scale - 1f) / 2f;
        tx = Math.max(-maxX, Math.min(maxX, tx));
        ty = Math.max(-maxY, Math.min(maxY, ty));
        apply();
    }

    private void apply() {
        iv.setScaleX(scale); iv.setScaleY(scale);
        iv.setTranslationX(tx); iv.setTranslationY(ty);
    }

    // ---- actions ------------------------------------------------------------------------

    private void share() {
        Media.Item it = list.get(pos);
        Intent s = new Intent(Intent.ACTION_SEND);
        s.setType(it.type == Media.VIDEO ? "video/*" : "image/*");
        s.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(new File(it.path)));
        startActivity(Intent.createChooser(s, "Compartir"));
    }

    private void confirmDelete() {
        final Media.Item it = list.get(pos);
        new AlertDialog.Builder(this, AlertDialog.THEME_DEVICE_DEFAULT_DARK)
                .setMessage(it.type == Media.VIDEO ? "¿Eliminar este vídeo?" : "¿Eliminar esta foto?")
                .setNegativeButton("Cancelar", null)
                .setPositiveButton("Eliminar", (dlg, w) -> delete(it))
                .show();
    }

    private void delete(final Media.Item it) {
        vv.close();   // player released off the UI thread; unlinking does not wait for it
        deleteNow(it);
    }

    private void deleteNow(Media.Item it) {
        new File(it.path).delete();
        try {
            getContentResolver().delete(MediaStore.Files.getContentUri("external"), MediaStore.Files.FileColumns._ID + "=?", new String[]{String.valueOf(it.id)});
        } catch (Exception ignored) { }
        List<Media.Item> copy = new ArrayList<>(list);
        copy.remove(it);
        list = copy;
        Media.current = copy;
        if (list.isEmpty()) { finish(); return; }
        if (pos >= list.size()) pos = list.size() - 1;
        show();
    }

    @Override
    protected void onPause() { super.onPause(); if (vv != null) vv.pause(); }

    @Override
    protected void onRestart() {
        super.onRestart();
        if (list != null && !list.isEmpty()) show();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (vv != null) vv.close();
    }

    /** Aurora exit transition (res/anim/app_exit): soft zoom-out and fade instead of the ROM default. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
