package com.scratch.ioscalendar;

import android.app.*;
import android.content.*;
import android.content.res.Configuration;
import android.database.ContentObserver;
import android.database.Cursor;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.*;
import android.provider.CalendarContract;
import android.text.InputType;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Aurora calendar: native provider data, glass over wallpaper, no generated resources. */
public class CalendarActivity extends Activity {
    private static final Locale ES = new Locale("es", "ES");
    private float d;
    private boolean night, destroyed, observing, compact, monthExpanded;
    private MonthPanel monthPanel;
    private int text, accent, glass, stroke, generation;
    private Calendar month, selected;
    private TextView heading, dayHeading;
    private LinearLayout agenda;
    private final DayView[] days = new DayView[42];
    private List<Event> events = new ArrayList<>();
    private String loadError;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final ContentObserver observer = new ContentObserver(main) {
        @Override public void onChange(boolean selfChange) { loadMonth(); }
    };

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        d = getResources().getDisplayMetrics().density;
        compact = getResources().getConfiguration().screenHeightDp < 420;
        monthExpanded = state != null && state.getBoolean("monthExpanded", false);
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        selected = midnight(System.currentTimeMillis());
        month = (Calendar) selected.clone(); month.set(Calendar.DAY_OF_MONTH, 1);
        if (state != null) {
            selected = midnight(state.getLong("selected", selected.getTimeInMillis()));
            month = midnight(state.getLong("month", month.getTimeInMillis()));
            month.set(Calendar.DAY_OF_MONTH, 1);
        } else readIntent(getIntent());

        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this);
        scrim.setBackgroundColor(night ? 0x9914123A : 0x66F6F5FF);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout col = column(); col.setPadding(dp(12), dp(24), dp(12), dp(8));
        if (compact) {
            ScrollView all = new ScrollView(this); all.setFillViewport(true);
            all.addView(col, new ScrollView.LayoutParams(-1, -2));
            root.addView(all, new FrameLayout.LayoutParams(-1, -1));
        } else root.addView(col, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout toolbar = new LinearLayout(this); toolbar.setGravity(Gravity.CENTER_VERTICAL);
        TextView label = label(compact ? "Calendario ▾" : "Calendario", 16, accent);
        if (compact) {
            label.setText(monthExpanded ? "Calendario ▴" : "Calendario ▾");
            label.setContentDescription(monthExpanded ? "Ocultar calendario mensual" : "Mostrar calendario mensual");
            label.setOnClickListener(v -> {
                monthExpanded = !monthExpanded;
                monthPanel.setVisibility(monthExpanded ? View.VISIBLE : View.GONE);
                label.setText(monthExpanded ? "Calendario ▴" : "Calendario ▾");
                label.setContentDescription(monthExpanded ? "Ocultar calendario mensual" : "Mostrar calendario mensual");
            });
        }
        toolbar.addView(label, new LinearLayout.LayoutParams(0, dp(compact ? 48 : 36), 1));
        TextView today = control("Hoy", 16, "Ir a hoy");
        today.setOnClickListener(v -> { selected = midnight(System.currentTimeMillis()); month = (Calendar) selected.clone(); month.set(Calendar.DAY_OF_MONTH, 1); refreshMonth(); });
        toolbar.addView(today, new LinearLayout.LayoutParams(dp(48), dp(compact ? 48 : 36)));
        TextView add = control("+", 32, "Añadir evento"); add.setOnClickListener(v -> newEvent());
        toolbar.addView(add, new LinearLayout.LayoutParams(dp(compact ? 48 : 40), dp(compact ? 48 : 36))); col.addView(toolbar);

        LinearLayout header = new LinearLayout(this); header.setGravity(Gravity.CENTER_VERTICAL);
        heading = label("", 27, text); heading.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        heading.setSingleLine(true);
        header.addView(heading, new LinearLayout.LayoutParams(0, dp(52), 1));
        TextView prev = control("‹", 34, "Mes anterior"), next = control("›", 34, "Mes siguiente");
        prev.setOnClickListener(v -> changeMonth(-1)); next.setOnClickListener(v -> changeMonth(1));
        header.addView(prev, new LinearLayout.LayoutParams(dp(32), dp(48)));
        header.addView(next, new LinearLayout.LayoutParams(dp(32), dp(48))); col.addView(header);

        MonthPanel panel = new MonthPanel(); monthPanel = panel;
        if (compact && !monthExpanded) panel.setVisibility(View.GONE);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setBackground(round(glass, 20)); panel.setPadding(dp(4), dp(4), dp(4), dp(4));
        LinearLayout weekdays = new LinearLayout(this);
        for (String name : new String[]{"L", "M", "X", "J", "V", "S", "D"}) {
            TextView t = label(name, 12, accent); t.setGravity(Gravity.CENTER);
            weekdays.addView(t, new LinearLayout.LayoutParams(0, dp(25), 1));
        }
        panel.addView(weekdays);
        for (int r = 0; r < 6; r++) {
            LinearLayout row = new LinearLayout(this);
            for (int c = 0; c < 7; c++) {
                DayView day = new DayView(); days[r * 7 + c] = day;
                row.addView(day, new LinearLayout.LayoutParams(0, dp(36), 1));
            }
            panel.addView(row);
        }
        col.addView(panel);
        dayHeading = label("", 17, text); dayHeading.setPadding(dp(6), dp(8), 0, 0);
        col.addView(dayHeading, new LinearLayout.LayoutParams(-1, dp(40)));
        agenda = column();
        if (compact) col.addView(agenda, new LinearLayout.LayoutParams(-1, -2));
        else {
            ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true);
            scroll.addView(agenda, new ScrollView.LayoutParams(-1, -2));
            col.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        }
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            col.setPadding(col.getPaddingLeft(), insets.getSystemWindowInsetTop(), col.getPaddingRight(), col.getPaddingBottom());
            return insets;
        });
        setContentView(root); refreshMonth();
    }

    @Override protected void onResume() {
        super.onResume();
        if (!observing) {
            try { getContentResolver().registerContentObserver(CalendarContract.CONTENT_URI, true, observer); observing = true; }
            catch (Exception ignored) { }
        }
        loadMonth();
    }
    @Override protected void onPause() {
        if (observing) {
            try { getContentResolver().unregisterContentObserver(observer); } catch (Exception ignored) { }
            observing = false;
        }
        super.onPause();
    }
    @Override protected void onDestroy() { destroyed = true; generation++; worker.shutdown(); super.onDestroy(); }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }
    @Override protected void onSaveInstanceState(Bundle out) {
        out.putBoolean("monthExpanded", monthExpanded);
        out.putLong("selected", selected.getTimeInMillis()); out.putLong("month", month.getTimeInMillis()); super.onSaveInstanceState(out);
    }
    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent); setIntent(intent); readIntent(intent); refreshMonth(); }

    private void readIntent(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction())) return;
        try {
            long time = intent.getLongExtra("beginTime", -1);
            Uri uri = intent.getData();
            if (uri != null) {
                String last = uri.getLastPathSegment();
                if (last != null && !"time".equals(last)) time = Long.parseLong(last);
                else if (uri.getQueryParameter("beginTime") != null) time = Long.parseLong(uri.getQueryParameter("beginTime"));
            }
            if (time >= 0) { selected = midnight(time); month = (Calendar) selected.clone(); month.set(Calendar.DAY_OF_MONTH, 1); }
        } catch (Exception ignored) { }
    }
    private int dp(float n) { return (int) (n * d + 0.5f); }
    private Calendar midnight(long time) {
        Calendar c = Calendar.getInstance(); c.setTimeInMillis(time);
        c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0); return c;
    }
    private String format(String pattern, long time) { return new SimpleDateFormat(pattern, ES).format(new Date(time)); }
    private LinearLayout column() { LinearLayout v = new LinearLayout(this); v.setOrientation(LinearLayout.VERTICAL); return v; }
    private TextView label(String value, int size, int color) {
        TextView t = new TextView(this); t.setText(value); t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, size); t.setGravity(Gravity.CENTER_VERTICAL);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL)); return t;
    }
    private GradientDrawable round(int fill, int radius) {
        GradientDrawable bg = new GradientDrawable(); bg.setColor(fill); bg.setCornerRadius(dp(radius));
        bg.setStroke(Math.max(1, dp(1)), stroke); return bg;
    }
    private TextView control(String value, int size, String description) {
        TextView v = label(value, size, accent); v.setGravity(Gravity.CENTER); v.setContentDescription(description); spring(v); return v;
    }
    private void spring(View v) {
        v.setOnTouchListener((view, e) -> {
            if (e.getActionMasked() == MotionEvent.ACTION_DOWN) {
                view.animate().cancel(); view.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80)
                    .setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
            } else if (e.getActionMasked() == MotionEvent.ACTION_UP || e.getActionMasked() == MotionEvent.ACTION_CANCEL) {
                view.animate().scaleX(1f).scaleY(1f).setDuration(320)
                    .setInterpolator(new android.view.animation.OvershootInterpolator(3.2f)).start();
            }
            return false;
        });
    }
    private Calendar gridStart() {
        Calendar c = (Calendar) month.clone(); c.set(Calendar.DAY_OF_MONTH, 1);
        c.add(Calendar.DAY_OF_MONTH, -((c.get(Calendar.DAY_OF_WEEK) + 5) % 7)); return c;
    }
    private void changeMonth(int step) {
        int day = selected.get(Calendar.DAY_OF_MONTH);
        month.add(Calendar.MONTH, step); selected = (Calendar) month.clone();
        selected.set(Calendar.DAY_OF_MONTH, Math.min(day, selected.getActualMaximum(Calendar.DAY_OF_MONTH))); refreshMonth();
    }
    private void refreshMonth() {
        heading.setText(format("MMMM yyyy", month.getTimeInMillis())); events = new ArrayList<>(); loadError = null;
        Calendar c = gridStart();
        for (DayView day : days) { day.date = (Calendar) c.clone(); day.invalidate(); c.add(Calendar.DAY_OF_MONTH, 1); }
        renderDays(); renderAgenda("Cargando eventos…"); loadMonth();
    }
    private void select(Calendar day) {
        selected = (Calendar) day.clone();
        if (selected.get(Calendar.MONTH) != month.get(Calendar.MONTH) || selected.get(Calendar.YEAR) != month.get(Calendar.YEAR)) {
            month = (Calendar) selected.clone(); month.set(Calendar.DAY_OF_MONTH, 1); refreshMonth();
        } else { renderDays(); renderAgenda(null); }
    }
    private void renderDays() {
        for (DayView day : days) {
            day.count = 0;
            for (Event event : events) if (overlaps(event, day.date)) day.count++;
            day.setContentDescription(format("EEEE d 'de' MMMM yyyy", day.date.getTimeInMillis()) + ", " + day.count + " eventos");
            day.invalidate();
        }
    }
    private boolean overlaps(Event event, Calendar day) {
        Calendar end = (Calendar) day.clone(); end.add(Calendar.DAY_OF_MONTH, 1);
        return event.start < end.getTimeInMillis() && event.end > day.getTimeInMillis();
    }
    // All-day provider timestamps use UTC dates, regardless of the phone's zone.
    private long localAllDay(long millis) {
        Calendar utc = Calendar.getInstance(TimeZone.getTimeZone("UTC")); utc.setTimeInMillis(millis);
        Calendar local = midnight(System.currentTimeMillis());
        local.set(utc.get(Calendar.YEAR), utc.get(Calendar.MONTH), utc.get(Calendar.DAY_OF_MONTH)); return local.getTimeInMillis();
    }
    private void loadMonth() {
        if (destroyed || heading == null) return;
        final int request = ++generation;
        Calendar start = gridStart(), end = (Calendar) start.clone(); end.add(Calendar.DAY_OF_MONTH, 42);
        // One extra day on either side also covers UTC all-day dates in every time zone.
        start.add(Calendar.DAY_OF_MONTH, -1); end.add(Calendar.DAY_OF_MONTH, 1);
        final long from = start.getTimeInMillis(), to = end.getTimeInMillis();
        worker.execute(() -> {
            List<Event> result = new ArrayList<>(); String error = null; Cursor cursor = null;
            try {
                Uri.Builder uri = CalendarContract.Instances.CONTENT_URI.buildUpon();
                ContentUris.appendId(uri, from); ContentUris.appendId(uri, to);
                cursor = getContentResolver().query(uri.build(), new String[]{CalendarContract.Instances.EVENT_ID,
                    CalendarContract.Instances.BEGIN, CalendarContract.Instances.END, CalendarContract.Instances.TITLE,
                    CalendarContract.Instances.CALENDAR_COLOR, CalendarContract.Instances.ALL_DAY,
                    CalendarContract.Instances.CALENDAR_ACCESS_LEVEL}, CalendarContract.Instances.VISIBLE + "=1", null,
                    CalendarContract.Instances.BEGIN + " ASC");
                if (cursor == null) throw new IllegalStateException("Calendar provider unavailable");
                while (cursor.moveToNext()) {
                    Event e = new Event(); e.id = cursor.getLong(0); e.start = cursor.getLong(1); e.end = cursor.getLong(2);
                    e.title = cursor.isNull(3) || cursor.getString(3).trim().isEmpty() ? "Sin título" : cursor.getString(3);
                    e.color = cursor.isNull(4) ? accent : cursor.getInt(4) | 0xFF000000;
                    e.allDay = cursor.getInt(5) != 0; e.writable = cursor.getInt(6) >= 500;
                    if (e.allDay) { e.start = localAllDay(e.start); e.end = localAllDay(e.end); }
                    if (e.end <= e.start) e.end = e.start + 1;
                    result.add(e);
                }
            } catch (SecurityException ex) { error = "Activa el permiso de calendario en Ajustes para ver los eventos."; }
              catch (Exception ex) { error = "No se pudieron leer los eventos del calendario."; }
            finally { closeCursor(cursor); }
            final String message = error;
            main.post(() -> {
                if (destroyed || request != generation) return;
                events = result; loadError = message; renderDays(); renderAgenda(null);
            });
        });
    }
    private void renderAgenda(String status) {
        dayHeading.setText(format("EEEE d 'de' MMMM", selected.getTimeInMillis())); agenda.removeAllViews();
        if (status == null) status = loadError;
        if (status != null) { empty(status); return; }
        int count = 0;
        for (Event e : events) {
            if (!overlaps(e, selected)) continue;
            count++;
            LinearLayout row = new LinearLayout(this); row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(dp(10), dp(10), dp(10), dp(10)); row.setMinimumHeight(dp(58)); row.setBackground(round(glass, 14));
            View color = new View(this); GradientDrawable mark = new GradientDrawable(); mark.setColor(e.color); mark.setCornerRadius(dp(3)); color.setBackground(mark);
            row.addView(color, new LinearLayout.LayoutParams(dp(4), dp(32)));
            TextView time = label(e.allDay ? "Todo\nel día" : format("HH:mm", e.start), 13, accent); time.setPadding(dp(8), 0, dp(6), 0);
            row.addView(time, new LinearLayout.LayoutParams(dp(66), -2));
            TextView title = label(e.title, 17, text); row.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
            row.setContentDescription(time.getText() + ", " + e.title + ". Mantén pulsado para eliminar.");
            row.setOnLongClickListener(v -> { confirmDelete(e); return true; }); spring(row);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2); lp.bottomMargin = dp(6); agenda.addView(row, lp);
        }
        if (count == 0) empty("No hay eventos. Pulsa + para añadir uno.");
    }
    private void empty(String message) { TextView t = label(message, 15, text); t.setPadding(dp(10), dp(10), dp(10), dp(10)); agenda.addView(t); }
    private void closeCursor(Cursor cursor) {
        if (cursor != null) { try { cursor.close(); } catch (Exception ignored) { } }
    }
    private void toast(String message) { if (!destroyed && !isFinishing()) Toast.makeText(this, message, Toast.LENGTH_LONG).show(); }
    private boolean alive() { return !destroyed && !isFinishing(); }

    private void newEvent() {
        final Calendar when = (Calendar) selected.clone();
        Calendar now = Calendar.getInstance(); when.set(Calendar.HOUR_OF_DAY, Math.min(23, now.get(Calendar.HOUR_OF_DAY) + 1)); when.set(Calendar.MINUTE, 0);
        Context dialogContext = new ContextThemeWrapper(this, night ? android.R.style.Theme_Holo : android.R.style.Theme_Holo_Light);
        LinearLayout fields = column(); fields.setPadding(dp(20), dp(8), dp(20), dp(8));
        EditText title = new EditText(dialogContext); title.setHint("Título"); title.setSingleLine(true); title.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES); fields.addView(title);
        Button date = new Button(dialogContext), time = new Button(dialogContext);
        Runnable update = () -> { date.setText(format("d 'de' MMMM yyyy", when.getTimeInMillis())); time.setText(format("HH:mm", when.getTimeInMillis())); };
        update.run();
        date.setOnClickListener(v -> new DatePickerDialog(dialogContext, (picker, year, mon, day) -> {
            when.set(Calendar.DAY_OF_MONTH, 1); when.set(Calendar.YEAR, year); when.set(Calendar.MONTH, mon); when.set(Calendar.DAY_OF_MONTH, day); update.run();
        }, when.get(Calendar.YEAR), when.get(Calendar.MONTH), when.get(Calendar.DAY_OF_MONTH)).show());
        time.setOnClickListener(v -> new TimePickerDialog(dialogContext, (picker, hour, minute) -> { when.set(Calendar.HOUR_OF_DAY, hour); when.set(Calendar.MINUTE, minute); update.run(); },
            when.get(Calendar.HOUR_OF_DAY), when.get(Calendar.MINUTE), true).show());
        fields.addView(date); fields.addView(time);
        fields.addView(label("Duración (minutos)", 14, text));
        EditText duration = new EditText(dialogContext); duration.setInputType(InputType.TYPE_CLASS_NUMBER); duration.setText("60"); duration.setSingleLine(true); fields.addView(duration);
        ScrollView scroller = new ScrollView(this); scroller.addView(fields);
        AlertDialog dialog = new AlertDialog.Builder(dialogContext).setTitle("Nuevo evento").setView(scroller)
            .setNegativeButton("Cancelar", null).setPositiveButton("Guardar", null).create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
            String name = title.getText().toString().trim();
            if (name.isEmpty()) { title.setError("Escribe un título"); return; }
            int minutes;
            try { minutes = Integer.parseInt(duration.getText().toString()); if (minutes < 1 || minutes > 525600) throw new NumberFormatException(); }
            catch (NumberFormatException ex) { duration.setError("Introduce de 1 a 525600 minutos"); return; }
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setEnabled(false);
            insertEvent(name, when.getTimeInMillis(), minutes, dialog);
        }));
        dialog.show();
    }
    private void insertEvent(String title, long start, int minutes, AlertDialog dialog) {
        worker.execute(() -> {
            Cursor cursor = null; String message; boolean saved = false;
            try {
                cursor = getContentResolver().query(CalendarContract.Calendars.CONTENT_URI,
                    new String[]{CalendarContract.Calendars._ID}, CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL + ">=?",
                    new String[]{"500"}, CalendarContract.Calendars._ID + " ASC");
                if (cursor == null || !cursor.moveToFirst()) message = "No hay ningún calendario con permiso de escritura. Añade una cuenta de calendario en Ajustes.";
                else {
                    ContentValues values = new ContentValues(); values.put(CalendarContract.Events.CALENDAR_ID, cursor.getLong(0));
                    values.put(CalendarContract.Events.TITLE, title); values.put(CalendarContract.Events.DTSTART, start);
                    values.put(CalendarContract.Events.DTEND, start + minutes * 60000L);
                    values.put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().getID());
                    Uri inserted = getContentResolver().insert(CalendarContract.Events.CONTENT_URI, values);
                    saved = inserted != null; message = saved ? "Evento guardado" : "No se pudo guardar el evento.";
                }
            } catch (SecurityException ex) { message = "Activa los permisos de calendario en Ajustes para guardar eventos."; }
              catch (Exception ex) { message = "No se pudo guardar el evento."; }
            finally { closeCursor(cursor); }
            final String result = message; final boolean success = saved;
            main.post(() -> {
                if (!alive()) return;
                toast(result);
                if (success) { dialog.dismiss(); selected = midnight(start); month = (Calendar) selected.clone(); month.set(Calendar.DAY_OF_MONTH, 1); refreshMonth(); }
                else if (dialog.isShowing()) dialog.getButton(AlertDialog.BUTTON_POSITIVE).setEnabled(true);
            });
        });
    }
    private void confirmDelete(Event event) {
        if (!event.writable) { toast("Este calendario es de solo lectura."); return; }
        new AlertDialog.Builder(this).setTitle("Eliminar evento").setMessage("¿Eliminar «" + event.title + "»?" +
            "\nSi se repite, se eliminará toda la serie.")
            .setNegativeButton("Cancelar", null).setPositiveButton("Eliminar", (dialog, which) -> worker.execute(() -> {
                String message;
                try {
                    int deleted = getContentResolver().delete(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, event.id), null, null);
                    message = deleted > 0 ? "Evento eliminado" : "El evento ya no está disponible.";
                } catch (SecurityException ex) { message = "No tienes permiso para eliminar este evento."; }
                  catch (Exception ex) { message = "No se pudo eliminar el evento."; }
                final String result = message;
                main.post(() -> { if (alive()) { toast(result); loadMonth(); } });
            })).show();
    }
    private static class Event { long id, start, end; String title; int color; boolean allDay, writable; }

    private class DayView extends View {
        Calendar date; int count;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        DayView() { super(CalendarActivity.this); setFocusable(true); spring(this); setOnClickListener(v -> { if (date != null) select(date); }); }
        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas); if (date == null) return;
            float x = getWidth() / 2f, y = dp(15), radius = dp(13);
            boolean today = date.getTimeInMillis() == midnight(System.currentTimeMillis()).getTimeInMillis();
            boolean chosen = date.getTimeInMillis() == selected.getTimeInMillis();
            paint.setStyle(Paint.Style.FILL); paint.setColor(accent);
            if (today) canvas.drawCircle(x, y, radius, paint);
            if (chosen) { paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(dp(1)); canvas.drawCircle(x, y, dp(15), paint); paint.setStyle(Paint.Style.FILL); }
            paint.setColor(today ? (night ? 0xFF14123A : Color.WHITE) : text);
            if (!today && date.get(Calendar.MONTH) != month.get(Calendar.MONTH)) paint.setAlpha(90);
            paint.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL)); paint.setTextSize(dp(16)); paint.setTextAlign(Paint.Align.CENTER);
            canvas.drawText(String.valueOf(date.get(Calendar.DAY_OF_MONTH)), x, y - (paint.ascent() + paint.descent()) / 2, paint);
            paint.setColor(accent); if (count > 0) canvas.drawCircle(x, dp(33), dp(1.6f), paint);
        }
    }
    private class MonthPanel extends LinearLayout {
        private float downX, downY; private boolean swiping;
        MonthPanel() { super(CalendarActivity.this); }
        @Override public boolean onInterceptTouchEvent(MotionEvent e) {
            if (e.getActionMasked() == MotionEvent.ACTION_DOWN) { downX = e.getX(); downY = e.getY(); swiping = false; }
            if (e.getActionMasked() == MotionEvent.ACTION_MOVE && Math.abs(e.getX() - downX) > dp(20) && Math.abs(e.getX() - downX) > Math.abs(e.getY() - downY) * 1.5f) {
                swiping = true; return true;
            }
            return false;
        }
        @Override public boolean onTouchEvent(MotionEvent e) {
            if (e.getActionMasked() == MotionEvent.ACTION_UP && swiping) {
                float delta = e.getX() - downX;
                if (Math.abs(delta) > dp(48)) changeMonth(delta < 0 ? 1 : -1);
                swiping = false; return true;
            }
            if (e.getActionMasked() == MotionEvent.ACTION_CANCEL) swiping = false;
            return true;
        }
    }

    /** Aurora exit transition (res/anim/app_exit): soft zoom-out and fade instead of the ROM default. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
