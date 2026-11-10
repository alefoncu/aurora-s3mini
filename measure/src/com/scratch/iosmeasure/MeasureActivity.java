package com.scratch.iosmeasure;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.hardware.*;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;
import java.util.Locale;

/** Wallpaper-backed measuring tools; all geometry is drawn directly in pixels. */
public class MeasureActivity extends Activity implements SensorEventListener {
    private float density;
    private boolean night, resumed, vertical, headingReady, gravityReady, magneticReady;
    private int ink, subtle, glass, stroke, accent, page, audioGeneration;
    private float heading, tiltX, tiltY, roll, maximum;
    private final float[] gravity = new float[3], magnetic = new float[3];
    private final float[] matrix = new float[9], orientation = new float[3];
    private SensorManager sensors;
    private Sensor rotationSensor, accelerationSensor, magneticSensor;
    private final LinearLayout[] pages = new LinearLayout[3];
    private final TextView[] segments = new TextView[3];
    private TextView headingText, cardinalText, compassHint, levelText, levelHint, modeButton;
    private TextView soundText, soundWord, soundHint, maxText;
    private DialView dial;
    private LevelView level;
    private GaugeView gauge;
    private HistoryView history;
    private final Handler main = new Handler(Looper.getMainLooper());
    private Recording recording;
    private boolean permissionPending;
    private static final int GREEN = 0xFF34D399;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        density = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        ink = night ? Color.WHITE : 0xFF14123A;
        subtle = night ? 0xB3FFFFFF : 0x9914123A;
        glass = night ? 0x2EFFFFFF : 0x66FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xB3FFFFFF;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        try { sensors = (SensorManager) getSystemService(SENSOR_SERVICE); } catch (Exception ignored) { }
        rotationSensor = sensor(Sensor.TYPE_ROTATION_VECTOR);
        accelerationSensor = sensor(Sensor.TYPE_ACCELEROMETER);
        magneticSensor = sensor(Sensor.TYPE_MAGNETIC_FIELD);
        if (state != null) { page = Math.max(0, Math.min(2, state.getInt("page"))); vertical = state.getBoolean("vertical"); }
        buildScreen();
    }
    private Sensor sensor(int type) {
        try { return sensors == null ? null : sensors.getDefaultSensor(type); } catch (Exception ignored) { return null; }
    }
    private int dp(float value) { return (int) (value * density + 0.5f); }
    private TextView label(String value, int size, boolean thin) {
        TextView view = new TextView(this); view.setText(value); view.setTextColor(ink);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, size);
        view.setTypeface(Typeface.create(thin ? "sans-serif-thin" : "sans-serif-light", Typeface.NORMAL));
        view.setGravity(Gravity.CENTER); return view;
    }
    private GradientDrawable glass(float radius) {
        GradientDrawable bg = new GradientDrawable(); bg.setColor(glass); bg.setCornerRadius(dp(radius));
        bg.setStroke(Math.max(1, dp(0.5f)), stroke); return bg;
    }
    private void buildScreen() {
        Window window = getWindow(); window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(Color.TRANSPARENT);
        window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this); scrim.setBackgroundColor(night ? 0x6614123A : 0x33F6F5FF);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL);
        int top = getResources().getIdentifier("status_bar_height", "dimen", "android");
        int inset = top == 0 ? dp(24) : getResources().getDimensionPixelSize(top);
        column.setPadding(dp(20), inset + dp(20), dp(20), 0);
        TextView title = label("Medidor", 28, true); title.setPadding(0, 0, 0, dp(18)); column.addView(title);
        LinearLayout selector = new LinearLayout(this); selector.setPadding(dp(4), dp(4), dp(4), dp(4)); selector.setBackground(glass(22));
        String[] names = {"Brújula", "Nivel", "Sonido"};
        for (int i = 0; i < 3; i++) {
            final int index = i; TextView item = label(names[i], 16, false); segments[i] = item;
            item.setOnClickListener(v -> selectPage(index)); selector.addView(item, new LinearLayout.LayoutParams(0, dp(40), 1));
        }
        column.addView(selector, new LinearLayout.LayoutParams(-1, -2));
        FrameLayout content = new FrameLayout(this);
        LinearLayout.LayoutParams contentParams = new LinearLayout.LayoutParams(-1, 0, 1); contentParams.topMargin = dp(16);
        column.addView(content, contentParams);
        for (int i = 0; i < 3; i++) {
            ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true); scroll.setClipToPadding(true);
            scroll.setPadding(0, 0, 0, dp(24));
            LinearLayout body = new LinearLayout(this); body.setOrientation(LinearLayout.VERTICAL); body.setGravity(Gravity.CENTER_HORIZONTAL);
            pages[i] = body; scroll.addView(body, new ScrollView.LayoutParams(-1, -2));
            content.addView(scroll, new FrameLayout.LayoutParams(-1, -1)); scroll.setVisibility(i == page ? View.VISIBLE : View.GONE);
        }
        dial = new DialView(); pages[0].addView(dial, new LinearLayout.LayoutParams(-1, dp(205)));
        headingText = label("—°", 70, true); pages[0].addView(headingText);
        cardinalText = label("Esperando orientación…", 22, false); pages[0].addView(cardinalText);
        compassHint = hint(pages[0], "");
        level = new LevelView(); pages[1].addView(level, new LinearLayout.LayoutParams(-1, dp(205)));
        levelText = label("X —°   Y —°", 30, true); pages[1].addView(levelText);
        modeButton = label("Plano / Vertical", 17, false); modeButton.setBackground(glass(24));
        LinearLayout.LayoutParams pill = new LinearLayout.LayoutParams(dp(210), dp(48)); pill.topMargin = dp(20);
        pages[1].addView(modeButton, pill);
        modeButton.setOnClickListener(v -> { vertical = !vertical; updateLevel(); });
        levelHint = hint(pages[1], ""); updateLevel();
        soundText = label("— dB", 70, true); pages[2].addView(soundText);
        soundWord = label("Esperando sonido…", 21, false); pages[2].addView(soundWord);
        gauge = new GaugeView(); pages[2].addView(gauge, new LinearLayout.LayoutParams(-1, dp(185)));
        soundHint = hint(pages[2], "Nivel aproximado · Sin calibrar");
        soundHint.setOnClickListener(v -> { if (resumed && page == 2 && recording == null) startAudio(); });
        LinearLayout card = new LinearLayout(this); card.setOrientation(LinearLayout.VERTICAL); card.setBackground(glass(24));
        card.setPadding(dp(16), dp(16), dp(16), dp(16));
        TextView caption = label("ÚLTIMOS 30 SEGUNDOS", 12, false); caption.setTextColor(subtle); caption.setLetterSpacing(0.08f); card.addView(caption);
        history = new HistoryView(); card.addView(history, new LinearLayout.LayoutParams(-1, dp(100)));
        maxText = label("Máx — dB", 18, false); card.addView(maxText);
        LinearLayout.LayoutParams cardParams = new LinearLayout.LayoutParams(-1, -2); cardParams.topMargin = dp(12); pages[2].addView(card, cardParams);
        root.addView(column, new FrameLayout.LayoutParams(-1, -1)); setContentView(root); updateSegments();
    }
    private TextView hint(LinearLayout parent, String text) {
        TextView view = label(text, 13, false); view.setTextColor(subtle); view.setPadding(0, dp(12), 0, dp(12)); parent.addView(view); return view;
    }
    private void updateSegments() {
        for (int i = 0; i < 3; i++) { segments[i].setBackground(i == page ? glass(18) : null); segments[i].setSelected(i == page); }
    }
    private void selectPage(int requested) {
        if (requested == page) return;
        stopActive();
        View old = (View) pages[page].getParent(), next = (View) pages[requested].getParent();
        // Cancel any unfinished crossfade before choosing the sole active page.
        for (LinearLayout body : pages) {
            View container = (View) body.getParent(); container.animate().cancel(); container.setVisibility(View.GONE); container.setAlpha(1f);
        }
        page = requested; updateSegments(); old.setVisibility(View.VISIBLE);
        old.animate().alpha(0f).setDuration(150).withEndAction(() -> { old.setVisibility(View.GONE); old.setAlpha(1f); }).start();
        next.setAlpha(0f); next.setVisibility(View.VISIBLE); next.animate().alpha(1f).setDuration(150).start();
        if (resumed) startActive();
    }
    @Override protected void onResume() { super.onResume(); resumed = true; startActive(); }
    @Override protected void onPause() { resumed = false; stopActive(); super.onPause(); }
    @Override protected void onDestroy() { stopActive(); main.removeCallbacksAndMessages(null); super.onDestroy(); }
    @Override protected void onSaveInstanceState(Bundle state) { state.putInt("page", page); state.putBoolean("vertical", vertical); super.onSaveInstanceState(state); }
    private boolean register(Sensor sensor) {
        try { return sensors != null && sensor != null && sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI, main); }
        catch (Exception ignored) { return false; }
    }
    private void startActive() {
        gravityReady = magneticReady = headingReady = false;
        if (page == 0) {
            boolean available = rotationSensor != null && register(rotationSensor);
            if (!available) {
                boolean accelerometer = register(accelerationSensor), magnetometer = register(magneticSensor);
                available = accelerometer && magnetometer;
                if (!available) unregister();
            }
            compassHint.setText(available ? "" : "Este móvil no tiene brújula");
            if (!available) { headingText.setText("—°"); cardinalText.setText("Sin orientación"); }
        } else if (page == 1) {
            boolean available = register(accelerationSensor);
            levelHint.setText(available ? (vertical ? "Modo vertical" : "Modo plano") : "Este móvil no tiene acelerómetro");
        } else startAudio();
    }
    private void unregister() { try { if (sensors != null) sensors.unregisterListener(this); } catch (Exception ignored) { } }
    private void stopActive() { unregister(); stopAudio(); }
    @Override public void onSensorChanged(SensorEvent event) {
        if (!resumed || page == 2 || event == null || event.sensor == null) return;
        try {
            int type = event.sensor.getType();
            if (type == Sensor.TYPE_ACCELEROMETER && event.values.length >= 3) {
                for (int i = 0; i < 3; i++) gravity[i] = gravityReady ? gravity[i] + 0.15f * (event.values[i] - gravity[i]) : event.values[i];
                gravityReady = true;
                if (page == 1) {
                    tiltX = (float) Math.toDegrees(Math.atan2(gravity[0], Math.sqrt(gravity[1] * gravity[1] + gravity[2] * gravity[2])));
                    tiltY = (float) Math.toDegrees(Math.atan2(gravity[1], Math.sqrt(gravity[0] * gravity[0] + gravity[2] * gravity[2])));
                    roll = (float) Math.toDegrees(Math.atan2(gravity[0], gravity[1])); updateLevel(); return;
                }
            } else if (type == Sensor.TYPE_MAGNETIC_FIELD && event.values.length >= 3) {
                for (int i = 0; i < 3; i++) magnetic[i] = magneticReady ? magnetic[i] + 0.15f * (event.values[i] - magnetic[i]) : event.values[i];
                magneticReady = true;
            }
            if (page != 0) return;
            boolean ready = false;
            if (type == Sensor.TYPE_ROTATION_VECTOR && event.values.length >= 3) { SensorManager.getRotationMatrixFromVector(matrix, event.values); ready = true; }
            else if (gravityReady && magneticReady) ready = SensorManager.getRotationMatrix(matrix, null, gravity, magnetic);
            if (ready) {
                SensorManager.getOrientation(matrix, orientation);
                float raw = ((float) Math.toDegrees(orientation[0]) + 360f) % 360f;
                heading = headingReady ? (heading + 0.15f * ((raw - heading + 540f) % 360f - 180f) + 360f) % 360f : raw;
                headingReady = true; int degrees = Math.round(heading) % 360;
                headingText.setText(degrees + "°");
                cardinalText.setText(new String[]{"Norte", "Noreste", "Este", "Sureste", "Sur", "Suroeste", "Oeste", "Noroeste"}[((int) ((heading + 22.5f) / 45f)) % 8]);
                dial.invalidate();
                if (type == Sensor.TYPE_ROTATION_VECTOR || type == Sensor.TYPE_MAGNETIC_FIELD) updateAccuracy(event.accuracy);
            }
        } catch (Exception ignored) { }
    }
    @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {
        if (resumed && page == 0 && sensor != null) {
            try { if (sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD || sensor.getType() == Sensor.TYPE_ROTATION_VECTOR) updateAccuracy(accuracy); }
            catch (Exception ignored) { }
        }
    }
    private void updateAccuracy(int accuracy) { compassHint.setText(accuracy <= SensorManager.SENSOR_STATUS_ACCURACY_LOW ? "Aleja el móvil de imanes" : ""); }
    private void updateLevel() {
        if (levelText == null) return;
        levelText.setText(gravityReady ? (vertical ? String.format(Locale.US, "%.1f°", roll) : String.format(Locale.US, "X %.1f°   Y %.1f°", tiltX, tiltY)) : (vertical ? "—°" : "X —°   Y —°"));
        modeButton.setText(vertical ? "Plano / Vertical ✓" : "Plano ✓ / Vertical");
        if (levelHint != null && accelerationSensor != null) levelHint.setText(vertical ? "Modo vertical" : "Modo plano");
        level.invalidate();
    }
    private boolean audioPermission() {
        try { return Build.VERSION.SDK_INT < 23 || checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED; }
        catch (Exception ignored) { return false; }
    }
    private void startAudio() {
        if (recording != null || !resumed || page != 2) return;
        if (!audioPermission()) {
            soundHint.setText("Permite el micrófono para medir · Toca para reintentar");
            if (Build.VERSION.SDK_INT >= 23 && !permissionPending) {
                try { permissionPending = true; requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, 10); }
                catch (Exception ignored) { permissionPending = false; }
            }
            return;
        }
        Recording session = new Recording(++audioGeneration);
        try {
            int minimum = AudioRecord.getMinBufferSize(44100, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            if (minimum <= 0) throw new IllegalStateException();
            session.recorder = new AudioRecord(MediaRecorder.AudioSource.MIC, 44100, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, Math.max(minimum, 4410 * 4));
            if (session.recorder == null || session.recorder.getState() != AudioRecord.STATE_INITIALIZED) throw new IllegalStateException();
            session.recorder.startRecording();
            if (session.recorder.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING) throw new IllegalStateException();
            recording = session; history.clear(); maximum = 0; gauge.value = 0; gauge.invalidate();
            soundText.setText("— dB"); soundWord.setText("Escuchando…"); maxText.setText("Máx — dB");
            soundHint.setText("Nivel aproximado · Sin calibrar");
            session.thread = new Thread(() -> capture(session), "Medidor-sonido"); session.thread.start();
        } catch (Exception ignored) {
            session.cancelled = true; session.release(); recording = null;
            soundHint.setText("No se pudo abrir el micrófono · Toca para reintentar");
        }
    }
    private void capture(Recording session) {
        short[] samples = new short[4410]; boolean failed = false;
        try {
            while (!session.cancelled) {
                int count = 0;
                try { if (session.recorder != null) count = session.recorder.read(samples, 0, samples.length); }
                catch (Exception failure) { if (!session.cancelled) failed = true; break; }
                if (session.cancelled) break;
                if (count <= 0) { failed = true; break; }
                double squares = 0; for (int i = 0; i < count; i++) squares += (double) samples[i] * samples[i];
                double rms = Math.sqrt(squares / count);
                final float db = (float) Math.max(0, Math.min(120, 20 * Math.log10(Math.max(1e-9, rms) / 32768.0) + 90));
                final long time = SystemClock.elapsedRealtime();
                main.post(() -> {
                    if (!current(session)) return;
                    soundText.setText(Math.round(db) + " dB"); soundWord.setText(db < 30 ? "Silencio" : db < 50 ? "Normal" : db < 70 ? "Ruidoso" : "Muy ruidoso");
                    maximum = Math.max(maximum, db); maxText.setText("Máx " + Math.round(maximum) + " dB");
                    gauge.value += 0.25f * (db - gauge.value); gauge.invalidate(); history.add(time, db);
                });
            }
        } finally {
            session.release();
            final boolean error = failed;
            main.post(() -> {
                if (!current(session)) return;
                recording = null;
                if (error) { soundWord.setText("Medición detenida"); soundHint.setText("Micrófono no disponible · Toca para reintentar"); }
            });
        }
    }
    private boolean current(Recording session) { return resumed && page == 2 && recording == session && !session.cancelled && session.generation == audioGeneration; }
    private void stopAudio() {
        ++audioGeneration; Recording session = recording; recording = null;
        if (session == null) return;
        session.cancelled = true;
        try { if (session.recorder != null) session.recorder.stop(); } catch (Exception ignored) { }
        if (session.thread != null) {
            session.thread.interrupt();
            try { session.thread.join(1000); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
        }
        session.release();
    }
    private static class Recording {
        final int generation; volatile boolean cancelled; AudioRecord recorder; Thread thread; private boolean released;
        Recording(int generation) { this.generation = generation; }
        synchronized void release() {
            if (released) return; released = true;
            try { if (recorder != null) recorder.stop(); } catch (Exception ignored) { }
            try { if (recorder != null) recorder.release(); } catch (Exception ignored) { }
        }
    }
    @Override public void onRequestPermissionsResult(int request, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(request, permissions, results);
        if (request != 10) return; permissionPending = false;
        if (resumed && page == 2) {
            if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) startAudio();
            else soundHint.setText("Micrófono sin permiso · Toca para reintentar");
        }
    }

    private abstract class Drawing extends View {
        final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        Drawing() { super(MeasureActivity.this); setLayerType(LAYER_TYPE_SOFTWARE, null); }
        void line(int color, float width) { paint.setShader(null); paint.clearShadowLayer(); paint.setColor(color); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(width); paint.setStrokeCap(Paint.Cap.ROUND); }
        void text(Canvas canvas, String value, float x, float y, int size, int color) {
            paint.setShader(null); paint.clearShadowLayer(); paint.setStyle(Paint.Style.FILL); paint.setColor(color);
            paint.setTextSize(dp(size)); paint.setTypeface(Typeface.create("sans-serif-light", 0)); paint.setTextAlign(Paint.Align.CENTER);
            canvas.drawText(value, x, y - (paint.ascent() + paint.descent()) / 2, paint);
        }
    }
    private class DialView extends Drawing {
        DialView() { setContentDescription("Rosa de los vientos"); }
        @Override protected void onDraw(Canvas canvas) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f, radius = Math.min(getWidth(), getHeight()) / 2f - dp(20);
            if (radius <= 0) return;
            line(stroke, Math.max(1f, density * 0.5f)); canvas.drawCircle(cx, cy, radius, paint);
            for (int i = 0; i < 72; i++) {
                double angle = Math.toRadians(i * 5f + 2.5f - heading - 90f);
                float inner = radius - dp(8); line(subtle, Math.max(1f, density * 0.5f));
                canvas.drawLine(cx + inner * (float) Math.cos(angle), cy + inner * (float) Math.sin(angle), cx + radius * (float) Math.cos(angle), cy + radius * (float) Math.sin(angle), paint);
            }
            for (int i = 0; i < 12; i++) {
                double angle = Math.toRadians(i * 30f - heading - 90f);
                float inner = radius - dp(18); line(ink, density);
                canvas.drawLine(cx + inner * (float) Math.cos(angle), cy + inner * (float) Math.sin(angle), cx + radius * (float) Math.cos(angle), cy + radius * (float) Math.sin(angle), paint);
            }
            String[] names = {"N", "E", "S", "O"};
            for (int i = 0; i < 4; i++) {
                double angle = Math.toRadians(i * 90 - heading - 90); float r = radius - dp(40);
                text(canvas, names[i], cx + r * (float) Math.cos(angle), cy + r * (float) Math.sin(angle), 23, i == 0 ? 0xFFFF6B78 : ink);
            }
            line(Color.WHITE, Math.max(1f, density * 0.7f)); canvas.drawLine(cx, cy - radius + dp(55), cx, cy + radius - dp(55), paint);
            paint.setStyle(Paint.Style.FILL); paint.setColor(accent);
            Path marker = new Path(); marker.moveTo(cx, cy - radius + dp(3)); marker.lineTo(cx - dp(5), cy - radius - dp(9)); marker.lineTo(cx + dp(5), cy - radius - dp(9)); marker.close(); canvas.drawPath(marker, paint);
            canvas.drawCircle(cx, cy, dp(3), paint);
        }
    }
    private class LevelView extends Drawing {
        LevelView() { setContentDescription("Nivel de burbuja"); }
        @Override protected void onDraw(Canvas canvas) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f, radius = Math.min(getWidth(), getHeight()) / 2f - dp(26);
            if (radius <= 0) return;
            boolean aligned = gravityReady && (vertical ? Math.abs(roll) < 0.8f : Math.abs(tiltX) < 0.8f && Math.abs(tiltY) < 0.8f);
            int color = aligned ? GREEN : ink;
            line(aligned ? GREEN : stroke, density);
            if (aligned) paint.setShadowLayer(dp(12), 0, 0, GREEN);
            if (vertical) {
                RectF bar = new RectF(cx - radius, cy - dp(30), cx + radius, cy + dp(30)); canvas.drawRoundRect(bar, dp(30), dp(30), paint);
                line(subtle, Math.max(1f, density * 0.5f)); canvas.drawLine(cx, cy - dp(42), cx, cy + dp(42), paint);
                float offset = Math.max(-1, Math.min(1, roll / 45)) * Math.max(0, radius - dp(28));
                line(color, dp(2)); canvas.drawCircle(cx + offset, cy, dp(23), paint);
            } else {
                canvas.drawCircle(cx, cy, radius, paint); line(subtle, Math.max(1f, density * 0.5f));
                canvas.drawLine(cx - radius, cy, cx + radius, cy, paint); canvas.drawLine(cx, cy - radius, cx, cy + radius, paint);
                canvas.drawCircle(cx, cy, dp(28), paint);
                float bx = -tiltX / 25f, by = tiltY / 25f, length = (float) Math.sqrt(bx * bx + by * by);
                if (length > 1) { bx /= length; by /= length; }
                float travel = Math.max(0, radius - dp(25));
                line(color, dp(2)); canvas.drawCircle(cx + bx * travel, cy + by * travel, dp(23), paint);
            }
            paint.setStyle(Paint.Style.FILL); paint.setColor(aligned ? 0x3034D399 : (night ? 0x26FFFFFF : 0x1814123A));
            if (!vertical) {
                float bx = -tiltX / 25f, by = tiltY / 25f, length = (float) Math.sqrt(bx * bx + by * by);
                if (length > 1) { bx /= length; by /= length; }
                canvas.drawCircle(cx + bx * Math.max(0, radius - dp(25)), cy + by * Math.max(0, radius - dp(25)), dp(22), paint);
            }
        }
    }
    private class GaugeView extends Drawing {
        float value;
        GaugeView() { setContentDescription("Escala aproximada de 0 a 120 decibelios"); }
        @Override protected void onDraw(Canvas canvas) {
            float radius = Math.min(getWidth() / 2f - dp(24), getHeight() - dp(42));
            if (radius <= 0) return;
            float cx = getWidth() / 2f, cy = radius + dp(16);
            RectF oval = new RectF(cx - radius, cy - radius, cx + radius, cy + radius);
            line(stroke, dp(9)); canvas.drawArc(oval, 180, 180, false, paint);
            paint.setShader(new SweepGradient(cx, cy, new int[]{0xFFFB7185, 0xFFFB7185, GREEN, 0xFFFACC15, 0xFFFB7185}, new float[]{0, 0.499f, 0.5f, 0.75f, 1}));
            canvas.drawArc(oval, 180, Math.max(0.2f, value / 120f * 180f), false, paint); paint.setShader(null);
            double angle = Math.toRadians(180 + value / 120 * 180);
            line(ink, density); canvas.drawLine(cx, cy, cx + (radius - dp(18)) * (float) Math.cos(angle), cy + (radius - dp(18)) * (float) Math.sin(angle), paint);
            text(canvas, "0", cx - radius, cy + dp(22), 12, subtle); text(canvas, "120 dB", cx + radius - dp(8), cy + dp(22), 12, subtle);
        }
    }
    private class HistoryView extends Drawing {
        final long[] times = new long[400]; final float[] values = new float[400]; int start, count;
        HistoryView() { setContentDescription("Historial de sonido de los últimos treinta segundos"); }
        void clear() { start = count = 0; invalidate(); }
        void add(long time, float value) {
            while (count > 0 && (time - times[start] > 30000 || count == times.length)) { start = (start + 1) % times.length; count--; }
            int index = (start + count) % times.length; times[index] = time; values[index] = value; count++; invalidate();
        }
        @Override protected void onDraw(Canvas canvas) {
            float left = dp(6), right = getWidth() - dp(6), top = dp(16), bottom = getHeight() - dp(25);
            if (right <= left || bottom <= top) return;
            line(stroke, Math.max(1f, density * 0.5f));
            for (int i = 0; i <= 3; i++) { float y = top + (bottom - top) * i / 3; canvas.drawLine(left, y, right, y, paint); }
            long now = SystemClock.elapsedRealtime(); Path path = new Path(); boolean begun = false;
            for (int i = 0; i < count; i++) {
                int index = (start + i) % times.length; long age = now - times[index]; if (age > 30000) continue;
                float x = right - age / 30000f * (right - left), y = bottom - values[index] / 120f * (bottom - top);
                if (!begun) { path.moveTo(x, y); begun = true; } else path.lineTo(x, y);
            }
            line(accent, dp(2)); canvas.drawPath(path, paint);
            text(canvas, "−30 s", left + dp(14), bottom + dp(17), 10, subtle); text(canvas, "Ahora", right - dp(16), bottom + dp(17), 10, subtle);
        }
    }
    @Override public void onConfigurationChanged(Configuration config) { super.onConfigurationChanged(config); recreate(); }
    @Override public void finish() {
        super.finish(); int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
