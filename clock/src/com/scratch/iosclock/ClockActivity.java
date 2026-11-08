package com.scratch.iosclock;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.TimePickerDialog;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.InputType;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.text.SimpleDateFormat;
import java.util.*;

/** Own Clock: alarms, stopwatch, timer and world clocks on glass over the wallpaper; follows day/night. */
public class ClockActivity extends Activity {
    private static final String[][] CITIES = {
        {"Madrid", "Europe/Madrid"}, {"Londres", "Europe/London"}, {"París", "Europe/Paris"}, {"Berlín", "Europe/Berlin"},
        {"Roma", "Europe/Rome"}, {"Lisboa", "Europe/Lisbon"}, {"Atenas", "Europe/Athens"}, {"Moscú", "Europe/Moscow"},
        {"Dubái", "Asia/Dubai"}, {"Bombay", "Asia/Kolkata"}, {"Bangkok", "Asia/Bangkok"}, {"Pekín", "Asia/Shanghai"},
        {"Tokio", "Asia/Tokyo"}, {"Sídney", "Australia/Sydney"}, {"Auckland", "Pacific/Auckland"}, {"El Cairo", "Africa/Cairo"},
        {"Johannesburgo", "Africa/Johannesburg"}, {"Nueva York", "America/New_York"}, {"Chicago", "America/Chicago"},
        {"Denver", "America/Denver"}, {"Los Ángeles", "America/Los_Angeles"}, {"México DF", "America/Mexico_City"},
        {"Bogotá", "America/Bogota"}, {"Lima", "America/Lima"}, {"Buenos Aires", "America/Argentina/Buenos_Aires"},
        {"Santiago", "America/Santiago"}, {"São Paulo", "America/Sao_Paulo"}, {"Honolulu", "Pacific/Honolulu"}};

    private float d;
    private boolean night;
    private int text, text2, scrim, glass, glassStroke, accent, danger, ok;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private FrameLayout pages;
    private final View[] page = new View[4];
    private final TextView[] tabLabels = new TextView[4];
    private final View[] tabIcons = new View[4];
    private int tab = 0;

    // alarms
    private LinearLayout alarmList;
    // stopwatch
    private long swStart, swElapsed;
    private boolean swRunning;
    private TextView swTime;
    private LinearLayout lapBox;
    private final List<Long> laps = new ArrayList<>();
    private TextView swGo, swLap;
    // timer
    private TextView timerView, timerGo;
    private long timerChoice = 5 * 60000L;
    private TimerRing ring;
    // world
    private LinearLayout worldList;

