package com.scratch.ios7launcher;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ActivityOptions;
import android.content.*;
import android.content.pm.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
import android.provider.Settings;
import android.os.*;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.util.*;

/** Flat paged home screen: squircle icons, translucent dock, no app drawer. */
public class HomeActivity extends Activity {
    private static final int COLS = 4, ROWS = 3;
    /** Preferred order / dock candidates, first match wins. */
    private static final String[][] DOCK = {
        {"com.scratch.iosphone", "com.android.dialer"},
        {"com.android.messaging"},
        {"com.scratch.ioscamera", "org.cyanogenmod.snap"},
        {"org.lineageos.jelly", "com.android.chrome"},
    };
    private static final java.util.Set<String> TOOLS = new java.util.HashSet<>(java.util.Arrays.asList(
        "com.topjohnwu.magisk", "de.robv.android.xposed.installer", "com.ceco.nougat.gravitybox"));
    /** Stock apps replaced by own ones: kept installed (the in-call UI needs them) but hidden from the grid. */
    private static final java.util.Set<String> HIDDEN = new java.util.HashSet<>(java.util.Arrays.asList("com.android.dialer", "com.android.gallery3d", "com.android.contacts", "com.android.deskclock", "com.android.calculator2",
        "com.android.calendar", "com.google.android.calendar", "com.cyanogenmod.eleven", "com.android.documentsui", "org.lineageos.recorder"));
    private static final java.util.Map<String, String> OWN = new java.util.HashMap<>();
    static {
        OWN.put("com.android.dialer", "com.scratch.iosphone");
        OWN.put("com.android.gallery3d", "com.scratch.iosgallery");
        OWN.put("com.android.contacts", "com.scratch.ioscontacts");
        OWN.put("com.android.deskclock", "com.scratch.iosclock");
        OWN.put("com.android.calculator2", "com.scratch.ioscalc");
        OWN.put("com.android.calendar", "com.scratch.ioscalendar");
        OWN.put("com.google.android.calendar", "com.scratch.ioscalendar");
        OWN.put("com.cyanogenmod.eleven", "com.scratch.iosmusic");
        OWN.put("com.android.documentsui", "com.scratch.iosfiles");
        OWN.put("org.lineageos.recorder", "com.scratch.iosrecorder");
    }
    private static final String[] FIRST = {
        "com.scratch.ioscontacts", "com.android.settings", "com.scratch.iosgallery", "com.scratch.iosclock",
        "com.scratch.ioscalc", "com.scratch.ioscalendar", "com.scratch.iosfiles", "com.scratch.iosmusic",
        "com.scratch.iosrecorder", "com.android.email", "com.android.vending", "org.cyanogenmod.snap",
    };

