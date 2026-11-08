package com.scratch.iosphone;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.database.Cursor;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.CallLog;
import android.provider.ContactsContract;
import android.telephony.TelephonyManager;
import android.text.Editable;
import android.text.TextWatcher;
import android.text.format.DateUtils;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.util.*;

/** Own phone app: keypad, recent calls and contacts on glass over the wallpaper; follows system day/night. */
public class PhoneActivity extends Activity {
    private static final String[][] KEYS = {
        {"1", ""}, {"2", "ABC"}, {"3", "DEF"}, {"4", "GHI"}, {"5", "JKL"}, {"6", "MNO"},
        {"7", "PQRS"}, {"8", "TUV"}, {"9", "WXYZ"}, {"*", ""}, {"0", "+"}, {"#", ""}};

    private float d;
    private boolean night;
    private int text, text2, scrim, glass, glassStroke, accent, ok, danger;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private FrameLayout pages;
    private final View[] page = new View[3];       // 0 recents, 1 contacts, 2 keypad
    private IconView[] tabIcons = new IconView[3];
    private TextView[] tabLabels = new TextView[3];
    private int tab = 2;
    private final StringBuilder number = new StringBuilder();
    private TextView numberView, matchView;
    private BaseAdapter recentsAdapter, contactsAdapter;
    private final List<String[]> recents = new ArrayList<>();      // name, number, type, date
    private final List<String[]> contacts = new ArrayList<>();     // name, id, lookup
    private final List<String[]> shown = new ArrayList<>();
    private int statusH;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        text2 = night ? 0xB3FFFFFF : 0x9914123A;
        scrim = night ? 0x9914123A : 0x80F6F5FF;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        glassStroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        ok = night ? 0xFF34D399 : 0xFF10B981;
        danger = night ? 0xFFFB7185 : 0xFFDC2626;

        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        statusH = (int) (24 * d);

        FrameLayout root = new FrameLayout(this);
        View sc = new View(this);
        sc.setBackgroundColor(scrim);
        root.addView(sc, new FrameLayout.LayoutParams(-1, -1));

        pages = new FrameLayout(this);
        FrameLayout.LayoutParams pl = new FrameLayout.LayoutParams(-1, -1);
        pl.topMargin = statusH;
        pl.bottomMargin = (int) (80 * d);
        root.addView(pages, pl);

        root.addView(buildTabBar(), new FrameLayout.LayoutParams(-1, (int) (60 * d), Gravity.BOTTOM) {{
            leftMargin = rightMargin = (int) (14 * d); bottomMargin = (int) (14 * d); }});
        setContentView(root);

