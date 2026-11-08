package com.scratch.iosrecorder;

import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaMetadataRetriever;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.SystemClock;
import android.text.InputType;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;
import java.io.File;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Aurora: glass controls over the wallpaper; no generated resource classes. */
public class RecorderActivity extends Activity {
    private float d;
    private boolean night, recording, resumed, loading;
    private int text, accent, glass, stroke, loadVersion;
    private static final int RED = 0xFFFF3B30;
    private final Handler handler = new Handler();
    private final ExecutorService metadata = Executors.newSingleThreadExecutor();
    private final File directory = new File(Environment.getExternalStorageDirectory(), "Recordings");
    private MediaRecorder recorder;
    private MediaPlayer player;
    private File recordingFile, opened;
    private long started;
    private LinearLayout rows;
    private TextView timer, recordButton, status, playButton, playTime;
    private SeekBar progress;
    private View halo;
    private ObjectAnimator pulse;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this);
        scrim.setBackgroundColor(night ? 0x9914123A : 0x66F6F5FF);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding(dp(16), dp(24), dp(16), dp(12));
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));
        TextView title = label("Grabadora", 30, "sans-serif-thin");
        title.setPadding(dp(4), dp(10), 0, dp(2));
        col.addView(title);
        timer = label("00:00", 52, "sans-serif-thin");
        timer.setGravity(Gravity.CENTER);
        col.addView(timer, new LinearLayout.LayoutParams(-1, dp(68)));
        FrameLayout controls = new FrameLayout(this);
        halo = new View(this);
        halo.setBackground(shape(0x30FF3B30, 1000));
        FrameLayout.LayoutParams hp = new FrameLayout.LayoutParams(dp(108), dp(108), Gravity.CENTER);
        controls.addView(halo, hp);
        recordButton = label("●", 54, "sans-serif-light");
        recordButton.setTextColor(RED);
        recordButton.setGravity(Gravity.CENTER);
        recordButton.setBackground(shape(glass, 1000));
        recordButton.setContentDescription("Iniciar grabación");
        spring(recordButton);
        recordButton.setOnClickListener(v -> { if (recording) stopRecording(); else startRecording(); });
        controls.addView(recordButton, new FrameLayout.LayoutParams(dp(90), dp(90), Gravity.CENTER));
        col.addView(controls, new LinearLayout.LayoutParams(-1, dp(116)));
        status = label("Toca para grabar", 14, "sans-serif-light");
        status.setGravity(Gravity.CENTER);
        col.addView(status, new LinearLayout.LayoutParams(-1, dp(28)));
        TextView heading = label("Grabaciones", 20, "sans-serif-light");
        heading.setPadding(dp(4), dp(10), 0, dp(8));
        col.addView(heading);
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        rows = new LinearLayout(this);
        rows.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(rows, new ScrollView.LayoutParams(-1, -2));
        col.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);
    }

    private int dp(float n) { return (int) (n * d + 0.5f); }
    private TextView label(String s, int size, String font) {
        TextView v = new TextView(this);
        v.setText(s); v.setTextColor(text);
        v.setTypeface(Typeface.create(font, Typeface.NORMAL));
        v.setTextSize(TypedValue.COMPLEX_UNIT_SP, size);
        return v;
    }
    private GradientDrawable shape(int fill, int radius) {
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(radius)); g.setColor(fill);
        g.setStroke(Math.max(1, dp(1)), stroke);
        return g;
    }
    private void spring(View v) {
        v.setOnTouchListener((view, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                view.animate().cancel();
                view.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
            } else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) {
                view.animate().scaleX(1f).scaleY(1f).setDuration(320).setInterpolator(new android.view.animation.OvershootInterpolator(3.2f)).start();
            }
            return false;
        });
    }
    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_LONG).show(); }
    private String clock(long ms) {
        long seconds = Math.max(0, ms / 1000);
        return String.format(Locale.getDefault(), "%02d:%02d", seconds / 60, seconds % 60);
    }
    private final Runnable tick = new Runnable() {
        @Override public void run() {
            if (recording) timer.setText(clock(SystemClock.elapsedRealtime() - started));
            if (player != null && !loading && progress != null) {
                try {
                    progress.setProgress(player.getCurrentPosition());
                    playTime.setText(clock(player.getCurrentPosition()) + " / " + clock(player.getDuration()));
                } catch (IllegalStateException ignored) { releasePlayer(); }
            }
            if (resumed) handler.postDelayed(this, 200);
        }
    };

    private void startRecording() {
        releasePlayer();
        opened = null;
        try {
            if (!Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) throw new java.io.IOException();
            if (!directory.isDirectory() && !directory.mkdirs()) throw new java.io.IOException();
            if (directory.getUsableSpace() < 1024 * 1024) { toast("No hay espacio para grabar"); return; }
            String name = "Grabación " + new SimpleDateFormat("yyyy-MM-dd HH.mm", Locale.getDefault()).format(new Date());
            recordingFile = availableFile(name);
            recorder = new MediaRecorder();
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            recorder.setAudioSamplingRate(44100);
            recorder.setAudioEncodingBitRate(96000);
            recorder.setOutputFile(recordingFile.getAbsolutePath());
            recorder.setOnErrorListener((r, what, extra) -> { if (r == recorder) { toast("La grabación se ha interrumpido"); stopRecording(); } });
            recorder.setOnInfoListener((r, what, extra) -> {
                if (r == recorder && (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED || what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED)) stopRecording();
            });
            recorder.prepare(); recorder.start();
            recording = true; started = SystemClock.elapsedRealtime();
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            recordButton.setText("■"); recordButton.setContentDescription("Detener grabación");
            status.setText("Grabando · toca para parar"); timer.setText("00:00");
            pulse = ObjectAnimator.ofFloat(halo, "alpha", 1f, 0.15f);
            pulse.setDuration(800); pulse.setRepeatMode(ValueAnimator.REVERSE); pulse.setRepeatCount(ValueAnimator.INFINITE); pulse.start();
            refresh();
        } catch (Exception e) {
            releaseRecorder();
            discardRecording();
            toast("No se pudo grabar. Comprueba el micrófono y el espacio disponible");
            refresh();
        }
    }
    private File availableFile(String name) {
        File f = new File(directory, name + ".m4a");
        for (int i = 2; f.exists(); i++) f = new File(directory, name + " (" + i + ").m4a");
        return f;
    }
    private void releaseRecorder() {
        if (recorder != null) {
            recorder.setOnErrorListener(null); recorder.setOnInfoListener(null);
            try { recorder.release(); } catch (RuntimeException ignored) { }
            recorder = null;
        }
    }
    private void discardRecording() {
        if (recordingFile != null && recordingFile.exists() && !recordingFile.delete()) toast("No se pudo eliminar el archivo incompleto");
        recordingFile = null;
    }
    private void stopRecording() {
        if (!recording) return;
        recording = false;
        boolean saved = false;
        try { recorder.stop(); saved = recordingFile != null && recordingFile.length() > 0; }
        catch (RuntimeException e) { toast("No se pudo guardar: grabación demasiado corta o sin espacio"); }
        finally { releaseRecorder(); }
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (pulse != null) { pulse.cancel(); pulse = null; }
        halo.setAlpha(1f); recordButton.setText("●"); recordButton.setContentDescription("Iniciar grabación");
        status.setText("Toca para grabar");
        if (saved) { scan(recordingFile); recordingFile = null; toast("Grabación guardada"); }
        else discardRecording();
        refresh();
    }
    private void scan(File f) {
        MediaScannerConnection.scanFile(getApplicationContext(), new String[]{f.getAbsolutePath()}, new String[]{"audio/mp4"}, null);
    }

    private static class Clip {
        File file; long duration;
        Clip(File f, long t) { file = f; duration = t; }
    }
    private void refresh() {
        final int version = ++loadVersion;
        final File exclude = recordingFile;
        if (metadata.isShutdown()) return;
        metadata.execute(() -> {
            List<Clip> clips = new ArrayList<>();
            boolean failed = false;
            try {
                File[] files = directory.listFiles(f -> f.isFile() && f.getName().toLowerCase(Locale.ROOT).endsWith(".m4a") && !f.equals(exclude));
                if (files != null) {
                    Arrays.sort(files, (a, b) -> Long.compare(b.lastModified(), a.lastModified()));
                    for (File f : files) {
                        if (Thread.currentThread().isInterrupted()) return;
                        long duration = -1;
                        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                        try {
                            retriever.setDataSource(f.getAbsolutePath());
                            String value = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                            if (value != null) duration = Long.parseLong(value);
                        } catch (RuntimeException ignored) { }
                        finally { try { retriever.release(); } catch (RuntimeException ignored) { } }
                        clips.add(new Clip(f, duration));
                    }
                } else if (directory.exists()) failed = true;
            } catch (SecurityException e) { failed = true; }
            final boolean readFailed = failed;
            handler.post(() -> {
                if (version != loadVersion || isFinishing() || isDestroyed()) return;
                render(clips, readFailed);
            });
        });
    }
    private void render(List<Clip> clips, boolean failed) {
        rows.removeAllViews(); progress = null; playButton = null; playTime = null;
        if (clips.isEmpty()) {
            TextView empty = label(failed ? "No se pudo leer la carpeta Recordings" : "Tus grabaciones aparecerán aquí", 16, "sans-serif-light");
            empty.setGravity(Gravity.CENTER); empty.setPadding(0, dp(24), 0, dp(24)); rows.addView(empty);
        }
        for (Clip clip : clips) {
            File f = clip.file;
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.VERTICAL); row.setPadding(dp(14), dp(12), dp(14), dp(12));
            row.setBackground(shape(glass, 18));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2); lp.bottomMargin = dp(8);
            rows.addView(row, lp);
            TextView name = label(f.getName().substring(0, f.getName().length()-4), 17, "sans-serif-light");
            row.addView(name);
            TextView info = label((clip.duration < 0 ? "Duración desconocida" : clock(clip.duration)) + "  ·  " + new SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(new Date(f.lastModified())), 12, "sans-serif-light");
            info.setPadding(0, dp(5), 0, 0); row.addView(info);
            row.setOnClickListener(v -> open(f));
            row.setOnLongClickListener(v -> { actions(f); return true; }); spring(row);
            if (f.equals(opened)) {
                LinearLayout inline = new LinearLayout(this); inline.setGravity(Gravity.CENTER_VERTICAL);
                playButton = label(player != null && !loading && player.isPlaying() ? "Ⅱ" : "▶", 25, "sans-serif-light");
                playButton.setTextColor(accent); playButton.setGravity(Gravity.CENTER);
                playButton.setContentDescription("Reproducir o pausar"); spring(playButton);
                playButton.setOnClickListener(v -> toggle(f));
                inline.addView(playButton, new LinearLayout.LayoutParams(dp(48), dp(48)));
                progress = new SeekBar(this); progress.setMax((int)Math.max(1, clip.duration));
                progress.setProgressTintList(android.content.res.ColorStateList.valueOf(accent));
                progress.setThumbTintList(android.content.res.ColorStateList.valueOf(accent));
                progress.setEnabled(player != null && !loading);
                progress.setContentDescription("Posición de reproducción");
                progress.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
                    public void onStartTrackingTouch(SeekBar s) { }
                    public void onStopTrackingTouch(SeekBar s) { }
                    public void onProgressChanged(SeekBar s, int value, boolean user) {
                        if (user && player != null && !loading) try { player.seekTo(value); } catch (RuntimeException e) { playbackError(); }
                    }
                });
                inline.addView(progress, new LinearLayout.LayoutParams(0, dp(48), 1)); row.addView(inline);
                playTime = label(loading ? "Cargando…" : "00:00 / " + clock(clip.duration), 12, "sans-serif-light"); row.addView(playTime);
            }
        }
    }
    private void open(File f) {
        if (recording) { toast("Detén la grabación para escuchar"); return; }
        if (f.equals(opened)) { toggle(f); return; }
        releasePlayer(); opened = f; preparePlayer(f); refresh();
    }
    private void preparePlayer(File f) {
        try {
            final MediaPlayer p = new MediaPlayer(); player = p; loading = true;
            p.setDataSource(f.getAbsolutePath());
            p.setOnPreparedListener(mp -> {
                if (player != mp || !resumed) return;
                loading = false;
                try {
                    mp.start();
                    if (progress != null) { progress.setMax(mp.getDuration()); progress.setEnabled(true); }
                    if (playButton != null) playButton.setText("Ⅱ");
                } catch (RuntimeException e) { playbackError(); }
            });
            p.setOnCompletionListener(mp -> {
                if (player != mp) return;
                if (playButton != null) playButton.setText("▶");
                try { mp.seekTo(0); } catch (RuntimeException e) { playbackError(); }
            });
            p.setOnErrorListener((mp, what, extra) -> { if (player == mp) playbackError(); return true; });
            p.prepareAsync();
        } catch (Exception e) { playbackError(); }
    }
    private void toggle(File f) {
        if (recording || loading) return;
        if (player == null) { preparePlayer(f); return; }
        try {
            if (player.isPlaying()) { player.pause(); if (playButton != null) playButton.setText("▶"); }
            else { player.start(); if (playButton != null) playButton.setText("Ⅱ"); }
        } catch (RuntimeException e) { playbackError(); }
    }
    private void playbackError() { releasePlayer(); toast("No se pudo reproducir esta grabación"); }
    private void releasePlayer() {
        MediaPlayer p = player; player = null; loading = false;
        if (p != null) {
            p.setOnPreparedListener(null); p.setOnCompletionListener(null); p.setOnErrorListener(null);
            try { p.release(); } catch (RuntimeException ignored) { }
        }
        if (playButton != null) playButton.setText("▶");
        if (progress != null) progress.setEnabled(false);
    }
    private void actions(File f) {
        new AlertDialog.Builder(this).setTitle(f.getName()).setItems(new String[]{"Renombrar", "Compartir", "Borrar"}, (dialog, item) -> {
            if (item == 0) rename(f);
            else if (item == 1) {
                try { startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("audio/mp4").putExtra(Intent.EXTRA_STREAM, Uri.fromFile(f)), "Compartir grabación")); }
                catch (RuntimeException e) { toast("No hay una aplicación para compartir audio"); }
            } else new AlertDialog.Builder(this).setTitle("¿Borrar grabación?").setMessage(f.getName()).setNegativeButton("Cancelar", null).setPositiveButton("Borrar", (a, b) -> {
                if (f.equals(opened)) { releasePlayer(); opened = null; }
                try { if (!f.delete()) toast("No se pudo borrar la grabación"); else scan(f); }
                catch (SecurityException e) { toast("No se pudo borrar la grabación"); }
                refresh();
            }).show();
        }).show();
    }
    private void rename(File f) {
        EditText input = new EditText(this);
        input.setTextColor(0xFF14123A); input.setHintTextColor(0xFF666666);
        input.setSingleLine(true); input.setInputType(InputType.TYPE_CLASS_TEXT);
        input.setText(f.getName().substring(0, f.getName().length()-4)); input.selectAll();
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle("Renombrar grabación").setView(input).setNegativeButton("Cancelar", null).setPositiveButton("Guardar", null).create();
        dialog.setOnShowListener(v -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(button -> {
            String name = input.getText().toString().trim();
            if (name.isEmpty() || name.equals(".") || name.equals("..") || name.length() > 100 || name.matches(".*[\\\\/\\p{Cntrl}].*")) { input.setError("Introduce un nombre válido (máximo 100 caracteres)"); return; }
            File dest = new File(directory, name + ".m4a");
            if (dest.equals(f)) { dialog.dismiss(); return; }
            if (dest.exists()) { input.setError("Ya existe una grabación con ese nombre"); return; }
            if (f.equals(opened)) { releasePlayer(); opened = null; }
            long date = f.lastModified();
            try {
                if (!f.renameTo(dest)) { toast("No se pudo renombrar"); return; }
                dest.setLastModified(date); scan(f); scan(dest); dialog.dismiss(); refresh();
            } catch (SecurityException e) { toast("No se pudo renombrar"); }
        })); dialog.show();
    }
    @Override protected void onResume() { super.onResume(); resumed = true; handler.removeCallbacks(tick); handler.post(tick); refresh(); }
    @Override protected void onPause() {
        resumed = false; handler.removeCallbacks(tick); stopRecording(); releaseRecorder(); releasePlayer(); super.onPause();
    }
    @Override protected void onDestroy() {
        stopRecording(); releaseRecorder(); releasePlayer(); ++loadVersion;
        metadata.shutdownNow(); handler.removeCallbacksAndMessages(null);
        if (pulse != null) pulse.cancel();
        super.onDestroy();
    }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }
    /** Aurora exit transition (res/anim/app_exit): soft zoom-out and fade instead of the ROM default. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