    private boolean night;
    private int labelColor, subColor, dockFill, dockStroke, scrim, boxFill, boxStroke, dotColor;
    private float d;
    private int w, h, gridH;
    private PackageManager pm;
    private PagerView pager;
    private LinearLayout dots, dock;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Map<String, Bitmap> cache = new HashMap<>();
    private final BroadcastReceiver pkgs = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent i) { reload(); }
    };

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        pm = getPackageManager();
        usage = new AppIndex.Usage(this);
        night = (getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK)
                == android.content.res.Configuration.UI_MODE_NIGHT_YES;
        labelColor = night ? Color.WHITE : 0xFF14123A;
        subColor = night ? 0xB3FFFFFF : 0x9914123A;
        dockFill = night ? 0x2EFFFFFF : 0x66FFFFFF;
        dockStroke = night ? 0x38FFFFFF : 0xB3FFFFFF;
        scrim = night ? 0xFF14123A : 0xFFF6F5FF;
        boxFill = night ? 0x29FFFFFF : 0xB3FFFFFF;
        boxStroke = night ? 0x38FFFFFF : 0xFFFFFFFF;
        dotColor = night ? Color.WHITE : 0xFF14123A;
        d = getResources().getDisplayMetrics().density;
        w = getResources().getDisplayMetrics().widthPixels;
        h = getResources().getDisplayMetrics().heightPixels;
        Window win = getWindow();
        win.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        FrameLayout root = new FrameLayout(this);

        int statusH = (int) (24 * d);
        TextClock time = headTime = new TextClock(this);
        time.setFormat24Hour("HH:mm");
        time.setFormat12Hour("h:mm");
        time.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        time.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64);
        time.setShadowLayer(6f, 0, 2, 0x40000000);
        time.setTextColor(labelColor);
        time.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        time.setPadding((int) (24 * d), 0, 0, 0);
        root.addView(time, new FrameLayout.LayoutParams(w, (int) (72 * d), Gravity.TOP) {{ topMargin = statusH; }});
        TextClock date = headDate = new TextClock(this);
        date.setFormat24Hour("EEEE, d 'de' MMMM");
        date.setFormat12Hour("EEEE, d 'de' MMMM");
        date.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        date.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        date.setTextColor(subColor);
        date.setShadowLayer(4f, 0, 1, 0x40000000);
        date.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        date.setPadding((int) (26 * d), 0, 0, 0);
        root.addView(date, new FrameLayout.LayoutParams(w, (int) (22 * d), Gravity.TOP) {{ topMargin = statusH + (int) (68 * d); }});

        int gridTop = statusH + (int) (104 * d);
        int dockH = (int) (76 * d), dockMargin = (int) (10 * d);
        int dotsH = (int) (20 * d);
        gridH = h - gridTop - dockH - dockMargin * 2 - dotsH;

        pager = new PagerView(this);
        root.addView(pager, new FrameLayout.LayoutParams(w, gridH, Gravity.TOP) {{ topMargin = gridTop; }});

        dots = new LinearLayout(this);
        dots.setGravity(Gravity.CENTER);
        root.addView(dots, new FrameLayout.LayoutParams(w, dotsH, Gravity.BOTTOM) {{ bottomMargin = dockH + dockMargin * 2; }});

        dock = new LinearLayout(this);
        dock.setOrientation(LinearLayout.HORIZONTAL);
        dock.setGravity(Gravity.CENTER);
        GradientDrawable dbg = new GradientDrawable();
        dbg.setColor(dockFill);
        dbg.setStroke(Math.max(1, (int) d), dockStroke);
        dbg.setCornerRadius(30 * d);
        dock.setBackground(dbg);
        root.addView(dock, new FrameLayout.LayoutParams(w - (int) (16 * d), dockH, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL) {{ bottomMargin = dockMargin; }});

        doneBtn = pill("Listo");
        doneBtn.setOnClickListener(v -> setEditing(false));
        root.addView(doneBtn, new FrameLayout.LayoutParams(-2, -2, Gravity.TOP | Gravity.RIGHT) {{ topMargin = statusH + (int) (6 * d); rightMargin = (int) (20 * d); }});
        restoreBtn = pill("Mostrar ocultas");
        restoreBtn.setOnClickListener(v -> { getSharedPreferences("home", MODE_PRIVATE).edit().putString("hidden", "").apply(); setEditing(true); reload(); });
        root.addView(restoreBtn, new FrameLayout.LayoutParams(-2, -2, Gravity.TOP | Gravity.RIGHT) {{ topMargin = statusH + (int) (46 * d); rightMargin = (int) (20 * d); }});

        setContentView(root);
        IntentFilter f = new IntentFilter();
        f.addAction(Intent.ACTION_PACKAGE_ADDED);
        f.addAction(Intent.ACTION_PACKAGE_REMOVED);
        f.addAction(Intent.ACTION_PACKAGE_REPLACED);
        f.addDataScheme("package");
        registerReceiver(pkgs, f);
        reload();
    }

    @Override protected void onPause() { wasPaused = true; super.onPause(); }
    @Override protected void onResume() {
        super.onResume();
        refreshToday();
        if (wasPaused) { wasPaused = false; popCurrent(); }
    }

    @Override protected void onDestroy() { unregisterReceiver(pkgs); super.onDestroy(); }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        if (pager != null) pager.goTo(1);
    }

    @Override
    public void onConfigurationChanged(android.content.res.Configuration c) {
        super.onConfigurationChanged(c);
        recreate();
    }

    @Override public void onBackPressed() { if (ccLayer != null) hideControl(); else if (folderLayer != null) closeFolder(); else if (searchLayer != null) hideSearch(); else if (editing) setEditing(false); }

    private float downX, downY;
    private List<App> allApps = new ArrayList<>();
    private FrameLayout searchLayer;
    private EditText searchBox;
    private final List<Object[]> results = new ArrayList<>();   // {App} or {name, number}
    private BaseAdapter searchAdapter;
    private AppIndex.Usage usage;
    private String lastQuery = "";
    private boolean firstBuild = true;
    private TextClock headTime, headDate;
    private LinearLayout todayCol;
    private boolean animateNext = true, wasPaused;
    private TextView calView, batView, stoView, ramView, alarmView, noteView, musicView, torchBtn;
    private View musicBox;
    private View batBar, stoBar, ramBar;

    /** A clear downward swipe anywhere on the home screen opens the notification shade. */
    @Override
    public boolean dispatchTouchEvent(MotionEvent e) {
        if (e.getAction() == MotionEvent.ACTION_UP && !editing && searchLayer == null && folderLayer == null && ccLayer == null
                && e.getY() > h * 0.30f && e.getY() < h - 130 * d && Math.abs(e.getX() - downX) < 10 * d && Math.abs(e.getY() - downY) < 10 * d) {
            long now = SystemClock.uptimeMillis();
            // double tap on an empty part of the home screen (not on an icon) locks the phone
            if (now - lastTap < 350 && tapOnEmpty(e.getX(), e.getY())) { lastTap = 0; lockScreen(); }
            else lastTap = now;
        }
        if (e.getAction() == MotionEvent.ACTION_DOWN) { downX = e.getX(); downY = e.getY(); }
        else if (e.getAction() == MotionEvent.ACTION_UP) {
            float dy = e.getY() - downY, dx = e.getX() - downX;
            boolean onToday = pager != null && pager.page() == 0; // the Today page scrolls vertically by itself
            if (searchLayer == null && !onToday && dy > 90 * d && Math.abs(dy) > 2 * Math.abs(dx) && downY < h * 0.6f) expandShade();
            else if (searchLayer == null && ccLayer == null && dy < -100 * d && Math.abs(dy) > 2 * Math.abs(dx) && downY > h - 120 * d) showControl(); // from the dock: Control Center
            else if (searchLayer == null && !onToday && dy < -100 * d && Math.abs(dy) > 2 * Math.abs(dx) && downY > h * 0.25f && downY <= h - 120 * d) showSearch();
        }
        return super.dispatchTouchEvent(e);
    }

    // ---- today page ---------------------------------------------------------

    private View todayPage() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding((int) (18 * d), (int) (4 * d), (int) (18 * d), 0);
        alarmView = card(col, "PRÓXIMA ALARMA", 15, 0);
        // quick actions: torch, camera, recorder
        LinearLayout quick = cardBox(col, "ATAJOS");
        LinearLayout qrow = new LinearLayout(this);
        qrow.setOrientation(LinearLayout.HORIZONTAL);
        qrow.setPadding(0, (int) (6 * d), 0, 0);
        torchBtn = quickButton("Linterna", v -> toggleTorch());
        qrow.addView(torchBtn, new LinearLayout.LayoutParams(0, -2, 1f) {{ rightMargin = (int) (6 * d); }});
        qrow.addView(quickButton("Cámara", v -> openPkg("com.scratch.ioscamera")), new LinearLayout.LayoutParams(0, -2, 1f) {{ rightMargin = (int) (6 * d); }});
        qrow.addView(quickButton("Grabadora", v -> openPkg("com.scratch.iosrecorder")), new LinearLayout.LayoutParams(0, -2, 1f));
        quick.addView(qrow);
        musicView = card(col, "MÚSICA", 15, 0);
        musicBox = (View) musicView.getParent();
        musicBox.setVisibility(View.GONE);
        musicBox.setOnClickListener(v -> openPkg("com.scratch.iosmusic"));
        noteView = card(col, "NOTAS", 14, 0);
        ((View) noteView.getParent()).setOnLongClickListener(v -> { confirmClearNotes(); return true; });
        calView = card(col, "PRÓXIMOS EVENTOS", 14, 0);
        LinearLayout st = cardBox(col, "ESTADO");
        batView = row(st, "Batería");
        batBar = lastBar;
        stoView = row(st, "Almacenamiento");
        stoBar = lastBar;
        ramView = row(st, "Memoria");
        ramBar = lastBar;
        col.setPadding((int) (18 * d), (int) (4 * d), (int) (18 * d), (int) (24 * d));
        refreshToday();
        todayCol = col;
        ScrollView sv = new ScrollView(this);
        sv.setVerticalScrollBarEnabled(false);
        sv.setOverScrollMode(View.OVER_SCROLL_NEVER);
        sv.addView(col, new FrameLayout.LayoutParams(-1, -2));
        return sv;
    }

    private TextView quickButton(String text, View.OnClickListener l) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setGravity(Gravity.CENTER);
        t.setTextColor(labelColor);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        t.setPadding(0, (int) (9 * d), 0, (int) (9 * d));
        GradientDrawable g = new GradientDrawable();
        g.setColor(boxFill); g.setStroke(Math.max(1, (int) d), boxStroke); g.setCornerRadius(18 * d);
        t.setBackground(g);
        t.setOnClickListener(l);
        return t;
    }

    private void openPkg(String pkg) {
        Intent i = pm.getLaunchIntentForPackage(pkg);
        if (i != null) startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }

    private void toggleTorch() {
        try {
            android.hardware.camera2.CameraManager cm = (android.hardware.camera2.CameraManager) getSystemService(CAMERA_SERVICE);
            torchOn = !torchOn;
            cm.setTorchMode(cm.getCameraIdList()[0], torchOn);
            if (torchBtn != null) {
                GradientDrawable g = new GradientDrawable();
                g.setColor(torchOn ? 0xFFFFD60A : boxFill); g.setStroke(Math.max(1, (int) d), boxStroke); g.setCornerRadius(18 * d);
                torchBtn.setBackground(g);
                torchBtn.setTextColor(torchOn ? 0xFF14123A : labelColor);
            }
        } catch (Exception e) {
            torchOn = false;
            Toast.makeText(this, "No se pudo usar la linterna", Toast.LENGTH_SHORT).show();
        }
    }

    private void confirmClearNotes() {
        new android.app.AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
            .setTitle("¿Borrar todas las notas?")
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Borrar", (dlg, w2) -> { getSharedPreferences("home", MODE_PRIVATE).edit().putString("notes", "").apply(); refreshToday(); })
            .show();
    }

    private View lastBar;

    /** Label on the left, value on the right and a thin bar underneath. */
    private TextView row(LinearLayout box, String name) {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setPadding(0, (int) (5 * d), 0, 0);
        TextView n = new TextView(this);
        n.setText(name);
        n.setTextColor(labelColor);
        n.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        n.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        r.addView(n, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView v = new TextView(this);
        v.setTextColor(subColor);
        v.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        v.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        v.setGravity(Gravity.RIGHT);
        r.addView(v, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        box.addView(r);
        lastBar = bar(box);
        return v;
    }

    private LinearLayout cardBox(LinearLayout parent, String title) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding((int) (18 * d), (int) (9 * d), (int) (18 * d), (int) (10 * d));
        GradientDrawable g = new GradientDrawable();
        g.setColor(dockFill);
        g.setStroke(Math.max(1, (int) d), dockStroke);
        g.setCornerRadius(24 * d);
        box.setBackground(g);
        TextView t = new TextView(this);
        t.setText(title);
        t.setTextColor(subColor);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        t.setLetterSpacing(0.12f);
        box.addView(t);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.bottomMargin = (int) (7 * d);
        parent.addView(box, lp);
        return box;
    }

    private TextView card(LinearLayout parent, String title, int sp, int minH) {
        LinearLayout box = cardBox(parent, title);
        TextView t = new TextView(this);
        t.setTextColor(labelColor);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        t.setLineSpacing(0, 1.15f);
        t.setMinHeight((int) (minH * d));
        t.setPadding(0, (int) (6 * d), 0, 0);
        box.addView(t);
        return t;
    }

    private TextView big(LinearLayout box, String s) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(labelColor);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        t.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        box.addView(t);
        return t;
    }

    private TextView small(LinearLayout box, String s) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(labelColor);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        box.addView(t);
        return t;
    }

    /** Thin progress bar: translucent track, accent fill sized through layout weight of the tag. */
    private View bar(LinearLayout box) {
        FrameLayout track = new FrameLayout(this);
        GradientDrawable tg = new GradientDrawable();
        tg.setColor(night ? 0x33FFFFFF : 0x2214123A);
        tg.setCornerRadius(3 * d);
        track.setBackground(tg);
        View fill = new View(this);
        GradientDrawable fg = new GradientDrawable();
        fg.setColor(night ? 0xFF7BA7FF : 0xFF3B6BEA);
        fg.setCornerRadius(3 * d);
        fill.setBackground(fg);
        track.addView(fill, new FrameLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (int) (4 * d));
        lp.topMargin = (int) (6 * d);
        box.addView(track, lp);
        return fill;
    }

    private void setBar(View fill, float frac) {
        final View f = fill;
        final float fr = Math.max(0f, Math.min(1f, frac));
        ((View) f.getParent()).post(() -> {
            ViewGroup.LayoutParams lp = f.getLayoutParams();
            lp.width = (int) (((View) f.getParent()).getWidth() * fr);
            f.setLayoutParams(lp);
        });
    }

    private void refreshToday() {
        if (batView == null) return;
        Intent b = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (b != null) {
            int lvl = b.getIntExtra("level", 0), sc = Math.max(1, b.getIntExtra("scale", 100));
            int st = b.getIntExtra("status", 0);
            boolean chg = st == 2 || st == 5;
            batView.setText((lvl * 100 / sc) + "%" + (chg ? (st == 5 ? " · completa" : " · cargando") : ""));
            setBar(batBar, lvl / (float) sc);
        }
        StatFs fs = new StatFs(Environment.getDataDirectory().getPath());
        long total = fs.getTotalBytes(), free = fs.getAvailableBytes();
        stoView.setText(String.format(Locale.getDefault(), "%.1f GB libres", free / 1e9));
        setBar(stoBar, (total - free) / (float) total);
        ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        ((ActivityManager) getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(mi);
        ramView.setText(String.format(Locale.getDefault(), "%d MB libres", mi.availMem >> 20));
        setBar(ramBar, (mi.totalMem - mi.availMem) / (float) mi.totalMem);
        loadEvents();
        if (noteView != null) {
            StringBuilder sb = new StringBuilder();
            int n = 0;
            for (String line : getSharedPreferences("home", MODE_PRIVATE).getString("notes", "").split("\n")) {
                if (line.trim().isEmpty() || n >= 3) continue;
                sb.append(n++ > 0 ? "\n" : "").append("\u2022 ").append(line.trim());
            }
            noteView.setText(n == 0 ? "Escribe «nota …» en la búsqueda" : sb.toString());
            noteView.setAlpha(n == 0 ? 0.55f : 1f);
        }
        if (musicBox != null) {
            boolean playing = ((android.media.AudioManager) getSystemService(AUDIO_SERVICE)).isMusicActive();
            musicBox.setVisibility(playing ? View.VISIBLE : View.GONE);
            if (playing) musicView.setText("Reproduciendo \u00b7 toca para abrir");
        }
        if (alarmView != null) {
            android.app.AlarmManager.AlarmClockInfo ci = ((android.app.AlarmManager) getSystemService(ALARM_SERVICE)).getNextAlarmClock();
            if (ci == null) alarmView.setText("Sin alarmas");
            else {
                long t = ci.getTriggerTime();
                Calendar a = Calendar.getInstance(); a.setTimeInMillis(t);
                Calendar n = Calendar.getInstance();
                boolean today = a.get(Calendar.DAY_OF_YEAR) == n.get(Calendar.DAY_OF_YEAR) && a.get(Calendar.YEAR) == n.get(Calendar.YEAR);
                n.add(Calendar.DAY_OF_YEAR, 1);
                boolean tomorrow = a.get(Calendar.DAY_OF_YEAR) == n.get(Calendar.DAY_OF_YEAR) && a.get(Calendar.YEAR) == n.get(Calendar.YEAR);
                String hm = new java.text.SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date(t));
                String day = today ? "hoy" : tomorrow ? "mañana" : new java.text.SimpleDateFormat("EEEE d MMM", Locale.getDefault()).format(new Date(t));
                alarmView.setText(hm + " · " + day);
            }
        }
    }

    private void loadEvents() {
        final boolean can = checkSelfPermission(android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED;
        new Thread(() -> {
            StringBuilder sb = new StringBuilder();
            if (can) {
                android.database.Cursor c = null;
                try {
                    long now = System.currentTimeMillis();
                    c = android.provider.CalendarContract.Instances.query(getContentResolver(),
                            new String[]{android.provider.CalendarContract.Instances.TITLE, android.provider.CalendarContract.Instances.BEGIN,
                                    android.provider.CalendarContract.Instances.ALL_DAY},
                            now, now + 7L * 24 * 3600 * 1000);
                    java.text.SimpleDateFormat day = new java.text.SimpleDateFormat("EEE d", Locale.getDefault());
                    java.text.SimpleDateFormat hour = new java.text.SimpleDateFormat("HH:mm", Locale.getDefault());
                    int n = 0;
                    while (c != null && c.moveToNext() && n < 3) {
                        Date dt = new Date(c.getLong(1));
                        if (n > 0) sb.append('\n');
                        sb.append(c.getInt(2) == 1 ? day.format(dt) : day.format(dt) + " · " + hour.format(dt)).append("   ").append(c.getString(0));
                        n++;
                    }
                } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            }
            final String out = sb.length() > 0 ? sb.toString() : (can ? "Sin eventos próximos" : "Sin acceso al calendario");
            ui.post(() -> { if (calView != null) calView.setText(out); });
        }).start();
    }

    // ---- search ------------------------------------------------------------

    private void showSearch() {
        if (searchLayer != null) return;
        ViewGroup content = (ViewGroup) findViewById(android.R.id.content);
        searchLayer = new FrameLayout(this);
        searchLayer.setBackgroundColor(scrim);
        searchLayer.setOnClickListener(v -> hideSearch());
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (20 * d);
        col.setPadding(pad, (int) (48 * d), pad, 0);
        searchBox = new EditText(this);
        searchBox.setHint("Buscar apps y contactos");
        searchBox.setHintTextColor(subColor);
        searchBox.setTextColor(labelColor);
        searchBox.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        searchBox.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        searchBox.setSingleLine();
        searchBox.setPadding((int) (20 * d), (int) (14 * d), (int) (20 * d), (int) (14 * d));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(boxFill);
        bg.setStroke(Math.max(1, (int) d), boxStroke);
        bg.setCornerRadius(28 * d);
        searchBox.setBackground(bg);
        col.addView(searchBox, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        ListView list = new ListView(this);
        list.setDivider(null);
        list.setSelector(new ColorDrawable(night ? 0x1FFFFFFF : 0x1F14123A));
        searchAdapter = new BaseAdapter() {
            @Override public int getCount() { return results.size(); }
            @Override public Object getItem(int i) { return results.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public View getView(int i, View convert, ViewGroup parent) { return resultRow(results.get(i)); }
        };
        list.setAdapter(searchAdapter);
        list.setOnItemClickListener((p, v, i, id) -> openResult(results.get(i)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        lp.topMargin = (int) (12 * d);
        col.addView(list, lp);
        searchLayer.addView(col, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        // The status-bar icons stay white (GravityBox); over the pale day sheet they vanish, so tint the bar strip.
        View strip = new View(this);
        strip.setBackgroundColor(night ? 0xFF14123A : 0xFF8A97EE);
        searchLayer.addView(strip, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (int) (24 * d), Gravity.TOP));
        content.addView(searchLayer, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        searchLayer.setAlpha(0f);
        searchLayer.setTranslationY(36 * d);
        searchLayer.animate().alpha(1f).translationY(0f).setDuration(260).setInterpolator(new android.view.animation.DecelerateInterpolator(2f)).start();
        searchBox.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence c, int a, int b, int n) { }
            @Override public void onTextChanged(CharSequence c, int a, int b, int n) { runSearch(c.toString().trim()); }
            @Override public void afterTextChanged(android.text.Editable e) { }
        });
        searchBox.requestFocus();
        contactsLoaded = false;
        loadContactIndex();
        runSearch("");
        ((android.view.inputmethod.InputMethodManager) getSystemService(INPUT_METHOD_SERVICE)).showSoftInput(searchBox, 0);
    }

    private void hideSearch() {
        if (searchLayer == null) return;
        ((android.view.inputmethod.InputMethodManager) getSystemService(INPUT_METHOD_SERVICE))
                .hideSoftInputFromWindow(searchBox.getWindowToken(), 0);
        final View sheet = searchLayer;
        searchLayer = null;
        results.clear();
        sheet.animate().alpha(0f).translationY(30 * d).setDuration(170).withEndAction(() -> {
            if (sheet.getParent() != null) ((ViewGroup) sheet.getParent()).removeView(sheet);
        }).start();
    }

    /** Contacts are matched in memory: SQL LIKE cannot ignore accents or tolerate typos. */
    private final List<String[]> contactIndex = new ArrayList<>();       // name, number, normalised name, digits, normalised extras
    private volatile boolean contactsLoaded;

    private void loadContactIndex() {
        if (contactsLoaded || checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return;
        new Thread(() -> {
            Map<Long, StringBuilder> extra = new HashMap<>();             // nickname, organisation, e-mail
            android.database.Cursor e = null;
            try {
                e = getContentResolver().query(android.provider.ContactsContract.Data.CONTENT_URI,
                        new String[]{android.provider.ContactsContract.Data.CONTACT_ID, android.provider.ContactsContract.Data.DATA1},
                        android.provider.ContactsContract.Data.MIMETYPE + " IN (?,?,?)",
                        new String[]{android.provider.ContactsContract.CommonDataKinds.Nickname.CONTENT_ITEM_TYPE,
                                android.provider.ContactsContract.CommonDataKinds.Organization.CONTENT_ITEM_TYPE,
                                android.provider.ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE}, null);
                while (e != null && e.moveToNext()) {
                    String v = e.getString(1);
                    if (v == null) continue;
                    StringBuilder sb = extra.get(e.getLong(0));
                    if (sb == null) { sb = new StringBuilder(); extra.put(e.getLong(0), sb); }
                    sb.append(v).append(' ');
                }
            } catch (Exception ignored) { } finally { if (e != null) e.close(); }
            List<String[]> out = new ArrayList<>();
            android.database.Cursor c = null;
            try {
                c = getContentResolver().query(android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        new String[]{android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER,
                                android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID}, null, null,
                        android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " COLLATE LOCALIZED ASC");
                while (c != null && c.moveToNext()) {
                    String name = c.getString(0), num = c.getString(1);
                    if (name == null) continue;
                    StringBuilder ex = extra.get(c.getLong(2));
                    out.add(new String[]{name, num, Fuzzy.norm(name), num == null ? "" : num.replaceAll("[^0-9]", ""), ex == null ? "" : Fuzzy.norm(ex.toString())});
                }
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            synchronized (contactIndex) { contactIndex.clear(); contactIndex.addAll(out); }
            contactsLoaded = true;
            ui.post(() -> { if (searchBox != null) runSearch(searchBox.getText().toString().trim()); });
        }).start();
    }

    private void runSearch(String q) {
        results.clear();
        final String nq = Fuzzy.norm(q);
        lastQuery = nq;
        if (nq.isEmpty()) {
            // nothing typed yet: the apps you use most
            final List<App> frequent = new ArrayList<>();
            for (App a : allApps) if (usage.count(a.pkg) > 0) frequent.add(a);
            Collections.sort(frequent, (x, y) -> usage.count(y.pkg) - usage.count(x.pkg));
            for (int i = 0; i < frequent.size() && i < 5; i++) results.add(new Object[]{frequent.get(i)});
            searchAdapter.notifyDataSetChanged();
            return;
        }
        for (Smart.Item si : Smart.answer(q)) results.add(new Object[]{si});
        final List<Object[]> apps = new ArrayList<>();
        for (App a : allApps) {
            int sc = AppIndex.score(nq, a.norm, a.doc);
            if (sc > 0) apps.add(new Object[]{a, sc + usage.bonus(a.pkg, nq)});
        }
        Collections.sort(apps, (x, y) -> (Integer) y[1] - (Integer) x[1]);
        for (int i = 0; i < apps.size() && i < 8; i++) results.add(new Object[]{apps.get(i)[0]});
        final boolean digits = nq.replace(" ", "").matches("[0-9+]{3,}");
        final String dq = nq.replaceAll("[^0-9]", "");
        final List<Object[]> people = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        synchronized (contactIndex) {
            for (String[] c : contactIndex) {
                int sc = digits ? (c[3].contains(dq) ? 50 : 0) : Math.max(Fuzzy.score(nq, c[2]), Fuzzy.score(nq, c[4]) * 7 / 10);
                if (sc > 0 && seen.add(c[0])) people.add(new Object[]{c[0], c[1], sc});
            }
        }
        Collections.sort(people, (x, y) -> (Integer) y[2] - (Integer) x[2]);
        for (int i = 0; i < people.size() && i < 6; i++) results.add(new Object[]{people.get(i)[0], people.get(i)[1]});
        if (results.isEmpty() && q.trim().length() >= 3) results.add(new Object[]{Smart.web(q.trim())});
        if (!contactsLoaded) loadContactIndex();
        searchAdapter.notifyDataSetChanged();
    }

    private View resultRow(Object[] r) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding((int) (6 * d), (int) (8 * d), (int) (6 * d), (int) (8 * d));
        ImageView iv = new ImageView(this);
        int s = (int) (44 * d);
        String title, sub;
        if (r[0] instanceof Smart.Item) {
            Smart.Item si = (Smart.Item) r[0];
            iv.setImageBitmap(smartTile(si, s));
            title = si.title; sub = si.sub;
        } else if (r.length == 1) {
            App a = (App) r[0];
            Bitmap b = cache.get(a.pkg);
            if (b != null) iv.setImageBitmap(Bitmap.createScaledBitmap(b, s, s, true));
            title = a.label; sub = "App";
        } else {
            iv.setImageBitmap(avatar((String) r[0], s));
            title = (String) r[0]; sub = (String) r[1];
        }
        row.addView(iv, new LinearLayout.LayoutParams(s, s));
        LinearLayout txt = new LinearLayout(this);
        txt.setOrientation(LinearLayout.VERTICAL);
        TextView t = new TextView(this);
        t.setText(title); t.setTextColor(labelColor); t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL)); t.setSingleLine();
        TextView u = new TextView(this);
        u.setText(sub); u.setTextColor(subColor); u.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13); u.setSingleLine();
        txt.addView(t); txt.addView(u);
        LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        tp.leftMargin = (int) (14 * d);
        row.addView(txt, tp);
        return row;
    }

    private Bitmap smartTile(Smart.Item it, int s) {
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(it.color);
        c.drawRoundRect(new RectF(0, 0, s, s), s * 0.25f, s * 0.25f, p);
        p.setColor(Color.WHITE);
        p.setTextAlign(Paint.Align.CENTER);
        p.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        p.setTextSize(s * 0.5f);
        c.drawText(it.glyph, s / 2f, s / 2f - (p.descent() + p.ascent()) / 2f, p);
        return b;
    }

    private boolean torchOn;
    private long lastTap;

    private boolean tapOnEmpty(float x, float y) {
        View pv = pager == null ? null : pager.pageView(pager.page());
        if (!(pv instanceof GridLayout)) return false;
        GridLayout g = (GridLayout) pv;
        int[] loc = new int[2]; g.getLocationOnScreen(loc);
        for (int i = 0; i < g.getChildCount(); i++) {
            View c = g.getChildAt(i);
            if (x >= loc[0] + c.getLeft() && x <= loc[0] + c.getRight() && y >= loc[1] + c.getTop() && y <= loc[1] + c.getBottom()) return false;
        }
        return true;
    }

    /** Locks with DevicePolicyManager (the launcher is a device admin with only force-lock; see docs/restore.md). */
    private void lockScreen() {
        try {
            android.app.admin.DevicePolicyManager dpm = (android.app.admin.DevicePolicyManager) getSystemService(DEVICE_POLICY_SERVICE);
            if (dpm.isAdminActive(new ComponentName(this, AdminReceiver.class))) dpm.lockNow();
            else Toast.makeText(this, "Activa el administrador del launcher para bloquear con doble toque", Toast.LENGTH_LONG).show();
        } catch (Exception e) { android.util.Log.e("HomeTap", "lock failed", e); }
    }

    private void runSmart(Smart.Item it) {
        try {
            if (it.intent != null) { startActivity(it.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); return; }
            String sp = it.special == null ? "" : it.special;
            if (sp.startsWith("copy:")) {
                ((ClipboardManager) getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("resultado", sp.substring(5)));
                Toast.makeText(this, "Copiado: " + sp.substring(5), Toast.LENGTH_SHORT).show();
            } else if (sp.equals("torch")) {
                android.hardware.camera2.CameraManager cm = (android.hardware.camera2.CameraManager) getSystemService(CAMERA_SERVICE);
                torchOn = !torchOn;
                cm.setTorchMode(cm.getCameraIdList()[0], torchOn);
            } else if (sp.startsWith("note:")) {
                SharedPreferences prefs = getSharedPreferences("home", MODE_PRIVATE);
                prefs.edit().putString("notes", sp.substring(5).replace('\n', ' ') + "\n" + prefs.getString("notes", "")).apply();
                Toast.makeText(this, "Nota guardada en Hoy", Toast.LENGTH_SHORT).show();
                refreshToday();
            }
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo completar", Toast.LENGTH_SHORT).show();
        }
    }

    /** Round avatar with the contact's initial on a colour picked from the name. */
    private Bitmap avatar(String name, int s) {
        int[] palette = {0xFF6366F1, 0xFFEC4899, 0xFF14B8A6, 0xFFF59E0B, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEF4444};
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(palette[Math.abs(name.hashCode()) % palette.length]);
        c.drawCircle(s / 2f, s / 2f, s / 2f, p);
        p.setColor(Color.WHITE);
        p.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        p.setTextSize(s * 0.46f);
        p.setTextAlign(Paint.Align.CENTER);
        String l = name.isEmpty() ? "?" : name.substring(0, 1).toUpperCase();
        c.drawText(l, s / 2f, s / 2f + p.getTextSize() * 0.35f, p);
        return b;
    }

    private void openResult(Object[] r) {
        hideSearch();
        if (r[0] instanceof Smart.Item) { runSmart((Smart.Item) r[0]); return; }
        if (r.length == 1) { App a = (App) r[0]; launch(a, findViewById(android.R.id.content)); return; }
        try {
            startActivity(new Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode((String) r[1]))));
        } catch (Exception ignored) { }
    }

    private void expandShade() {
        try {
            Object sbm = getSystemService("statusbar");
            Class.forName("android.app.StatusBarManager").getMethod("expandNotificationsPanel").invoke(sbm);
        } catch (Exception ignored) { }
    }

    // ---- data -------------------------------------------------------------

    private static class App { String pkg, label, norm; volatile String doc = ""; ComponentName cn; ResolveInfo ri; List<App> kids; }

    private void reload() {
        new Thread(() -> {
            Intent q = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> ris = pm.queryIntentActivities(q, 0);
            Map<String, App> byPkg = new LinkedHashMap<>();
            for (ResolveInfo ri : ris) {
                String p = ri.activityInfo.packageName;
                if (p.equals(getPackageName()) || byPkg.containsKey(p)) continue;
                App a = new App();
                a.pkg = p;
                a.label = String.valueOf(ri.loadLabel(pm));
                a.cn = new ComponentName(p, ri.activityInfo.name);
                a.ri = ri;
                byPkg.put(p, a);
            }
            if (byPkg.containsKey("com.scratch.ioscamera")) byPkg.remove("org.cyanogenmod.snap");
            for (String hp : HIDDEN) { String own = OWN.get(hp); if (own != null && byPkg.containsKey(own)) byPkg.remove(hp); }
            List<App> dockApps = new ArrayList<>();
            final Set<String> dockFolderIds = new HashSet<>();
            String savedDock = getSharedPreferences("home", MODE_PRIVATE).getString("dock", "");
            if (!savedDock.isEmpty()) {
                List<String[]> fl = loadFolders();
                List<App> sd = new ArrayList<>();
                for (String tok : savedDock.split("\n")) {
                    if (tok.startsWith("folder:")) {
                        App f = dockFolder(tok, fl, byPkg);
                        if (f != null) { sd.add(f); if (f.kids != null) dockFolderIds.add(tok); }
                    } else { App a = byPkg.get(tok); if (a != null) sd.add(a); }
                }
                if (!sd.isEmpty()) {
                    for (App a : sd) { if (a.kids != null) for (App k : a.kids) byPkg.remove(k.pkg); else byPkg.remove(a.pkg); }
                    dockApps.addAll(sd);
                }
            }
            if (dockApps.isEmpty()) for (String[] cands : DOCK) {
                for (String c : cands) {
                    App a = byPkg.get(c);
                    if (a != null) { dockApps.add(a); byPkg.remove(c); break; }
                }
            }
            // hidden from the grid (user choice, plus AudioFX: it lives in Settings > Sound) but still found by the search
            final List<App> hiddenApps = new ArrayList<>();
            List<String> hide = new ArrayList<>(Arrays.asList(getSharedPreferences("home", MODE_PRIVATE).getString("hidden", "").split("\n")));
            hide.add("org.cyanogenmod.audiofx");
            for (String hp : hide) if (!hp.isEmpty()) { App ha = byPkg.remove(hp); if (ha != null) hiddenApps.add(ha); }
            List<App> grid = new ArrayList<>();
            for (String p : FIRST) { App a = byPkg.remove(p); if (a != null) grid.add(a); }
            List<App> rest = new ArrayList<>();
        List<App> tools = new ArrayList<>();
        for (App a : byPkg.values()) (TOOLS.contains(a.pkg) ? tools : rest).add(a);
            Collections.sort(rest, (x, y) -> x.label.compareToIgnoreCase(y.label));
            grid.addAll(rest);
        grid.addAll(tools);
            final List<App> flat = new ArrayList<>(grid);
            applyFolders(grid, dockFolderIds);
            applySavedOrder(grid);
            allApps = new ArrayList<>(); for (App a : dockApps) { if (a.kids != null) allApps.addAll(a.kids); else allApps.add(a); } allApps.addAll(flat); allApps.addAll(hiddenApps);
            // Publish usable icons before the expensive package metadata index is built.
            for (App a : allApps) { a.norm = Fuzzy.norm(a.label); a.doc = a.norm; }
            for (App a : allApps) icon(a);
            for (App a : dockApps) icon(a);
            for (App a : grid) icon(a);
            ui.post(() -> { if (!isDestroyed()) build(grid, dockApps); });
            Map<String, String> caps = AppIndex.capabilities(pm);
            for (App a : allApps) a.doc = AppIndex.doc(HomeActivity.this, pm, a.ri, caps);
            ui.post(() -> {
                if (!isDestroyed() && searchLayer != null && searchBox != null)
                    runSearch(searchBox.getText().toString().trim());
            });
        }).start();
    }

    private void build(List<App> grid, List<App> dockApps) {
        curGrid = grid; curDock = dockApps;
        int per = COLS * ROWS;
        int pages = Math.max(1, (grid.size() + per - 1) / per);
        int cur = pager.page();
        if (firstBuild) { cur = 1; firstBuild = false; }
        pager.clear();
        pager.addPage(todayPage(), w);
        for (int p = 0; p < pages; p++) {
            GridLayout g = new GridLayout(this);
            g.setColumnCount(COLS);
            g.setRowCount(ROWS);
            int cw = w / COLS, ch = gridH / ROWS;
            final int base = p * per;
            g.setOnDragListener((v, e) -> {
                if (e.getAction() == DragEvent.ACTION_DRAG_LOCATION) {
                    long now = SystemClock.uptimeMillis();
                    float ex = e.getX();
                    if (now - lastEdge > 700) {
                        int pg = pager.page();
                        if (ex < 36 * d && pg > 1) { lastEdge = now; pager.goTo(pg - 1); }
                        else if (ex > w - 36 * d && pg < dots.getChildCount() - 1) { lastEdge = now; pager.goTo(pg + 1); }
                    }
                    return true;
                }
                if (e.getAction() == DragEvent.ACTION_DROP && e.getLocalState() instanceof App) {
                    int col = Math.max(0, Math.min(COLS - 1, (int) (e.getX() / cw)));
                    int row = Math.max(0, Math.min(ROWS - 1, (int) (e.getY() / ch)));
                    float fx = (e.getX() - col * cw) / cw, fy = (e.getY() - row * ch) / ch;
                    boolean onIcon = Math.abs(fx - 0.5f) < 0.28f && fy < 66 * d / ch;
                    drop((App) e.getLocalState(), base + row * COLS + col, onIcon);
                }
                return true;
            });
            for (int i = p * per; i < Math.min(grid.size(), (p + 1) * per); i++) {
                View cell = cell(grid.get(i), true);
                GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
                lp.width = cw; lp.height = ch;
                g.addView(cell, lp);
            }
            pager.addPage(g, w);
        }
        dock.removeAllViews();
        for (App a : dockApps) {
            View cell = cell(a, false);
            dock.addView(cell, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f));
        }
        dock.setOnDragListener((v, e) -> {
            if (e.getAction() == DragEvent.ACTION_DROP && e.getLocalState() instanceof App && dock.getWidth() > 0) {
                int n = Math.max(1, dock.getChildCount());
                int slot = Math.max(0, Math.min(n - 1, (int) (e.getX() / (dock.getWidth() / (float) n))));
                float fx = e.getX() / (dock.getWidth() / (float) n) - slot;
                dropOnDock((App) e.getLocalState(), slot, Math.abs(fx - 0.5f) < 0.28f);
            }
            return true;
        });
        dots.removeAllViews();
        for (int p = 0; p < pages + 1; p++) {
            View dot = new View(this);
            GradientDrawable gd = new GradientDrawable();
            gd.setShape(GradientDrawable.OVAL);
            gd.setColor(dotColor);
            dot.setBackground(gd);
            dot.setAlpha(p == cur ? 1f : 0.4f);
            dots.addView(dot, new LinearLayout.LayoutParams((int) (7 * d), (int) (7 * d)) {{ leftMargin = rightMargin = (int) (4 * d); }});
        }
        pager.setOnPage(pg -> {
            for (int i = 0; i < dots.getChildCount(); i++) dots.getChildAt(i).setAlpha(i == pg ? 1f : 0.4f);
            if (pg == 0) popToday();
        });
        pager.setOnScroll(x -> { // the clock and date glide away more slowly than the page
            float k = Math.max(0, x - w);
            float a = 1f - Math.min(1f, k / w) * 0.7f;
            if (headTime != null) { headTime.setTranslationX(-k * 0.35f); headTime.setAlpha(a); }
            if (headDate != null) { headDate.setTranslationX(-k * 0.35f); headDate.setAlpha(a); }
        });
        final int fc = cur;
        pager.post(() -> pager.goToNow(fc));
        if (animateNext) { animateNext = false; pager.post(this::popCurrent); }
    }

    // ---- animations -----------------------------------------------------------------------------

    private void popCurrent() {
        View pv = pager.pageView(pager.page());
        if (pv instanceof GridLayout) popIn((ViewGroup) pv);
        for (int i = 0; i < dock.getChildCount(); i++) pop(dock.getChildAt(i), 120 + i * 40);
        if (pager.page() == 0) popToday();
    }

    private void popIn(ViewGroup page) {
        for (int i = 0; i < page.getChildCount(); i++) pop(page.getChildAt(i), i * 20);
    }

    private void pop(View c, long delay) {
        c.animate().cancel();
        c.setAlpha(0f); c.setScaleX(0.7f); c.setScaleY(0.7f); c.setTranslationY(10 * d);
        c.animate().alpha(1f).scaleX(1f).scaleY(1f).translationY(0f).setStartDelay(delay).setDuration(340)
                .setInterpolator(new android.view.animation.OvershootInterpolator(1.7f)).start();
    }

    private void popToday() {
        if (todayCol == null) return;
        for (int i = 0; i < todayCol.getChildCount(); i++) {
            View v = todayCol.getChildAt(i);
            v.animate().cancel();
            v.setAlpha(0f); v.setTranslationY(28 * d);
            v.animate().alpha(1f).translationY(0f).setStartDelay(i * 70L).setDuration(420)
                    .setInterpolator(new android.view.animation.DecelerateInterpolator(2f)).start();
        }
    }

    // ---- user order (long-press and drag an icon to a new slot) ---------------------------------

    private List<App> curGrid, curDock;
    private long lastEdge;

    private void applySavedOrder(List<App> grid) {
        String saved = getSharedPreferences("home", MODE_PRIVATE).getString("order", "");
        if (saved.isEmpty()) return;
        Map<String, App> by = new LinkedHashMap<>();
        for (App a : grid) by.put(a.pkg, a);
        List<App> out = new ArrayList<>();
        for (String p : saved.split("\n")) { App a = by.remove(p); if (a != null) out.add(a); }
        out.addAll(by.values()); // apps installed since: keep their default position order, at the end
        grid.clear(); grid.addAll(out);
    }

    private void moveApp(App a, int to) {
        List<App> g = curGrid;
        if (g == null) return;
        int from = g.indexOf(a);
        if (from < 0) return;
        to = Math.max(0, Math.min(g.size() - 1, to));
        if (to == from) return;
        g.remove(from);
        g.add(to, a);
        StringBuilder sb = new StringBuilder();
        for (App x : g) sb.append(x.pkg).append('\n');
        getSharedPreferences("home", MODE_PRIVATE).edit().putString("order", sb.toString()).apply();
        final List<App> gg = g, dd = curDock;
        ui.post(() -> build(gg, dd));
    }

    // ---- folders: drop an icon on the middle of another to group them ---------------------------

    private FrameLayout folderLayer;

    private Bitmap folderIcon(App f, int s) {
        Bitmap out = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(out);
        Path sq = squircle(s);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(night ? 0x59FFFFFF : 0x80FFFFFF);
        c.drawPath(sq, p);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(Math.max(1f, d * 0.75f));
        p.setColor(night ? 0x66FFFFFF : 0xCCFFFFFF);
        c.drawPath(sq, p);
        int m = Math.round(s * 0.12f), cell = Math.round(s * 0.36f), gap = Math.round(s * 0.08f);
        for (int i = 0; i < Math.min(4, f.kids.size()); i++) {
            Bitmap b = cache.get(f.kids.get(i).pkg);
            if (b == null) continue;
            int x = m + (i % 2) * (cell + gap), y = m + (i / 2) * (cell + gap);
            c.drawBitmap(b, null, new Rect(x, y, x + cell, y + cell), new Paint(Paint.FILTER_BITMAP_FLAG | Paint.ANTI_ALIAS_FLAG));
        }
        return out;
    }

    /** folders pref: one line per folder, "id|name|pkg,pkg". */
    private List<String[]> loadFolders() {
        List<String[]> out = new ArrayList<>();
        for (String line : getSharedPreferences("home", MODE_PRIVATE).getString("folders", "").split("\n")) {
            String[] t = line.split("\\|", 3);
            if (t.length == 3 && !t[0].isEmpty()) out.add(t);
        }
        return out;
    }

    private void saveFolders(List<String[]> fs) {
        StringBuilder sb = new StringBuilder();
        for (String[] t : fs) if (!t[2].isEmpty()) sb.append(t[0]).append('|').append(t[1]).append('|').append(t[2]).append('\n');
        getSharedPreferences("home", MODE_PRIVATE).edit().putString("folders", sb.toString()).apply();
    }

    private void saveOrder(List<String> ids) {
        StringBuilder sb = new StringBuilder();
        for (String x : ids) sb.append(x).append('\n');
        getSharedPreferences("home", MODE_PRIVATE).edit().putString("order", sb.toString()).apply();
    }

    private void applyFolders(List<App> grid, Set<String> keepIds) {
        SharedPreferences sp = getSharedPreferences("home", MODE_PRIVATE);
        if (!sp.getBoolean("seeded_tools", false)) { // first run: group the root/Xposed tools in one folder
            StringBuilder pk = new StringBuilder();
            int n = 0;
            for (App a : grid) if (TOOLS.contains(a.pkg)) { pk.append(n++ > 0 ? "," : "").append(a.pkg); }
            if (n >= 2) sp.edit().putString("folders", sp.getString("folders", "") + "folder:tools|Herramientas|" + pk + "\n").apply();
            sp.edit().putBoolean("seeded_tools", true).apply();
        }
        List<String[]> keep = new ArrayList<>();
        for (String[] t : loadFolders()) {
            List<App> members = new ArrayList<>();
            int first = Integer.MAX_VALUE;
            for (String p : t[2].split(",")) {
                for (int i = 0; i < grid.size(); i++) {
                    if (grid.get(i).kids == null && grid.get(i).pkg.equals(p)) { first = Math.min(first, i); members.add(grid.get(i)); break; }
                }
            }
            if (members.size() < 2) { if (keepIds.contains(t[0])) keep.add(t); continue; } // dissolved: the remaining member stays a plain icon
            grid.removeAll(members);
            App f = new App();
            f.pkg = t[0]; f.label = t[1]; f.kids = members; f.norm = Fuzzy.norm(f.label); f.doc = f.norm;
            grid.add(Math.min(first, grid.size()), f);
            StringBuilder pk = new StringBuilder();
            for (App m : members) pk.append(pk.length() > 0 ? "," : "").append(m.pkg);
            keep.add(new String[]{t[0], t[1], pk.toString()});
        }
        saveFolders(keep);
    }

    /** Folder token from the saved dock: a real folder, or its only remaining member, or null. */
    private App dockFolder(String id, List<String[]> fl, Map<String, App> byPkg) {
        for (String[] t : fl) {
            if (!t[0].equals(id)) continue;
            List<App> members = new ArrayList<>();
            for (String p : t[2].split(",")) { App a = byPkg.get(p); if (a != null) members.add(a); }
            if (members.size() >= 2) {
                App f = new App();
                f.pkg = id; f.label = t[1]; f.kids = members; f.norm = Fuzzy.norm(f.label); f.doc = f.norm;
                return f;
            }
            return members.isEmpty() ? null : members.get(0);
        }
        return null;
    }

    private void saveDock(List<String> tokens) {
        StringBuilder sb = new StringBuilder();
        for (String x : tokens) sb.append(x).append('\n');
        getSharedPreferences("home", MODE_PRIVATE).edit().putString("dock", sb.toString()).apply();
    }

    private List<String> dockTokens() {
        List<String> out = new ArrayList<>();
        if (curDock != null) for (App a : curDock) out.add(a.pkg);
        return out;
    }

    private List<String> gridTokens() {
        List<String> out = new ArrayList<>();
        if (curGrid != null) for (App a : curGrid) out.add(a.pkg);
        return out;
    }

    private void drop(App dragged, int idx, boolean onIcon) {
        List<App> g = curGrid;
        if (g == null) return;
        App target = idx < g.size() ? g.get(idx) : null;
        if (curDock != null && curDock.contains(dragged)) { dockToGrid(dragged, target); return; }
        if (target == dragged) { ui.post(() -> setEditing(!editing)); return; }
        if (onIcon && target != null && target != dragged && dragged.kids == null) {
            List<String> ids = new ArrayList<>();
            List<String[]> fs = loadFolders();
            if (target.kids != null) {
                for (String[] t : fs) if (t[0].equals(target.pkg)) t[2] = t[2] + "," + dragged.pkg;
                for (App x : g) if (x != dragged) ids.add(x.pkg);
            } else {
                String id = "folder:" + System.currentTimeMillis();
                fs.add(new String[]{id, "Carpeta", target.pkg + "," + dragged.pkg});
                for (App x : g) { if (x == dragged) continue; ids.add(x == target ? id : x.pkg); }
            }
            saveFolders(fs); saveOrder(ids);
            cache.remove(target.pkg);
            reload();
            return;
        }
        moveApp(dragged, idx);
    }

    private void openFolder(App f) {
        if (folderLayer != null) return;
        ViewGroup content = (ViewGroup) findViewById(android.R.id.content);
        folderLayer = new FrameLayout(this);
        folderLayer.setBackgroundColor(night ? 0xCC14123A : 0xCCF6F5FF);
        folderLayer.setOnClickListener(v -> closeFolder());
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        int pd = (int) (16 * d);
        panel.setPadding(pd, pd, pd, pd);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(night ? 0xFF2A2862 : 0xFFFFFFFF);
        bg.setStroke(Math.max(1, (int) d), boxStroke);
        bg.setCornerRadius(24 * d);
        panel.setBackground(bg);
        panel.setOnClickListener(v -> { });
        TextView title = new TextView(this);
        title.setText(f.label);
        title.setTextColor(labelColor);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        title.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        title.setGravity(Gravity.CENTER);
        title.setOnClickListener(v -> renameFolder(f));
        panel.addView(title, new LinearLayout.LayoutParams(-1, -2));
        TextView hint = new TextView(this);
        hint.setText("Toca el nombre para cambiarlo · mantén pulsado un icono para sacarlo");
        hint.setTextColor(subColor);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        hint.setGravity(Gravity.CENTER);
        panel.addView(hint, new LinearLayout.LayoutParams(-1, -2));
        GridLayout g = new GridLayout(this);
        g.setColumnCount(3);
        int cw = (w - (int) (32 * d) - 2 * pd) / 3;
        boolean e0 = editing; editing = false;
        for (final App kid : f.kids) {
            View c = cell(kid, true);
            c.setOnLongClickListener(v -> { v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS); removeFromFolder(f, kid); return true; });
            GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
            lp.width = cw; lp.height = (int) (84 * d);
            g.addView(c, lp);
        }
        editing = e0;
        panel.addView(g, new LinearLayout.LayoutParams(-2, -2) {{ topMargin = (int) (10 * d); gravity = Gravity.CENTER_HORIZONTAL; }});
        folderLayer.addView(panel, new FrameLayout.LayoutParams(w - (int) (32 * d), -2, Gravity.CENTER));
        content.addView(folderLayer, new FrameLayout.LayoutParams(-1, -1));
        folderLayer.setAlpha(0f);
        folderLayer.animate().alpha(1f).setDuration(160).start();
        folderPanel = panel;
        panel.setScaleX(0.6f); panel.setScaleY(0.6f); panel.setAlpha(0f);
        panel.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(300).setInterpolator(new android.view.animation.OvershootInterpolator(1.15f)).start();
    }

    /** A dock icon dropped on a grid icon: they swap places. */
    private void dockToGrid(App dragged, App target) {
        if (target == null || curGrid == null || curDock == null) return;
        int slot = curDock.indexOf(dragged);
        List<String> dk = dockTokens(), gr = gridTokens();
        dk.set(slot, target.pkg);
        gr.set(gr.indexOf(target.pkg), dragged.pkg);
        saveDock(dk); saveOrder(gr);
        reload();
    }

    /** Drop on a dock slot: reorder inside the dock, swap with a grid icon, or group into a (dock) folder. */
    private void dropOnDock(App dragged, int slot, boolean onIcon) {
        List<App> g = curGrid, dkl = curDock;
        if (g == null || dkl == null || slot >= dkl.size()) return;
        App target = dkl.get(slot);
        boolean fromDock = dkl.contains(dragged);
        List<String> dk = dockTokens(), gr = gridTokens();
        if (target == dragged) { ui.post(() -> setEditing(!editing)); return; }
        if (onIcon && dragged.kids == null) {
            List<String[]> fs = loadFolders();
            if (target.kids != null) {
                for (String[] t : fs) if (t[0].equals(target.pkg)) t[2] = t[2] + "," + dragged.pkg;
                dk.remove(dragged.pkg); gr.remove(dragged.pkg);
            } else if (target.kids == null) {
                String id = "folder:" + System.currentTimeMillis();
                fs.add(new String[]{id, "Carpeta", target.pkg + "," + dragged.pkg});
                dk.set(dk.indexOf(target.pkg), id); dk.remove(dragged.pkg); gr.remove(dragged.pkg);
            }
            saveFolders(fs); saveDock(dk); saveOrder(gr);
            cache.remove(target.pkg);
            reload();
            return;
        }
        if (fromDock) { int a = dk.indexOf(dragged.pkg); dk.set(a, target.pkg); dk.set(slot, dragged.pkg); saveDock(dk); }
        else if (g.contains(dragged)) { dk.set(slot, dragged.pkg); gr.set(gr.indexOf(dragged.pkg), target.pkg); saveDock(dk); saveOrder(gr); }
        else return;
        reload();
    }

    // ---- edit ("jiggle") mode: drop an icon where it was to toggle; × hides, dissolves or uninstalls --------

    private boolean editing;
    private TextView doneBtn, restoreBtn;

    private void setEditing(boolean on) {
        editing = on;
        if (doneBtn != null) doneBtn.setVisibility(on ? View.VISIBLE : View.GONE);
        if (restoreBtn != null) restoreBtn.setVisibility(on && !getSharedPreferences("home", MODE_PRIVATE).getString("hidden", "").isEmpty() ? View.VISIBLE : View.GONE);
        if (curGrid != null) build(curGrid, curDock);
    }

    private void wobble(View c) {
        final android.animation.ObjectAnimator an = android.animation.ObjectAnimator.ofFloat(c, "rotation", -1.6f, 1.6f);
        an.setDuration(110 + (int) (Math.random() * 40));
        an.setRepeatCount(android.animation.ValueAnimator.INFINITE);
        an.setRepeatMode(android.animation.ValueAnimator.REVERSE);
        an.setCurrentPlayTime((long) (Math.random() * 100));
        c.addOnAttachStateChangeListener(new View.OnAttachStateChangeListener() {
            @Override public void onViewAttachedToWindow(View v) { an.start(); }
            @Override public void onViewDetachedFromWindow(View v) { an.cancel(); v.setRotation(0f); }
        });
    }

    private TextView pill(String text) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setTextColor(labelColor);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        t.setPadding((int) (16 * d), (int) (6 * d), (int) (16 * d), (int) (6 * d));
        GradientDrawable g = new GradientDrawable();
        g.setColor(boxFill); g.setStroke(Math.max(1, (int) d), boxStroke); g.setCornerRadius(20 * d);
        t.setBackground(g);
        t.setVisibility(View.GONE);
        return t;
    }

    private void removeApp(App a) {
        if (a.kids != null) { // dissolve the folder: members go back to the grid
            List<String[]> fs = loadFolders();
            for (java.util.Iterator<String[]> it = fs.iterator(); it.hasNext();) if (it.next()[0].equals(a.pkg)) it.remove();
            saveFolders(fs);
            List<String> dk = dockTokens();
            if (dk.contains(a.pkg)) { dk.set(dk.indexOf(a.pkg), a.kids.get(0).pkg); saveDock(dk); }
            cache.remove(a.pkg);
            reload();
            return;
        }
        boolean own = a.pkg.startsWith("com.scratch.");
        boolean system = false;
        try { system = (pm.getApplicationInfo(a.pkg, 0).flags & ApplicationInfo.FLAG_SYSTEM) != 0; } catch (Exception e) { }
        if (!own && !system) { // ordinary user app: the system asks for confirmation
            startActivity(new Intent(Intent.ACTION_DELETE, Uri.parse("package:" + a.pkg)));
            return;
        }
        if (curDock != null && curDock.contains(a)) return; // keep the dock populated
        SharedPreferences sp = getSharedPreferences("home", MODE_PRIVATE);
        sp.edit().putString("hidden", sp.getString("hidden", "") + a.pkg + "\n").apply();
        if (restoreBtn != null && editing) restoreBtn.setVisibility(View.VISIBLE);
        reload();
    }

    // ---- Control Center: swipe up from the dock -------------------------------------------------------

    private FrameLayout ccLayer;
    private View ccPanel;

    private interface Flip { boolean flip(); }

    private View ccTile(String glyph, String caption, boolean on, final Flip f) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER_HORIZONTAL);
        final TextView c = new TextView(this);
        c.setText(glyph);
        c.setGravity(Gravity.CENTER);
        c.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        c.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        final Runnable style = new Runnable() {
            boolean state = on;
            @Override public void run() {
                GradientDrawable g = new GradientDrawable();
                g.setShape(GradientDrawable.OVAL);
                g.setColor(state ? (night ? 0xFF7BA7FF : 0xFF3B6BEA) : boxFill);
                g.setStroke(Math.max(1, (int) d), boxStroke);
                c.setBackground(g);
                c.setTextColor(state ? (night ? 0xFF14123A : Color.WHITE) : labelColor);
            }
        };
        style.run();
        final boolean[] st = {on};
        c.setOnClickListener(v -> {
            try { st[0] = f.flip(); } catch (Exception e) { Toast.makeText(this, "No disponible", Toast.LENGTH_SHORT).show(); return; }
            GradientDrawable g = new GradientDrawable();
            g.setShape(GradientDrawable.OVAL);
            g.setColor(st[0] ? (night ? 0xFF7BA7FF : 0xFF3B6BEA) : boxFill);
            g.setStroke(Math.max(1, (int) d), boxStroke);
            c.setBackground(g);
            c.setTextColor(st[0] ? (night ? 0xFF14123A : Color.WHITE) : labelColor);
            c.animate().cancel(); c.setScaleX(0.88f); c.setScaleY(0.88f);
            c.animate().scaleX(1f).scaleY(1f).setDuration(300).setInterpolator(new android.view.animation.OvershootInterpolator(3f)).start();
        });
        int s = (int) (58 * d);
        box.addView(c, new LinearLayout.LayoutParams(s, s));
        TextView t = new TextView(this);
        t.setText(caption); t.setTextColor(subColor); t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        t.setGravity(Gravity.CENTER);
        box.addView(t, new LinearLayout.LayoutParams(-2, -2) {{ topMargin = (int) (5 * d); }});
        return box;
    }

    private SeekBar ccSlider(int max, int progress, SeekBar.OnSeekBarChangeListener l) {
        SeekBar sb = new SeekBar(this);
        sb.setMax(max);
        sb.setProgress(progress);
        int accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        sb.setProgressTintList(android.content.res.ColorStateList.valueOf(accent));
        sb.setThumbTintList(android.content.res.ColorStateList.valueOf(accent));
        sb.setOnSeekBarChangeListener(l);
        return sb;
    }

    private TextView ccLabel(String t) {
        TextView v = new TextView(this);
        v.setText(t); v.setTextColor(subColor); v.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11); v.setLetterSpacing(0.12f);
        v.setPadding(0, (int) (12 * d), 0, (int) (2 * d));
        return v;
    }

    private void showControl() {
        if (ccLayer != null) return;
        ViewGroup content = (ViewGroup) findViewById(android.R.id.content);
        ccLayer = new FrameLayout(this);
        ccLayer.setBackgroundColor(night ? 0x88000000 : 0x5514123A);
        ccLayer.setOnClickListener(v -> hideControl());
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        int pd = (int) (18 * d);
        panel.setPadding(pd, (int) (10 * d), pd, pd);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(night ? 0xF51E1B4B : 0xF5F6F5FF);
        bg.setStroke(Math.max(1, (int) d), boxStroke);
        bg.setCornerRadii(new float[]{28 * d, 28 * d, 28 * d, 28 * d, 0, 0, 0, 0});
        panel.setBackground(bg);
        panel.setOnClickListener(v -> { });

        View grip = new View(this);
        GradientDrawable gg = new GradientDrawable(); gg.setColor(subColor); gg.setCornerRadius(3 * d);
        grip.setBackground(gg);
        panel.addView(grip, new LinearLayout.LayoutParams((int) (40 * d), (int) (4 * d)) {{ gravity = Gravity.CENTER_HORIZONTAL; bottomMargin = (int) (12 * d); }});

        final android.net.wifi.WifiManager wm = (android.net.wifi.WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        final android.bluetooth.BluetoothAdapter bt = android.bluetooth.BluetoothAdapter.getDefaultAdapter();
        LinearLayout tiles = new LinearLayout(this);
        tiles.setOrientation(LinearLayout.HORIZONTAL);
        tiles.addView(ccTile("Wi-Fi", "Wi-Fi", wm != null && wm.isWifiEnabled(), () -> { boolean on = !wm.isWifiEnabled(); wm.setWifiEnabled(on); return on; }), new LinearLayout.LayoutParams(0, -2, 1f));
        tiles.addView(ccTile("BT", "Bluetooth", bt != null && bt.isEnabled(), () -> { if (bt.isEnabled()) { bt.disable(); return false; } bt.enable(); return true; }), new LinearLayout.LayoutParams(0, -2, 1f));
        tiles.addView(ccTile("\u2600", "Linterna", torchOn, () -> { toggleTorch(); return torchOn; }), new LinearLayout.LayoutParams(0, -2, 1f));
        tiles.addView(ccTile("\u21bb", "Rotación", Settings.System.getInt(getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, 0) == 1, () -> {
            boolean on = Settings.System.getInt(getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, 0) != 1;
            Settings.System.putInt(getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, on ? 1 : 0);
            return on;
        }), new LinearLayout.LayoutParams(0, -2, 1f));
        panel.addView(tiles);

        panel.addView(ccLabel("BRILLO"));
        int br = 128;
        try { br = Settings.System.getInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS); } catch (Exception ignored) { }
        panel.addView(ccSlider(255, br, new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar sb, int p, boolean user) {
                if (!user) return;
                try {
                    Settings.System.putInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                    Settings.System.putInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, Math.max(8, p));
                    WindowManager.LayoutParams lp = getWindow().getAttributes();
                    lp.screenBrightness = Math.max(8, p) / 255f;
                    getWindow().setAttributes(lp);
                } catch (Exception e) { Toast.makeText(HomeActivity.this, "Sin permiso para cambiar el brillo", Toast.LENGTH_SHORT).show(); }
            }
            @Override public void onStartTrackingTouch(SeekBar sb) { }
            @Override public void onStopTrackingTouch(SeekBar sb) { }
        }));

        panel.addView(ccLabel("VOLUMEN"));
        final android.media.AudioManager am = (android.media.AudioManager) getSystemService(AUDIO_SERVICE);
        panel.addView(ccSlider(am.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC), am.getStreamVolume(android.media.AudioManager.STREAM_MUSIC), new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar sb, int p, boolean user) { if (user) am.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, p, 0); }
            @Override public void onStartTrackingTouch(SeekBar sb) { }
            @Override public void onStopTrackingTouch(SeekBar sb) { }
        }));

        LinearLayout quick = new LinearLayout(this);
        quick.setOrientation(LinearLayout.HORIZONTAL);
        quick.setPadding(0, (int) (14 * d), 0, 0);
        String[][] q = {{"Calc.", "com.scratch.ioscalc"}, {"Cámara", "com.scratch.ioscamera"}, {"Reloj", "com.scratch.iosclock"}, {"Grabadora", "com.scratch.iosrecorder"}};
        for (int i = 0; i < q.length; i++) {
            final String pk = q[i][1];
            quick.addView(quickButton(q[i][0], v -> { hideControl(); openPkg(pk); }), new LinearLayout.LayoutParams(0, -2, 1f) {{ rightMargin = (int) (4 * d); leftMargin = (int) (4 * d); }});
        }
        panel.addView(quick);

        ccPanel = panel;
        ccLayer.addView(panel, new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM));
        content.addView(ccLayer, new FrameLayout.LayoutParams(-1, -1));
        ccLayer.setAlpha(0f);
        ccLayer.animate().alpha(1f).setDuration(180).start();
        panel.setTranslationY(420 * d);
        panel.animate().translationY(0f).setDuration(320).setInterpolator(new android.view.animation.DecelerateInterpolator(2.2f)).start();
    }

    private void hideControl() {
        if (ccLayer == null) return;
        final FrameLayout layer = ccLayer;
        ccLayer = null;
        if (ccPanel != null) ccPanel.animate().translationY(420 * d).setDuration(220).start();
        layer.animate().alpha(0f).setDuration(220).withEndAction(() -> { if (layer.getParent() != null) ((ViewGroup) layer.getParent()).removeView(layer); }).start();
    }

    private void renameFolder(App f) {
        final EditText et = new EditText(this);
        et.setText(f.label);
        et.setSingleLine();
        et.setTextColor(0xFF14123A);
        et.setHintTextColor(0x8014123A);
        et.selectAll();
        new android.app.AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
            .setTitle("Nombre de la carpeta").setView(et)
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Guardar", (dlg, w2) -> {
                String n = et.getText().toString().replace("|", " ").replace("\n", " ").trim();
                if (n.isEmpty()) return;
                List<String[]> fs = loadFolders();
                for (String[] t : fs) if (t[0].equals(f.pkg)) t[1] = n;
                saveFolders(fs);
                closeFolder();
                reload();
            }).show();
    }

    private View folderPanel;

    private void closeFolder() {
        if (folderLayer == null) return;
        final FrameLayout layer = folderLayer;
        folderLayer = null; // reopening is allowed right away
        if (folderPanel != null) folderPanel.animate().scaleX(0.8f).scaleY(0.8f).alpha(0f).setDuration(160).start();
        layer.animate().alpha(0f).setDuration(170).withEndAction(() -> {
            if (layer.getParent() != null) ((ViewGroup) layer.getParent()).removeView(layer);
        }).start();
    }

    private void removeFromFolder(App f, App kid) {
        List<String[]> fs = loadFolders();
        for (String[] t : fs) {
            if (!t[0].equals(f.pkg)) continue;
            StringBuilder sb = new StringBuilder();
            for (String p : t[2].split(",")) if (!p.equals(kid.pkg)) sb.append(sb.length() > 0 ? "," : "").append(p);
            t[2] = sb.toString();
        }
        saveFolders(fs);
        cache.remove(f.pkg);
        closeFolder();
        reload();
    }

    private View cell(App a, boolean label) {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setGravity(label ? Gravity.CENTER_HORIZONTAL | Gravity.TOP : Gravity.CENTER);
        c.setPadding(0, label ? (int) (6 * d) : 0, 0, 0);
        ImageView iv = new ImageView(this);
        iv.setImageBitmap(cache.get(a.pkg));
        int s = (int) (54 * d);
        FrameLayout ic = new FrameLayout(this);
        ic.setElevation(night ? 3 * d : 4 * d);
        ic.setOutlineProvider(new ViewOutlineProvider() {
            @Override public void getOutline(View v, Outline o) { o.setRoundRect(0, 0, v.getWidth(), v.getHeight(), v.getWidth() * 0.225f); o.setAlpha(0.9f); }
        });
        ic.addView(iv, new FrameLayout.LayoutParams(s, s));
        if (editing) {
            TextView x = new TextView(this);
            x.setText("\u00d7");
            x.setTextColor(Color.WHITE);
            x.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
            x.setGravity(Gravity.CENTER);
            GradientDrawable xb = new GradientDrawable();
            xb.setShape(GradientDrawable.OVAL);
            xb.setColor(0xE6444466);
            xb.setStroke(Math.max(1, (int) d), 0xFFFFFFFF);
            x.setBackground(xb);
            x.setOnClickListener(v -> removeApp(a));
            ic.addView(x, new FrameLayout.LayoutParams((int) (22 * d), (int) (22 * d), Gravity.TOP | Gravity.LEFT));
        }
        c.addView(ic, new LinearLayout.LayoutParams(s, s));
        if (label) {
            TextView t = new TextView(this);
            t.setText(a.label);
            t.setTextColor(labelColor);
            if (night) t.setShadowLayer(3f, 0, 1, 0x80000000);
            t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
            t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            t.setSingleLine();
            t.setEllipsize(TextUtils_END);
            t.setGravity(Gravity.CENTER);
                        c.addView(t, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT) {{ topMargin = (int) (3 * d); }});
        }
        c.setOnClickListener(v -> { if (editing) return; if (a.kids != null) openFolder(a); else launch(a, iv); });
        if (editing) wobble(c);
        c.setOnLongClickListener(v -> {
            v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
            v.setAlpha(1f);
            return v.startDrag(null, new View.DragShadowBuilder(v), a, 0);
        });
        c.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) v.animate().cancel(); 
            if (e.getAction() == MotionEvent.ACTION_DOWN) v.animate().scaleX(0.9f).scaleY(0.9f).setStartDelay(0).setDuration(90).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
            else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL)
                v.animate().scaleX(1f).scaleY(1f).setStartDelay(0).setDuration(300).setInterpolator(new android.view.animation.OvershootInterpolator(3f)).start();
            return false;
        });
        return c;
    }

    private static final android.text.TextUtils.TruncateAt TextUtils_END = android.text.TextUtils.TruncateAt.END;

    private void launch(App a, View from) {
        usage.record(a.pkg, lastQuery);
        lastQuery = "";
        Intent i = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(a.cn).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        try {
            startActivity(i, ActivityOptions.makeScaleUpAnimation(from, 0, 0, from.getWidth(), from.getHeight()).toBundle());
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo abrir " + a.label, Toast.LENGTH_SHORT).show();
        }
    }

    // ---- icons ------------------------------------------------------------

    /** Colour tile: vertical gradient per app kind, hairline highlight border, white line glyph. */
    private void icon(App a) {
        if (cache.containsKey(a.pkg)) return;
        int s = (int) (54 * d);
        if (a.kids != null) { cache.put(a.pkg, folderIcon(a, s)); return; }
        Bitmap out = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(out);
        Path sq = squircle(s);
        String kind = Glyphs.kindFor(a.pkg);
        int[] g = Glyphs.gradientFor(kind, a.pkg);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new LinearGradient(0, 0, 0, s, g[0], g[1], Shader.TileMode.CLAMP));
        c.drawPath(sq, p);
        p.setShader(null);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(Math.max(1f, d * 0.75f));
        p.setColor(0x40FFFFFF);
        c.drawPath(sq, p);
        int gs = (int) (s * 0.60f), off = (s - gs) / 2;
        c.save();
        c.translate(off, off);
        if (kind != null) Glyphs.draw(c, kind, gs, Color.WHITE);
        else { c.translate(-off, -off); Glyphs.letter(c, a.label, s, Color.WHITE); }
        c.restore();
        cache.put(a.pkg, out);
    }

    private static Bitmap cameraIcon(int s) {
        Bitmap out = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(out);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new LinearGradient(0, 0, 0, s, 0xFF8E8E93, 0xFF3A3A3C, Shader.TileMode.CLAMP));
        c.drawPath(squircle(s), p);
        p.setShader(null);
        p.setColor(Color.WHITE);
        float u = s / 48f;
        c.drawRoundRect(new RectF(8 * u, 15 * u, 40 * u, 36 * u), 4 * u, 4 * u, p);
        c.drawRoundRect(new RectF(17 * u, 11 * u, 31 * u, 17 * u), 2 * u, 2 * u, p);
        p.setColor(0xFF3A3A3C);
        c.drawCircle(24 * u, 25.5f * u, 7.5f * u, p);
        p.setColor(Color.WHITE);
        c.drawCircle(24 * u, 25.5f * u, 5.5f * u, p);
        p.setColor(0xFF3A3A3C);
        c.drawCircle(24 * u, 25.5f * u, 3 * u, p);
        return out;
    }

    private static int dominant(Bitmap b) {
        Bitmap sm = Bitmap.createScaledBitmap(b, 12, 12, true);
        long r = 0, g = 0, bl = 0, n = 0;
        for (int y = 0; y < 12; y++) for (int x = 0; x < 12; x++) {
            int px = sm.getPixel(x, y);
            int al = Color.alpha(px);
            if (al < 128) continue;
            r += Color.red(px); g += Color.green(px); bl += Color.blue(px); n++;
        }
        sm.recycle();
        if (n == 0) return 0xFF2E9CF3;
        return Color.rgb((int) (r / n), (int) (g / n), (int) (bl / n));
    }

    private static int blend(int base, int tint, float a) {
        return Color.rgb(
            (int) (Color.red(base) * (1 - a) + Color.red(tint) * a),
            (int) (Color.green(base) * (1 - a) + Color.green(tint) * a),
            (int) (Color.blue(base) * (1 - a) + Color.blue(tint) * a));
    }

    /** Superellipse |x|^n + |y|^n = 1, n = 4.6 approximates the iOS icon shape. */
    private static Path squircle(int s) {
        Path p = new Path();
        float r = s / 2f, n = 4.6f;
        int steps = 72;
        for (int i = 0; i <= steps; i++) {
            double t = 2 * Math.PI * i / steps;
            double ct = Math.cos(t), st = Math.sin(t);
            float x = r + (float) (Math.signum(ct) * Math.pow(Math.abs(ct), 2 / n) * r);
            float y = r + (float) (Math.signum(st) * Math.pow(Math.abs(st), 2 / n) * r);
            if (i == 0) p.moveTo(x, y); else p.lineTo(x, y);
        }
        p.close();
        return p;
    }

    // ---- pager ------------------------------------------------------------

    interface OnPage { void on(int p); }

    /** Snap-to-page horizontal scroller without support-library dependencies. */
    private static class PagerView extends HorizontalScrollView {
        private final LinearLayout strip;
        private int pageW = 1, cur;
        private OnPage cb;
        private java.util.function.IntConsumer scrollCb;
        PagerView(Context c) {
            super(c);
            setHorizontalScrollBarEnabled(false);
            setOverScrollMode(OVER_SCROLL_NEVER);
            strip = new LinearLayout(c);
            addView(strip, new LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT));
        }
        void clear() { strip.removeAllViews(); }
        @Override protected void onScrollChanged(int l, int t, int ol, int ot) {
            super.onScrollChanged(l, t, ol, ot);
            if (scrollCb != null) scrollCb.accept(l);
            for (int i = 0; i < strip.getChildCount(); i++) {
                float off = Math.min(1f, Math.abs((l - i * pageW) / (float) pageW));
                View v = strip.getChildAt(i);
                v.setAlpha(1f - 0.55f * off);
                v.setScaleX(1f - 0.06f * off);
                v.setScaleY(1f - 0.06f * off);
            }
        }
        void addPage(View v, int w) { pageW = w; strip.addView(v, new LinearLayout.LayoutParams(w, ViewGroup.LayoutParams.MATCH_PARENT)); }
        void setOnPage(OnPage o) { cb = o; }
        void setOnScroll(java.util.function.IntConsumer c) { scrollCb = c; }
        View pageView(int i) { return i >= 0 && i < strip.getChildCount() ? strip.getChildAt(i) : null; }
        int page() { return cur; }
        void goTo(int p) { smoothScrollTo(p * pageW, 0); set(p); }
        void goToNow(int p) { p = Math.min(p, Math.max(0, strip.getChildCount() - 1)); scrollTo(p * pageW, 0); set(p); }
        private void set(int p) { if (p != cur || cb != null) { cur = p; if (cb != null) cb.on(p); } }
        @Override public boolean onTouchEvent(MotionEvent e) {
            boolean r = super.onTouchEvent(e);
            if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) {
                int n = Math.max(1, strip.getChildCount());
                int p = Math.max(0, Math.min(n - 1, Math.round(getScrollX() / (float) pageW)));
                post(() -> goTo(p));
            }
            return r;
        }
    }
}
