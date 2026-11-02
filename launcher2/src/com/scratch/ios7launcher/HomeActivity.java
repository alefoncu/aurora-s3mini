package com.scratch.ios7launcher;

import android.app.Activity;
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
        {"com.android.dialer"},
        {"com.android.messaging"},
        {"com.scratch.ioscamera", "org.cyanogenmod.snap"},
        {"org.lineageos.jelly", "com.android.chrome"},
    };
    private static final java.util.Set<String> TOOLS = new java.util.HashSet<>(java.util.Arrays.asList(
        "com.topjohnwu.magisk", "de.robv.android.xposed.installer", "com.ceco.nougat.gravitybox"));
    private static final String[] FIRST = {
        "com.android.contacts", "com.android.settings", "com.android.gallery3d", "com.android.deskclock",
        "com.android.calculator2", "com.google.android.calendar", "com.android.email", "org.cyanogenmod.snap",
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
        night = (getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK)
                == android.content.res.Configuration.UI_MODE_NIGHT_YES;
        labelColor = night ? Color.WHITE : 0xFF14123A;
        subColor = night ? 0xB3FFFFFF : 0x9914123A;
        dockFill = night ? 0x2EFFFFFF : 0x66FFFFFF;
        dockStroke = night ? 0x38FFFFFF : 0xB3FFFFFF;
        scrim = night ? 0xEB14123A : 0xEBF6F5FF;
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
        time.setTextColor(Color.WHITE);
        time.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        time.setPadding((int) (24 * d), 0, 0, 0);
        root.addView(time, new FrameLayout.LayoutParams(w, (int) (72 * d), Gravity.TOP) {{ topMargin = statusH; }});
        TextClock date = new TextClock(this);
        date.setFormat24Hour("EEEE, d 'de' MMMM");
        date.setFormat12Hour("EEEE, d 'de' MMMM");
        date.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        date.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        date.setTextColor(0xBFFFFFFF);
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

    @Override protected void onDestroy() { unregisterReceiver(pkgs); super.onDestroy(); }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        if (pager != null) pager.goTo(0);
    }

    @Override
    public void onConfigurationChanged(android.content.res.Configuration c) {
        super.onConfigurationChanged(c);
        recreate();
    }

    @Override public void onBackPressed() { if (searchLayer != null) hideSearch(); }

    private float downX, downY;
    private List<App> allApps = new ArrayList<>();
    private FrameLayout searchLayer;
    private EditText searchBox;
    private final List<Object[]> results = new ArrayList<>();   // {App} or {name, number}
    private BaseAdapter searchAdapter;

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
        content.addView(searchLayer, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        searchLayer.setAlpha(0f);
        searchLayer.animate().alpha(1f).setDuration(180).start();
        searchBox.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence c, int a, int b, int n) { }
            @Override public void onTextChanged(CharSequence c, int a, int b, int n) { runSearch(c.toString().trim()); }
            @Override public void afterTextChanged(android.text.Editable e) { }
        });
        searchBox.requestFocus();
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

    private void runSearch(String q) {
        results.clear();
        if (!q.isEmpty()) {
            String ql = q.toLowerCase();
            for (App a : allApps) if (a.label.toLowerCase().contains(ql)) results.add(new Object[]{a});
            if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                android.database.Cursor c = null;
                try {
                    c = getContentResolver().query(android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            new String[]{android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                    android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER},
                            android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " LIKE ?",
                            new String[]{"%" + q + "%"},
                            android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC LIMIT 6");
                    Set<String> seen = new HashSet<>();
                    while (c != null && c.moveToNext()) if (seen.add(c.getString(0))) results.add(new Object[]{c.getString(0), c.getString(1)});
                } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            }
        }
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

    private static class App { String pkg, label; ComponentName cn; }

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
                byPkg.put(p, a);
            }
            if (byPkg.containsKey("com.scratch.ioscamera")) byPkg.remove("org.cyanogenmod.snap");
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
            allApps = new ArrayList<>(); allApps.addAll(dockApps); allApps.addAll(grid);
            for (App a : dockApps) icon(a);
            for (App a : grid) icon(a);
            ui.post(() -> build(grid, dockApps));
        }).start();
    }

    private void build(List<App> grid, List<App> dockApps) {
        int per = COLS * ROWS;
        int pages = Math.max(1, (grid.size() + per - 1) / per);
        int cur = pager.page();
        pager.clear();
        for (int p = 0; p < pages; p++) {
            GridLayout g = new GridLayout(this);
            g.setColumnCount(COLS);
            g.setRowCount(ROWS);
            int cw = w / COLS, ch = gridH / ROWS;
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
        for (int p = 0; p < pages && pages > 1; p++) {
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
        pager.post(() -> pager.goToNow(cur));
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
        c.setOnClickListener(v -> launch(a, iv));
        c.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) v.setAlpha(0.6f);
            else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) v.setAlpha(1f);
            return false;
        });
        return c;
    }

    private static final android.text.TextUtils.TruncateAt TextUtils_END = android.text.TextUtils.TruncateAt.END;

    private void launch(App a, View from) {
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