    private final Runnable tick = new Runnable() {
        @Override public void run() {
            if (swTime != null && page[1] != null && page[1].getVisibility() == View.VISIBLE) updateStopwatch();
            if (page[2] != null && page[2].getVisibility() == View.VISIBLE) updateTimer();
            if (page[3] != null && page[3].getVisibility() == View.VISIBLE) renderWorld();
            ui.postDelayed(this, 100);
        }
    };

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        text2 = night ? 0xB3FFFFFF : 0x9914123A;
        scrim = night ? 0x9914123A : 0x66F6F5FF;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        glassStroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        danger = night ? 0xFFFB7185 : 0xFFDC2626;
        ok = night ? 0xFF34D399 : 0xFF10B981;

        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        FrameLayout root = new FrameLayout(this);
        View sc = new View(this);
        sc.setBackgroundColor(scrim);
        root.addView(sc, new FrameLayout.LayoutParams(-1, -1));
        pages = new FrameLayout(this);
        FrameLayout.LayoutParams pl = new FrameLayout.LayoutParams(-1, -1);
        pl.topMargin = (int) (24 * d);
        pl.bottomMargin = (int) (80 * d);
        root.addView(pages, pl);
        FrameLayout.LayoutParams bl = new FrameLayout.LayoutParams(-1, (int) (60 * d), Gravity.BOTTOM);
        bl.leftMargin = bl.rightMargin = (int) (14 * d);
        bl.bottomMargin = (int) (14 * d);
        root.addView(tabBar(), bl);
        setContentView(root);
        select(0);
        ui.post(tick);
    }

    @Override protected void onResume() { super.onResume(); if (page[0] != null) renderAlarms(); updateTimerButton(); }
    @Override protected void onDestroy() { ui.removeCallbacks(tick); super.onDestroy(); }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }

    // ---- tabs --------------------------------------------------------------------

    private View tabBar() {
        LinearLayout bar = new LinearLayout(this);
        GradientDrawable g = new GradientDrawable();
        g.setColor(night ? 0x3314123A : 0xB3FFFFFF);
        g.setStroke(Math.max(1, (int) d), glassStroke);
        g.setCornerRadius(30 * d);
        bar.setBackground(g);
        String[] names = {"Alarmas", "Cronómetro", "Temporizador", "Mundo"};
        String[] kinds = {"alarm", "stopwatch", "timer", "globe"};
        for (int i = 0; i < 4; i++) {
            final int idx = i;
            LinearLayout cell = new LinearLayout(this);
            cell.setOrientation(LinearLayout.VERTICAL);
            cell.setGravity(Gravity.CENTER);
            tabIcons[i] = glyph(kinds[i], text2, 22);
            tabIcons[i].setClickable(false);
            cell.addView(tabIcons[i], new LinearLayout.LayoutParams((int) (24 * d), (int) (24 * d)));
            TextView t = new TextView(this);
            t.setText(names[i]);
            t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9);
            t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            t.setGravity(Gravity.CENTER);
            t.setSingleLine();
            tabLabels[i] = t;
            cell.addView(t);
            cell.setOnClickListener(v -> select(idx));
            bar.addView(cell, new LinearLayout.LayoutParams(0, -1, 1f));
        }
        return bar;
    }

    private void select(int i) {
        tab = i;
        for (int k = 0; k < 4; k++) {
            boolean on = k == i;
            tabLabels[k].setTextColor(on ? accent : text2);
            ((GlyphView) tabIcons[k]).color = on ? accent : text2;
            tabIcons[k].invalidate();
        }
        if (page[i] == null) {
            page[i] = i == 0 ? buildAlarms() : i == 1 ? buildStopwatch() : i == 2 ? buildTimer() : buildWorld();
            pages.addView(page[i], new FrameLayout.LayoutParams(-1, -1));
        }
        for (int k = 0; k < 4; k++) if (page[k] != null) page[k].setVisibility(k == i ? View.VISIBLE : View.GONE);
        if (i == 0) renderAlarms();
        if (i == 3) renderWorld();
    }

    private View title(String s, View right) {
        LinearLayout head = new LinearLayout(this);
        head.setGravity(Gravity.CENTER_VERTICAL);
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(text);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        t.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        t.setPadding((int) (22 * d), (int) (12 * d), 0, (int) (8 * d));
        head.addView(t, new LinearLayout.LayoutParams(0, -2, 1f));
        if (right != null) head.addView(right, new LinearLayout.LayoutParams((int) (56 * d), (int) (56 * d)));
        return head;
    }

    // ---- alarms ------------------------------------------------------------------

    private View buildAlarms() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        View plus = glyph("plus", text, 22);
        plus.setOnClickListener(v -> editAlarm(null));
        col.addView(title("Alarmas", plus));
        ScrollView sv = new ScrollView(this);
        alarmList = new LinearLayout(this);
        alarmList.setOrientation(LinearLayout.VERTICAL);
        alarmList.setPadding((int) (14 * d), 0, (int) (14 * d), (int) (16 * d));
        sv.addView(alarmList);
        col.addView(sv, new LinearLayout.LayoutParams(-1, 0, 1f));
        return col;
    }

    private void renderAlarms() {
        alarmList.removeAllViews();
        List<Alarms.Alarm> list = Alarms.load(this);
        Collections.sort(list, (a, b) -> (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
        if (list.isEmpty()) {
            TextView none = new TextView(this);
            none.setText("Sin alarmas\nToca + para añadir una");
            none.setTextColor(text2);
            none.setGravity(Gravity.CENTER);
            none.setPadding(0, (int) (80 * d), 0, 0);
            alarmList.addView(none);
            return;
        }
        for (final Alarms.Alarm a : list) {
            LinearLayout card = new LinearLayout(this);
            card.setGravity(Gravity.CENTER_VERTICAL);
            card.setBackground(pill(glass, glassStroke, 22));
            card.setPadding((int) (20 * d), (int) (10 * d), (int) (16 * d), (int) (10 * d));
            LinearLayout t = new LinearLayout(this);
            t.setOrientation(LinearLayout.VERTICAL);
            TextView time = new TextView(this);
            time.setText(String.format(Locale.US, "%02d:%02d", a.hour, a.minute));
            time.setTextColor(a.on ? text : text2);
            time.setTextSize(TypedValue.COMPLEX_UNIT_SP, 40);
            time.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
            TextView sub = new TextView(this);
            sub.setText((a.label.isEmpty() ? "" : a.label + " · ") + Alarms.daysText(a.days));
            sub.setTextColor(text2);
            sub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
            t.addView(time);
            t.addView(sub);
            card.addView(t, new LinearLayout.LayoutParams(0, -2, 1f));
            card.addView(toggle(a.on, on -> {
                List<Alarms.Alarm> cur = Alarms.load(this);
                for (Alarms.Alarm x : cur) if (x.id == a.id) x.on = on;
                Alarms.save(this, cur);
                renderAlarms();
            }), new LinearLayout.LayoutParams((int) (52 * d), (int) (32 * d)));
            card.setOnClickListener(v -> editAlarm(a));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
            lp.bottomMargin = (int) (8 * d);
            alarmList.addView(card, lp);
        }
    }

    private void editAlarm(final Alarms.Alarm existing) {
        final Alarms.Alarm a = new Alarms.Alarm();
        if (existing != null) { a.id = existing.id; a.hour = existing.hour; a.minute = existing.minute; a.days = existing.days; a.label = existing.label; a.on = existing.on; }
        else { Calendar c = Calendar.getInstance(); a.hour = (c.get(Calendar.HOUR_OF_DAY) + 1) % 24; a.minute = 0; a.on = true; }

        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding((int) (24 * d), (int) (16 * d), (int) (24 * d), (int) (8 * d));
        final TextView time = new TextView(this);
        time.setTextSize(TypedValue.COMPLEX_UNIT_SP, 56);
        time.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        time.setGravity(Gravity.CENTER);
        time.setTextColor(night ? Color.WHITE : 0xFF14123A);
        Runnable upd = () -> time.setText(String.format(Locale.US, "%02d:%02d", a.hour, a.minute));
        upd.run();
        time.setOnClickListener(v -> new TimePickerDialog(this, night ? AlertDialog.THEME_DEVICE_DEFAULT_DARK : AlertDialog.THEME_DEVICE_DEFAULT_LIGHT,
                (view, h, m) -> { a.hour = h; a.minute = m; upd.run(); }, a.hour, a.minute, true).show());
        box.addView(time);
        TextView hint = new TextView(this);
        hint.setText("Toca la hora para cambiarla");
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        hint.setGravity(Gravity.CENTER);
        hint.setTextColor(night ? 0xB3FFFFFF : 0x9914123A);
        box.addView(hint);

        LinearLayout days = new LinearLayout(this);
        days.setGravity(Gravity.CENTER);
        days.setPadding(0, (int) (14 * d), 0, (int) (6 * d));
        String[] names = {"L", "M", "X", "J", "V", "S", "D"};
        for (int i = 0; i < 7; i++) {
            final int bit = 1 << i;
            final TextView chip = new TextView(this);
            chip.setText(names[i]);
            chip.setGravity(Gravity.CENTER);
            chip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
            Runnable style = () -> {
                boolean on = (a.days & bit) != 0;
                GradientDrawable g = new GradientDrawable();
                g.setShape(GradientDrawable.OVAL);
                g.setColor(on ? accent : (night ? 0x33FFFFFF : 0x1F14123A));
                chip.setBackground(g);
                chip.setTextColor(on ? Color.WHITE : (night ? Color.WHITE : 0xFF14123A));
            };
            style.run();
            chip.setOnClickListener(v -> { a.days ^= bit; style.run(); });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams((int) (28 * d), (int) (28 * d));
            lp.setMargins((int) (2 * d), 0, (int) (2 * d), 0);
            days.addView(chip, lp);
        }
        box.addView(days);
        final EditText label = new EditText(this);
        label.setHint("Etiqueta");
        label.setText(a.label);
        label.setSingleLine();
        label.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        box.addView(label);

        AlertDialog.Builder b = new AlertDialog.Builder(this, night ? AlertDialog.THEME_DEVICE_DEFAULT_DARK : AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setView(box)
                .setNegativeButton("Cancelar", null)
                .setPositiveButton("Guardar", (dlg, w) -> {
                    a.label = label.getText().toString().trim();
                    a.on = true;
                    List<Alarms.Alarm> list = Alarms.load(this);
                    if (existing == null) { a.id = Alarms.nextId(list); list.add(a); }
                    else for (int i = 0; i < list.size(); i++) if (list.get(i).id == a.id) list.set(i, a);
                    Alarms.save(this, list);
                    renderAlarms();
                    long t = Alarms.nextTrigger(a, System.currentTimeMillis());
                    long mins = Math.max(1, (t - System.currentTimeMillis()) / 60000);
                    Toast.makeText(this, "Suena en " + (mins >= 60 ? (mins / 60) + " h " : "") + (mins % 60) + " min", Toast.LENGTH_SHORT).show();
                });
        if (existing != null) b.setNeutralButton("Eliminar", (dlg, w) -> {
            List<Alarms.Alarm> list = Alarms.load(this);
            for (Iterator<Alarms.Alarm> it = list.iterator(); it.hasNext(); ) if (it.next().id == a.id) it.remove();
            Alarms.save(this, list);
            // the registered system alarm must go too: rescheduleAll() only walks alarms that still exist
            android.app.PendingIntent pi = Alarms.pending(this, a.id, "alarm");
            ((android.app.AlarmManager) getSystemService(Context.ALARM_SERVICE)).cancel(pi);
            pi.cancel();
            renderAlarms();
        });
        b.show();
    }

    // ---- stopwatch ----------------------------------------------------------------

    private View buildStopwatch() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.addView(title("Cronómetro", null));
        swTime = new TextView(this);
        swTime.setTextColor(text);
        swTime.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64);
        swTime.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        swTime.setGravity(Gravity.CENTER);
        swTime.setPadding(0, (int) (30 * d), 0, (int) (20 * d));
        col.addView(swTime);
        LinearLayout btns = new LinearLayout(this);
        btns.setGravity(Gravity.CENTER);
        swLap = round("Vuelta", glass, text);
        swGo = round("Iniciar", ok, Color.WHITE);
        swLap.setOnClickListener(v -> {
            if (swRunning) { laps.add(0, elapsed()); renderLaps(); }
            else { swElapsed = 0; laps.clear(); renderLaps(); updateStopwatch(); }
        });
        swGo.setOnClickListener(v -> {
            if (swRunning) { swElapsed = elapsed(); swRunning = false; }
            else { swStart = SystemClock.elapsedRealtime(); swRunning = true; }
            updateStopwatch();
        });
        LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams((int) (84 * d), (int) (84 * d));
        bp.setMargins((int) (20 * d), 0, (int) (20 * d), 0);
        btns.addView(swLap, bp);
        btns.addView(swGo, bp);
        col.addView(btns);
        ScrollView sv = new ScrollView(this);
        lapBox = new LinearLayout(this);
        lapBox.setOrientation(LinearLayout.VERTICAL);
        lapBox.setPadding((int) (28 * d), (int) (16 * d), (int) (28 * d), 0);
        sv.addView(lapBox);
        col.addView(sv, new LinearLayout.LayoutParams(-1, 0, 1f));
        updateStopwatch();
        return col;
    }

    private long elapsed() { return swRunning ? swElapsed + SystemClock.elapsedRealtime() - swStart : swElapsed; }

    private void updateStopwatch() {
        long e = elapsed();
        swTime.setText(String.format(Locale.US, "%02d:%02d.%02d", e / 60000, (e / 1000) % 60, (e / 10) % 100));
        swGo.setText(swRunning ? "Parar" : "Iniciar");
        swGo.setBackground(circle(swRunning ? danger : ok));
        swLap.setText(swRunning ? "Vuelta" : "Reiniciar");
    }

    private void renderLaps() {
        lapBox.removeAllViews();
        for (int i = 0; i < laps.size(); i++) {
            long e = laps.get(i), prev = i + 1 < laps.size() ? laps.get(i + 1) : 0;
            long lap = e - prev;
            TextView t = new TextView(this);
            t.setText(String.format(Locale.US, "Vuelta %d      %02d:%02d.%02d", laps.size() - i, lap / 60000, (lap / 1000) % 60, (lap / 10) % 100));
            t.setTextColor(text);
            t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
            t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            t.setPadding(0, (int) (6 * d), 0, (int) (6 * d));
            lapBox.addView(t);
        }
    }

    // ---- timer --------------------------------------------------------------------

    private View buildTimer() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL);
        col.addView(title("Temporizador", null));
        FrameLayout dial = new FrameLayout(this);
        ring = new TimerRing(this);
        dial.addView(ring, new FrameLayout.LayoutParams(-1, -1));
        timerView = new TextView(this);
        timerView.setTextColor(text);
        timerView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 44);
        timerView.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        timerView.setGravity(Gravity.CENTER);
        dial.addView(timerView, new FrameLayout.LayoutParams(-1, -1));
        col.addView(dial, new LinearLayout.LayoutParams((int) (190 * d), (int) (190 * d)));

        LinearLayout chips = new LinearLayout(this);
        chips.setGravity(Gravity.CENTER);
        chips.setPadding(0, (int) (14 * d), 0, (int) (10 * d));
        int[] mins = {1, 5, 10, 15, 30};
        for (final int m : mins) {
            TextView c = new TextView(this);
            c.setText(m + "'");
            c.setSingleLine();
            c.setTextColor(text);
            c.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
            c.setPadding((int) (16 * d), (int) (7 * d), (int) (16 * d), (int) (7 * d));
            c.setBackground(pill(glass, glassStroke, 18));
            c.setOnClickListener(v -> { if (Alarms.prefs(this).getLong("timer_end", 0) == 0) { timerChoice = m * 60000L; updateTimer(); } });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
            lp.setMargins((int) (3 * d), 0, (int) (3 * d), 0);
            chips.addView(c, lp);
        }
        col.addView(chips);
        timerGo = round("Iniciar", ok, Color.WHITE);
        timerGo.setOnClickListener(v -> {
            if (Alarms.prefs(this).getLong("timer_end", 0) > System.currentTimeMillis()) Alarms.cancelTimer(this);
            else Alarms.startTimer(this, timerChoice);
            updateTimer();
        });
        col.addView(timerGo, new LinearLayout.LayoutParams((int) (76 * d), (int) (76 * d)));
        updateTimer();
        return col;
    }

    private void updateTimerButton() { if (timerGo != null) updateTimer(); }

    private void updateTimer() {
        long end = Alarms.prefs(this).getLong("timer_end", 0), total = Alarms.prefs(this).getLong("timer_total", timerChoice);
        long left = end - System.currentTimeMillis();
        boolean running = end > 0 && left > 0;
        long shown = running ? left : timerChoice;
        long s = (shown + 999) / 1000;
        timerView.setText(s >= 3600 ? String.format(Locale.US, "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
                : String.format(Locale.US, "%02d:%02d", s / 60, s % 60));
        ring.fraction = running ? Math.max(0f, left / (float) total) : 1f;
        ring.invalidate();
        timerGo.setText(running ? "Cancelar" : "Iniciar");
        timerGo.setBackground(circle(running ? danger : ok));
    }

    private class TimerRing extends View {
        float fraction = 1f;
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        TimerRing(Context c) { super(c); }
        @Override protected void onDraw(Canvas cv) {
            float s = Math.min(getWidth(), getHeight()), m = 10 * d;
            RectF r = new RectF((getWidth() - s) / 2f + m, (getHeight() - s) / 2f + m, (getWidth() + s) / 2f - m, (getHeight() + s) / 2f - m);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(5 * d);
            p.setStrokeCap(Paint.Cap.ROUND);
            p.setColor(night ? 0x33FFFFFF : 0x2214123A);
            cv.drawArc(r, 0, 360, false, p);
            p.setColor(accent);
            cv.drawArc(r, -90, 360 * fraction, false, p);
        }
    }

    // ---- world clocks -----------------------------------------------------------------

    private View buildWorld() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        View plus = glyph("plus", text, 22);
        plus.setOnClickListener(v -> addCity());
        col.addView(title("Mundo", plus));
        ScrollView sv = new ScrollView(this);
        worldList = new LinearLayout(this);
        worldList.setOrientation(LinearLayout.VERTICAL);
        worldList.setPadding((int) (14 * d), 0, (int) (14 * d), (int) (16 * d));
        sv.addView(worldList);
        col.addView(sv, new LinearLayout.LayoutParams(-1, 0, 1f));
        return col;
    }

    private List<String> cities() {
        String raw = Alarms.prefs(this).getString("cities", "Europe/Madrid;America/New_York;Asia/Tokyo");
        return new ArrayList<>(Arrays.asList(raw.split(";")));
    }

    private String cityName(String tz) {
        for (String[] c : CITIES) if (c[1].equals(tz)) return c[0];
        return tz;
    }

    private long lastWorldMinute = -1;

    private void renderWorld() {
        long minute = System.currentTimeMillis() / 60000;
        if (minute == lastWorldMinute && worldList.getChildCount() > 0) return;
        lastWorldMinute = minute;
        worldList.removeAllViews();
        final List<String> list = cities();
        Date now = new Date();
        TimeZone local = TimeZone.getDefault();
        for (final String tz : list) {
            TimeZone z = TimeZone.getTimeZone(tz);
            int diffH = (z.getOffset(now.getTime()) - local.getOffset(now.getTime())) / 3600000;
            SimpleDateFormat f = new SimpleDateFormat("HH:mm", Locale.getDefault());
            f.setTimeZone(z);
            LinearLayout card = new LinearLayout(this);
            card.setGravity(Gravity.CENTER_VERTICAL);
            card.setBackground(pill(glass, glassStroke, 22));
            card.setPadding((int) (20 * d), (int) (10 * d), (int) (20 * d), (int) (10 * d));
            LinearLayout t = new LinearLayout(this);
            t.setOrientation(LinearLayout.VERTICAL);
            TextView n = new TextView(this);
            n.setText(cityName(tz));
            n.setTextColor(text);
            n.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
            n.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            TextView s = new TextView(this);
            s.setText(diffH == 0 ? "Hora local" : (diffH > 0 ? "+" : "") + diffH + " h");
            s.setTextColor(text2);
            s.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
            t.addView(n);
            t.addView(s);
            card.addView(t, new LinearLayout.LayoutParams(0, -2, 1f));
            TextView h = new TextView(this);
            h.setText(f.format(now));
            h.setTextColor(text);
            h.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
            h.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
            card.addView(h);
            card.setOnLongClickListener(v -> { list.remove(tz); Alarms.prefs(this).edit().putString("cities", join(list)).apply(); lastWorldMinute = -1; renderWorld(); return true; });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
            lp.bottomMargin = (int) (8 * d);
            worldList.addView(card, lp);
        }
        TextView hint = new TextView(this);
        hint.setText("Mantén pulsada una ciudad para quitarla");
        hint.setTextColor(text2);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        hint.setGravity(Gravity.CENTER);
        hint.setPadding(0, (int) (8 * d), 0, 0);
        worldList.addView(hint);
    }

    private static String join(List<String> l) {
        StringBuilder sb = new StringBuilder();
        for (String s : l) sb.append(sb.length() > 0 ? ";" : "").append(s);
        return sb.toString();
    }

    private void addCity() {
        final List<String> have = cities();
        final List<String[]> options = new ArrayList<>();
        for (String[] c : CITIES) if (!have.contains(c[1])) options.add(c);
        String[] names = new String[options.size()];
        for (int i = 0; i < names.length; i++) names[i] = options.get(i)[0];
        new AlertDialog.Builder(this, night ? AlertDialog.THEME_DEVICE_DEFAULT_DARK : AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setTitle("Añadir ciudad")
                .setItems(names, (dlg, which) -> {
                    have.add(options.get(which)[1]);
                    Alarms.prefs(this).edit().putString("cities", join(have)).apply();
                    lastWorldMinute = -1;
                    renderWorld();
                }).show();
    }

    // ---- helpers ------------------------------------------------------------------------

    interface OnToggle { void on(boolean v); }

    private View toggle(final boolean on, final OnToggle cb) {
        View v = new View(this) {
            @Override protected void onDraw(Canvas cv) {
                Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
                float h = getHeight(), w = getWidth();
                p.setColor(on ? ok : (night ? 0x44FFFFFF : 0x3314123A));
                cv.drawRoundRect(new RectF(0, 0, w, h), h / 2, h / 2, p);
                p.setColor(Color.WHITE);
                cv.drawCircle(on ? w - h / 2 : h / 2, h / 2, h / 2 - 3 * d, p);
            }
        };
        v.setOnClickListener(x -> cb.on(!on));
        return v;
    }

    private TextView round(String s, int fill, int color) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        t.setGravity(Gravity.CENTER);
        t.setBackground(circle(fill));
        return t;
    }

    private GradientDrawable circle(int fill) {
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(fill);
        return g;
    }

    private GradientDrawable pill(int fill, int stroke, int radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setStroke(Math.max(1, (int) d), stroke);
        g.setCornerRadius(radiusDp * d);
        return g;
    }

    private View glyph(String kind, int color, int sizeDp) { return new GlyphView(this, kind, color, sizeDp); }

    private class GlyphView extends View {
        final String kind;
        int color;
        final int sizeDp;
        GlyphView(Context c, String kind, int color, int sizeDp) { super(c); this.kind = kind; this.color = color; this.sizeDp = sizeDp; }
        @Override protected void onDraw(Canvas cv) {
            float s = sizeDp * d;
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setColor(color);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeCap(Paint.Cap.ROUND);
            p.setStrokeJoin(Paint.Join.ROUND);
            cv.save();
            cv.translate((getWidth() - s) / 2f, (getHeight() - s) / 2f);
            cv.scale(s / 48f, s / 48f);
            p.setStrokeWidth(3f);
            switch (kind) {
                case "plus": cv.drawLine(24, 8, 24, 40, p); cv.drawLine(8, 24, 40, 24, p); break;
                case "alarm":
                    cv.drawCircle(24, 26, 14, p);
                    cv.drawLine(24, 26, 24, 18, p); cv.drawLine(24, 26, 30, 29, p);
                    cv.drawLine(8, 12, 14, 7, p); cv.drawLine(40, 12, 34, 7, p);
                    break;
                case "stopwatch":
                    cv.drawCircle(24, 27, 14, p);
                    cv.drawLine(24, 27, 29, 20, p);
                    cv.drawLine(20, 8, 28, 8, p); cv.drawLine(24, 8, 24, 13, p);
                    break;
                case "timer":
                    cv.drawLine(14, 8, 34, 8, p); cv.drawLine(14, 40, 34, 40, p);
                    cv.drawLine(15, 8, 24, 24, p); cv.drawLine(33, 8, 24, 24, p);
                    cv.drawLine(24, 24, 15, 40, p); cv.drawLine(24, 24, 33, 40, p);
                    break;
                default: // globe
                    cv.drawCircle(24, 24, 15, p);
                    cv.drawOval(new RectF(17.5f, 9, 30.5f, 39), p);
                    cv.drawLine(9, 24, 39, 24, p);
            }
            cv.restore();
        }
    }
}
