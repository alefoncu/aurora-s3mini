package com.scratch.ios7launcher;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ActivityOptions;
import android.content.*;
import android.content.pm.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
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
    private static final java.util.Set<String> HIDDEN = new java.util.HashSet<>(java.util.Arrays.asList("com.android.dialer", "com.android.gallery3d", "com.android.contacts", "com.android.deskclock", "com.android.calculator2"));
    private static final java.util.Map<String, String> OWN = new java.util.HashMap<>();
    static {
        OWN.put("com.android.dialer", "com.scratch.iosphone");
        OWN.put("com.android.gallery3d", "com.scratch.iosgallery");
        OWN.put("com.android.contacts", "com.scratch.ioscontacts");
        OWN.put("com.android.deskclock", "com.scratch.iosclock");
        OWN.put("com.android.calculator2", "com.scratch.ioscalc");
    }
    private static final String[] FIRST = {
        "com.scratch.ioscontacts", "com.android.settings", "com.scratch.iosgallery", "com.scratch.iosclock",
        "com.scratch.ioscalc", "com.google.android.calendar", "com.android.email", "org.cyanogenmod.snap",
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
        TextClock time = new TextClock(this);
        time.setFormat24Hour("HH:mm");
        time.setFormat12Hour("h:mm");
        time.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        time.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64);
        time.setShadowLayer(6f, 0, 2, 0x40000000);
        time.setTextColor(labelColor);
        time.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        time.setPadding((int) (24 * d), 0, 0, 0);
        root.addView(time, new FrameLayout.LayoutParams(w, (int) (72 * d), Gravity.TOP) {{ topMargin = statusH; }});
        TextClock date = new TextClock(this);
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

        setContentView(root);
        IntentFilter f = new IntentFilter();
        f.addAction(Intent.ACTION_PACKAGE_ADDED);
        f.addAction(Intent.ACTION_PACKAGE_REMOVED);
        f.addAction(Intent.ACTION_PACKAGE_REPLACED);
        f.addDataScheme("package");
        registerReceiver(pkgs, f);
        reload();
    }

    @Override protected void onResume() { super.onResume(); refreshToday(); }

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

    @Override public void onBackPressed() { if (folderLayer != null) closeFolder(); else if (searchLayer != null) hideSearch(); }

    private float downX, downY;
    private List<App> allApps = new ArrayList<>();
    private FrameLayout searchLayer;
    private EditText searchBox;
    private final List<Object[]> results = new ArrayList<>();   // {App} or {name, number}
    private BaseAdapter searchAdapter;
    private AppIndex.Usage usage;
    private String lastQuery = "";
    private boolean firstBuild = true;
    private TextView calView, batView, stoView, ramView;
    private View batBar, stoBar, ramBar;

    /** A clear downward swipe anywhere on the home screen opens the notification shade. */
    @Override
    public boolean dispatchTouchEvent(MotionEvent e) {
        if (e.getAction() == MotionEvent.ACTION_DOWN) { downX = e.getX(); downY = e.getY(); }
        else if (e.getAction() == MotionEvent.ACTION_UP) {
            float dy = e.getY() - downY, dx = e.getX() - downX;
            if (searchLayer == null && dy > 90 * d && Math.abs(dy) > 2 * Math.abs(dx) && downY < h * 0.6f) expandShade();
            else if (searchLayer == null && dy < -100 * d && Math.abs(dy) > 2 * Math.abs(dx) && downY > h * 0.25f) showSearch();
        }
        return super.dispatchTouchEvent(e);
    }

    // ---- today page ---------------------------------------------------------

    private View todayPage() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding((int) (18 * d), (int) (4 * d), (int) (18 * d), 0);
        calView = card(col, "PRÓXIMOS EVENTOS", 14, 40);
        LinearLayout st = cardBox(col, "ESTADO");
        batView = row(st, "Batería");
        batBar = lastBar;
        stoView = row(st, "Almacenamiento");
        stoBar = lastBar;
        ramView = row(st, "Memoria");
        ramBar = lastBar;
        refreshToday();
        return col;
    }

    private View lastBar;

    /** Label on the left, value on the right and a thin bar underneath. */
    private TextView row(LinearLayout box, String name) {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setPadding(0, (int) (8 * d), 0, 0);
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
        box.setPadding((int) (18 * d), (int) (12 * d), (int) (18 * d), (int) (14 * d));
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
        lp.bottomMargin = (int) (10 * d);
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
        searchLayer.animate().alpha(1f).setDuration(180).start();
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
        ((ViewGroup) searchLayer.getParent()).removeView(searchLayer);
        searchLayer = null;
        results.clear();
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
        if (r.length == 1) {
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
            byPkg.remove("com.scratch.iosmessages"); // stock Messages (themed by overlay) is the default; own app is send-only
            List<App> dockApps = new ArrayList<>();
            for (String[] cands : DOCK) {
                for (String c : cands) {
                    App a = byPkg.get(c);
                    if (a != null) { dockApps.add(a); byPkg.remove(c); break; }
                }
            }
            List<App> grid = new ArrayList<>();
            for (String p : FIRST) { App a = byPkg.remove(p); if (a != null) grid.add(a); }
            List<App> rest = new ArrayList<>();
        List<App> tools = new ArrayList<>();
        for (App a : byPkg.values()) (TOOLS.contains(a.pkg) ? tools : rest).add(a);
            Collections.sort(rest, (x, y) -> x.label.compareToIgnoreCase(y.label));
            grid.addAll(rest);
        grid.addAll(tools);
            final List<App> flat = new ArrayList<>(grid);
            applyFolders(grid);
            applySavedOrder(grid);
            allApps = new ArrayList<>(); allApps.addAll(dockApps); allApps.addAll(flat);
            // Publish usable icons before the expensive package metadata index is built.
            for (App a : allApps) { a.norm = Fuzzy.norm(a.label); a.doc = a.norm; }
            for (App a : dockApps) icon(a);
            for (App a : flat) icon(a);
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
        });
        final int fc = cur;
        pager.post(() -> pager.goToNow(fc));
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

    private void applyFolders(List<App> grid) {
        List<String[]> keep = new ArrayList<>();
        for (String[] t : loadFolders()) {
            List<App> members = new ArrayList<>();
            int first = Integer.MAX_VALUE;
            for (String p : t[2].split(",")) {
                for (int i = 0; i < grid.size(); i++) {
                    if (grid.get(i).kids == null && grid.get(i).pkg.equals(p)) { first = Math.min(first, i); members.add(grid.get(i)); break; }
                }
            }
            if (members.size() < 2) continue; // dissolved: the remaining member stays a plain icon
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

    private void drop(App dragged, int idx, boolean onIcon) {
        List<App> g = curGrid;
        if (g == null) return;
        App target = idx < g.size() ? g.get(idx) : null;
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
        for (final App kid : f.kids) {
            View c = cell(kid, true);
            c.setOnLongClickListener(v -> { v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS); removeFromFolder(f, kid); return true; });
            GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
            lp.width = cw; lp.height = (int) (84 * d);
            g.addView(c, lp);
        }
        panel.addView(g, new LinearLayout.LayoutParams(-2, -2) {{ topMargin = (int) (10 * d); gravity = Gravity.CENTER_HORIZONTAL; }});
        folderLayer.addView(panel, new FrameLayout.LayoutParams(w - (int) (32 * d), -2, Gravity.CENTER));
        content.addView(folderLayer, new FrameLayout.LayoutParams(-1, -1));
        folderLayer.setAlpha(0f);
        folderLayer.animate().alpha(1f).setDuration(150).start();
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

    private void closeFolder() {
        if (folderLayer == null) return;
        ((ViewGroup) folderLayer.getParent()).removeView(folderLayer);
        folderLayer = null;
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
        c.addView(iv, new LinearLayout.LayoutParams(s, s));
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
        c.setOnClickListener(v -> { if (a.kids != null) openFolder(a); else launch(a, iv); });
        if (label) c.setOnLongClickListener(v -> {
            v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
            v.setAlpha(1f);
            return v.startDrag(null, new View.DragShadowBuilder(v), a, 0);
        });
        c.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) v.setAlpha(0.6f);
            else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) v.setAlpha(1f);
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