        handleIntent(getIntent());
        selectTab(tab);
    }

    @Override
    protected void onNewIntent(Intent i) { super.onNewIntent(i); handleIntent(i); selectTab(tab); }

    @Override
    public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }

    @Override
    protected void onResume() { super.onResume(); if (page[0] != null) loadRecents(); }

    private void handleIntent(Intent i) {
        if (i == null) return;
        Uri data = i.getData();
        if (data != null && "tel".equals(data.getScheme())) {
            number.setLength(0);
            number.append(data.getSchemeSpecificPart().replaceAll("[^0-9+*#]", ""));
            tab = 2;
        }
    }

    // ---- tab bar -------------------------------------------------------------

    private View buildTabBar() {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        GradientDrawable g = new GradientDrawable();
        g.setColor(night ? 0x3314123A : 0xB3FFFFFF);
        g.setStroke(Math.max(1, (int) d), glassStroke);
        g.setCornerRadius(30 * d);
        bar.setBackground(g);
        String[] names = {"Recientes", "Contactos", "Teclado"};
        String[] kinds = {"clock", "person", "keypad"};
        for (int i = 0; i < 3; i++) {
            final int idx = i;
            LinearLayout cell = new LinearLayout(this);
            cell.setOrientation(LinearLayout.VERTICAL);
            cell.setGravity(Gravity.CENTER);
            tabIcons[i] = new IconView(this, kinds[i], text2, 2f);
            tabIcons[i].setClickable(false);
            cell.addView(tabIcons[i], new LinearLayout.LayoutParams((int) (24 * d), (int) (24 * d)));
            TextView t = new TextView(this);
            t.setText(names[i]);
            t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10);
            t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            t.setGravity(Gravity.CENTER);
            tabLabels[i] = t;
            cell.addView(t);
            cell.setOnClickListener(v -> selectTab(idx));
            bar.addView(cell, new LinearLayout.LayoutParams(0, -1, 1f));
        }
        return bar;
    }

    private void selectTab(int i) {
        tab = i;
        for (int k = 0; k < 3; k++) {
            boolean on = k == i;
            tabIcons[k].setColor(on ? accent : text2);
            tabLabels[k].setTextColor(on ? accent : text2);
        }
        if (page[i] == null) {
            page[i] = i == 0 ? buildRecents() : i == 1 ? buildContacts() : buildKeypad();
            pages.addView(page[i], new FrameLayout.LayoutParams(-1, -1));
        }
        for (int k = 0; k < 3; k++) if (page[k] != null) page[k].setVisibility(k == i ? View.VISIBLE : View.GONE);
        if (i == 0) loadRecents();
        if (i == 1) loadContacts();
        if (i == 2) refreshNumber();
    }

    // ---- keypad ----------------------------------------------------------------

    private View buildKeypad() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL);
        TelephonyManager tm = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
        if (tm != null && tm.getSimState() == TelephonyManager.SIM_STATE_ABSENT) {
            TextView sim = new TextView(this);
            sim.setText("Sin tarjeta SIM · las llamadas no están disponibles");
            sim.setTextColor(danger);
            sim.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
            sim.setGravity(Gravity.CENTER);
            col.addView(sim, new LinearLayout.LayoutParams(-1, (int) (18 * d)));
        } else {
            col.addView(new View(this), new LinearLayout.LayoutParams(-1, (int) (18 * d)));
        }
        numberView = new TextView(this);
        numberView.setTextColor(text);
        numberView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        numberView.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        numberView.setGravity(Gravity.CENTER);
        numberView.setSingleLine();
        col.addView(numberView, new LinearLayout.LayoutParams(-1, (int) (48 * d)));
        matchView = new TextView(this);
        matchView.setTextColor(text2);
        matchView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        matchView.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        matchView.setGravity(Gravity.CENTER);
        matchView.setSingleLine();
        col.addView(matchView, new LinearLayout.LayoutParams(-1, (int) (20 * d)));
        col.addView(new View(this), new LinearLayout.LayoutParams(-1, (int) (2 * d)));

        int sz = (int) (54 * d), gap = (int) (5 * d);
        for (int r = 0; r < 4; r++) {
            LinearLayout row = new LinearLayout(this);
            row.setGravity(Gravity.CENTER);
            for (int c = 0; c < 3; c++) {
                final String[] k = KEYS[r * 3 + c];
                KeyView kv = new KeyView(this, k[0], k[1]);
                kv.setOnClickListener(v -> { number.append(k[0]); refreshNumber(); });
                if (k[0].equals("0")) kv.setOnLongClickListener(v -> { number.append('+'); refreshNumber(); return true; });
                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(sz, sz);
                lp.setMargins(gap * 3, gap, gap * 3, gap);
                row.addView(kv, lp);
            }
            col.addView(row, new LinearLayout.LayoutParams(-2, -2));
        }
        LinearLayout last = new LinearLayout(this);
        last.setGravity(Gravity.CENTER);
        last.addView(new View(this), new LinearLayout.LayoutParams(sz, sz) {{ setMargins(gap * 3, gap, gap * 3, gap); }});
        CallButton call = new CallButton(this);
        call.setOnClickListener(v -> placeCall(number.toString()));
        last.addView(call, new LinearLayout.LayoutParams(sz, sz) {{ setMargins(gap * 3, gap, gap * 3, gap); }});
        IconView del = new IconView(this, "backspace", text2, 2f);
        del.setPadding((int) (18 * d), (int) (18 * d), (int) (18 * d), (int) (18 * d));
        del.setOnClickListener(v -> { if (number.length() > 0) { number.setLength(number.length() - 1); refreshNumber(); } });
        del.setOnLongClickListener(v -> { number.setLength(0); refreshNumber(); return true; });
        last.addView(del, new LinearLayout.LayoutParams(sz, sz) {{ setMargins(gap * 3, gap, gap * 3, gap); }});
        col.addView(last, new LinearLayout.LayoutParams(-2, -2));
        return col;
    }

    private void refreshNumber() {
        if (numberView == null) return;
        numberView.setText(number.toString());
        matchView.setText("");
        final String n = number.toString();
        if (n.length() < 3) return;
        new Thread(() -> {
            String name = null;
            Cursor c = null;
            try {
                c = getContentResolver().query(Uri.withAppendedPath(ContactsContract.CommonDataKinds.Phone.CONTENT_FILTER_URI, Uri.encode(n)),
                        new String[]{ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME}, null, null, null);
                if (c != null && c.moveToFirst()) name = c.getString(0);
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            final String m = name;
            ui.post(() -> { if (n.contentEquals(number) && matchView != null && m != null) matchView.setText(m); });
        }).start();
    }

    private void placeCall(String n) {
        if (n.isEmpty()) {
            n = CallLog.Calls.getLastOutgoingCall(this);
            if (n == null || n.isEmpty()) return;
            number.setLength(0); number.append(n); refreshNumber();
        }
        try {
            startActivity(new Intent(Intent.ACTION_CALL, Uri.parse("tel:" + Uri.encode(n))));
        } catch (Exception e) {
            Toast.makeText(this, "No se puede llamar", Toast.LENGTH_SHORT).show();
        }
    }

    // ---- recents -----------------------------------------------------------------

    private View buildRecents() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.addView(title("Recientes"));
        ListView list = new ListView(this);
        list.setDivider(null);
        list.setSelector(new android.graphics.drawable.ColorDrawable(night ? 0x1FFFFFFF : 0x1F14123A));
        recentsAdapter = new BaseAdapter() {
            @Override public int getCount() { return recents.size(); }
            @Override public Object getItem(int i) { return recents.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public View getView(int i, View v, ViewGroup p) { return recentRow(recents.get(i)); }
        };
        list.setAdapter(recentsAdapter);
        list.setOnItemClickListener((p, v, i, id) -> placeCall(recents.get(i)[1]));
        TextView empty = new TextView(this);
        empty.setText("Sin llamadas recientes");
        empty.setTextColor(text2);
        empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        empty.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        empty.setGravity(Gravity.CENTER);
        FrameLayout box = new FrameLayout(this);
        box.addView(empty, new FrameLayout.LayoutParams(-1, -1));
        box.addView(list, new FrameLayout.LayoutParams(-1, -1));
        list.setEmptyView(empty);
        col.addView(box, new LinearLayout.LayoutParams(-1, 0, 1f));
        return col;
    }

    private View recentRow(String[] r) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding((int) (20 * d), (int) (10 * d), (int) (20 * d), (int) (10 * d));
        int type = Integer.parseInt(r[2]);
        boolean missed = type == CallLog.Calls.MISSED_TYPE || type == CallLog.Calls.REJECTED_TYPE;
        String kind = type == CallLog.Calls.OUTGOING_TYPE ? "out" : missed ? "missed" : "in";
        int col = missed ? danger : type == CallLog.Calls.INCOMING_TYPE ? ok : text2;
        row.addView(new IconView(this, kind, col, 2f), new LinearLayout.LayoutParams((int) (22 * d), (int) (22 * d)));
        LinearLayout t = new LinearLayout(this);
        t.setOrientation(LinearLayout.VERTICAL);
        TextView name = new TextView(this);
        name.setText(r[0] != null && !r[0].isEmpty() ? r[0] : r[1]);
        name.setTextColor(missed ? danger : text);
        name.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        name.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        name.setSingleLine();
        TextView sub = new TextView(this);
        sub.setText(r[1] + " · " + DateUtils.getRelativeTimeSpanString(Long.parseLong(r[3]), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS));
        sub.setTextColor(text2);
        sub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        sub.setSingleLine();
        t.addView(name);
        t.addView(sub);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1f);
        lp.leftMargin = (int) (16 * d);
        row.addView(t, lp);
        return row;
    }

    private void loadRecents() {
        new Thread(() -> {
            List<String[]> out = new ArrayList<>();
            Cursor c = null;
            try {
                c = getContentResolver().query(CallLog.Calls.CONTENT_URI,
                        new String[]{CallLog.Calls.CACHED_NAME, CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE},
                        null, null, CallLog.Calls.DATE + " DESC LIMIT 100");
                while (c != null && c.moveToNext()) out.add(new String[]{c.getString(0), c.getString(1), String.valueOf(c.getInt(2)), String.valueOf(c.getLong(3))});
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            ui.post(() -> {
                recents.clear(); recents.addAll(out);
                if (recentsAdapter != null) recentsAdapter.notifyDataSetChanged();
            });
        }).start();
    }

    // ---- contacts ----------------------------------------------------------------

    private View buildContacts() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.addView(title("Contactos"));
        EditText search = new EditText(this);
        search.setHint("Buscar");
        search.setHintTextColor(text2);
        search.setTextColor(text);
        search.setSingleLine();
        search.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        search.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        search.setPadding((int) (18 * d), (int) (10 * d), (int) (18 * d), (int) (10 * d));
        GradientDrawable g = new GradientDrawable();
        g.setColor(glass);
        g.setStroke(Math.max(1, (int) d), glassStroke);
        g.setCornerRadius(24 * d);
        search.setBackground(g);
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(-1, -2);
        sp.setMargins((int) (16 * d), 0, (int) (16 * d), (int) (6 * d));
        col.addView(search, sp);
        ListView list = new ListView(this);
        list.setDivider(null);
        list.setSelector(new android.graphics.drawable.ColorDrawable(night ? 0x1FFFFFFF : 0x1F14123A));
        contactsAdapter = new BaseAdapter() {
            @Override public int getCount() { return shown.size(); }
            @Override public Object getItem(int i) { return shown.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public View getView(int i, View v, ViewGroup p) { return contactRow(shown.get(i)); }
        };
        list.setAdapter(contactsAdapter);
        list.setOnItemClickListener((p, v, i, id) -> callContact(shown.get(i)));
        list.setOnItemLongClickListener((p, v, i, id) -> {
            String[] c = shown.get(i);
            startActivity(new Intent(Intent.ACTION_VIEW, ContactsContract.Contacts.getLookupUri(Long.parseLong(c[1]), c[2])));
            return true;
        });
        col.addView(list, new LinearLayout.LayoutParams(-1, 0, 1f));
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) { filterContacts(s.toString().trim()); }
            @Override public void afterTextChanged(Editable e) { }
        });
        return col;
    }

    private void loadContacts() {
        if (!contacts.isEmpty()) return;
        new Thread(() -> {
            List<String[]> out = new ArrayList<>();
            Cursor c = null;
            try {
                c = getContentResolver().query(ContactsContract.Contacts.CONTENT_URI,
                        new String[]{ContactsContract.Contacts.DISPLAY_NAME, ContactsContract.Contacts._ID, ContactsContract.Contacts.LOOKUP_KEY},
                        ContactsContract.Contacts.HAS_PHONE_NUMBER + "=1", null, ContactsContract.Contacts.DISPLAY_NAME + " COLLATE LOCALIZED ASC");
                while (c != null && c.moveToNext()) out.add(new String[]{c.getString(0), String.valueOf(c.getLong(1)), c.getString(2)});
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            ui.post(() -> { contacts.clear(); contacts.addAll(out); filterContacts(""); });
        }).start();
    }

    private void filterContacts(String q) {
        shown.clear();
        final String nq = Fuzzy.norm(q);
        if (nq.isEmpty()) shown.addAll(contacts);
        else {
            final List<String[]> hits = new ArrayList<>();
            final Map<String[], Integer> sc = new HashMap<>();
            for (String[] c : contacts) {
                int s2 = Fuzzy.score(nq, Fuzzy.norm(c[0]));
                if (s2 > 0) { hits.add(c); sc.put(c, s2); }
            }
            Collections.sort(hits, (a, b) -> sc.get(b) - sc.get(a));
            shown.addAll(hits);
        }
        if (contactsAdapter != null) contactsAdapter.notifyDataSetChanged();
    }

    private View contactRow(String[] c) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding((int) (20 * d), (int) (8 * d), (int) (20 * d), (int) (8 * d));
        ImageView iv = new ImageView(this);
        int s = (int) (40 * d);
        iv.setImageBitmap(avatar(c[0] == null ? "?" : c[0], s));
        row.addView(iv, new LinearLayout.LayoutParams(s, s));
        TextView t = new TextView(this);
        t.setText(c[0]);
        t.setTextColor(text);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        t.setSingleLine();
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1f);
        lp.leftMargin = (int) (16 * d);
        row.addView(t, lp);
        return row;
    }

    private void callContact(String[] c) {
        Cursor cur = null;
        String num = null;
        try {
            cur = getContentResolver().query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    new String[]{ContactsContract.CommonDataKinds.Phone.NUMBER},
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID + "=?", new String[]{c[1]}, null);
            if (cur != null && cur.moveToFirst()) num = cur.getString(0);
        } catch (Exception ignored) { } finally { if (cur != null) cur.close(); }
        if (num != null) placeCall(num);
    }

    // ---- shared bits ---------------------------------------------------------------

    private View title(String s) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(text);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 32);
        t.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        t.setPadding((int) (22 * d), (int) (14 * d), 0, (int) (8 * d));
        return t;
    }

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
        c.drawText(name.isEmpty() ? "?" : name.substring(0, 1).toUpperCase(), s / 2f, s / 2f + p.getTextSize() * 0.35f, p);
        return b;
    }

    /** Glass circle with a digit and its letters. */
    private class KeyView extends View {
        private final String digit, letters;
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        KeyView(Context c, String digit, String letters) { super(c); this.digit = digit; this.letters = letters; setClickable(true); }
        @Override protected void onDraw(Canvas cv) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f, r = getWidth() / 2f - d;
            p.setStyle(Paint.Style.FILL);
            p.setColor(isPressed() ? (night ? 0x4DFFFFFF : 0xE6FFFFFF) : glass);
            cv.drawCircle(cx, cy, r, p);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(Math.max(1f, d * 0.75f));
            p.setColor(glassStroke);
            cv.drawCircle(cx, cy, r, p);
            p.setStyle(Paint.Style.FILL);
            p.setTextAlign(Paint.Align.CENTER);
            p.setColor(text);
            p.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            p.setTextSize(d * 26);
            cv.drawText(digit, cx, letters.isEmpty() ? cy + d * 9 : cy + d * 4, p);
            if (!letters.isEmpty()) {
                p.setColor(text2);
                p.setTextSize(d * 8);
                cv.drawText(letters, cx, cy + d * 17, p);
            }
        }
        @Override public void setPressed(boolean pr) { super.setPressed(pr); invalidate(); }
    }

    private class CallButton extends View {
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        CallButton(Context c) { super(c); setClickable(true); }
        @Override protected void onDraw(Canvas cv) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f, r = getWidth() / 2f - d;
            p.setColor(isPressed() ? 0xFF059669 : ok);
            cv.drawCircle(cx, cy, r, p);
            cv.save();
            cv.translate(cx - r * 0.5f, cy - r * 0.5f);
            Icons.draw(cv, "phone", r, Color.WHITE, 2.4f);
            cv.restore();
        }
        @Override public void setPressed(boolean pr) { super.setPressed(pr); invalidate(); }
    }

    private static class IconView extends View {
        private final String kind;
        private int color;
        private final float stroke;
        IconView(Context c, String kind, int color, float stroke) { super(c); this.kind = kind; this.color = color; this.stroke = stroke; setClickable(true); }
        void setColor(int c) { color = c; invalidate(); }
        @Override protected void onDraw(Canvas cv) {
            float s = Math.min(getWidth() - getPaddingLeft() - getPaddingRight(), getHeight() - getPaddingTop() - getPaddingBottom());
            cv.save();
            cv.translate((getWidth() - s) / 2f, (getHeight() - s) / 2f);
            Icons.draw(cv, kind, s, color, stroke);
            cv.restore();
        }
    }

    /** Aurora exit transition (res/anim/app_exit): soft zoom-out and fade instead of the ROM default. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
