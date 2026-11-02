package com.scratch.ioscontacts;

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
import android.provider.ContactsContract;
import android.provider.ContactsContract.CommonDataKinds;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.util.*;

/** Own Contacts app: sectioned list with search and a detail page (call, SMS, email); edit/new through the stock editor. */
public class ContactsActivity extends Activity {
    private float d;
    private boolean night;
    private int text, text2, scrim, glass, glassStroke, accent, ok;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private FrameLayout stage;
    private View listPage, detailPage;
    private BaseAdapter adapter;
    private final List<Row> all = new ArrayList<>();       // contacts, sorted
    private final List<Row> shown = new ArrayList<>();     // contacts and letter headers
    private EditText search;
    private TextView count;
    private Row current;
    private LinearLayout detailBody;
    private ImageView detailAvatar;
    private TextView detailName, detailSub;

    private static class Row { long id; String lookup; String name; boolean header; boolean star; int score; }

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
        ok = night ? 0xFF34D399 : 0xFF10B981;

        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        FrameLayout root = new FrameLayout(this);
        View sc = new View(this);
        sc.setBackgroundColor(scrim);
        root.addView(sc, new FrameLayout.LayoutParams(-1, -1));
        stage = new FrameLayout(this);
        stage.setPadding(0, (int) (24 * d), 0, 0);
        root.addView(stage, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
        listPage = buildList();
        detailPage = buildDetail();
        stage.addView(listPage, new FrameLayout.LayoutParams(-1, -1));
        stage.addView(detailPage, new FrameLayout.LayoutParams(-1, -1));
        detailPage.setVisibility(View.GONE);
        stage.setFocusableInTouchMode(true);
        stage.requestFocus();
    }

    @Override protected void onResume() { super.onResume(); load(); if (current != null) showDetail(current); }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }
    @Override public void onBackPressed() { if (detailPage.getVisibility() == View.VISIBLE) closeDetail(); else super.onBackPressed(); }

    // ---- list ------------------------------------------------------------------

    private View buildList() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        LinearLayout head = new LinearLayout(this);
        head.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout titles = new LinearLayout(this);
        titles.setOrientation(LinearLayout.VERTICAL);
        titles.setPadding((int) (22 * d), (int) (12 * d), 0, (int) (4 * d));
        TextView t = new TextView(this);
        t.setText("Contactos");
        t.setTextColor(text);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        t.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        titles.addView(t);
        count = new TextView(this);
        count.setTextColor(text2);
        count.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        count.setPadding((int) (2 * d), 0, 0, 0);
        titles.addView(count);
        head.addView(titles, new LinearLayout.LayoutParams(0, -2, 1f));
        View plus = glyph("plus", text, 22);
        plus.setOnClickListener(v -> startActivity(new Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI)));
        head.addView(plus, new LinearLayout.LayoutParams((int) (56 * d), (int) (56 * d)));
        col.addView(head);

        search = new EditText(this);
        search.setHint("Buscar");
        search.setHintTextColor(text2);
        search.setTextColor(text);
        search.setSingleLine();
        search.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        search.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        search.setPadding((int) (18 * d), (int) (10 * d), (int) (18 * d), (int) (10 * d));
        search.setBackground(pill(glass, glassStroke, 24));
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(-1, -2);
        sp.setMargins((int) (16 * d), (int) (4 * d), (int) (16 * d), (int) (6 * d));
        col.addView(search, sp);
        search.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) { filter(s.toString().trim()); }
            @Override public void afterTextChanged(android.text.Editable e) { }
        });

        ListView list = new ListView(this);
        list.setDivider(null);
        list.setFastScrollEnabled(true);
        list.setSelector(new android.graphics.drawable.ColorDrawable(night ? 0x1FFFFFFF : 0x1F14123A));
        adapter = new BaseAdapter() {
            @Override public int getCount() { return shown.size(); }
            @Override public Object getItem(int i) { return shown.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public boolean isEnabled(int i) { return !shown.get(i).header; }
            @Override public View getView(int i, View v, ViewGroup p) { return row(shown.get(i)); }
        };
        list.setAdapter(adapter);
        list.setOnItemClickListener((p, v, i, id) -> { if (!shown.get(i).header) showDetail(shown.get(i)); });
        TextView empty = new TextView(this);
        empty.setText("Sin contactos");
        empty.setTextColor(text2);
        empty.setGravity(Gravity.CENTER);
        FrameLayout box = new FrameLayout(this);
        box.addView(empty, new FrameLayout.LayoutParams(-1, -1));
        box.addView(list, new FrameLayout.LayoutParams(-1, -1));
        list.setEmptyView(empty);
        col.addView(box, new LinearLayout.LayoutParams(-1, 0, 1f));
        return col;
    }

    private View row(Row r) {
        if (r.header) {
            TextView h = new TextView(this);
            h.setText(r.name);
            h.setTextColor(accent);
            h.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
            h.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
            h.setPadding((int) (24 * d), (int) (12 * d), 0, (int) (2 * d));
            return h;
        }
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding((int) (20 * d), (int) (6 * d), (int) (20 * d), (int) (6 * d));
        ImageView iv = new ImageView(this);
        int s = (int) (40 * d);
        iv.setImageBitmap(avatar(r.name, s));
        row.addView(iv, new LinearLayout.LayoutParams(s, s));
        TextView t = new TextView(this);
        t.setText(r.name);
        t.setTextColor(text);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        t.setSingleLine();
        t.setEllipsize(android.text.TextUtils.TruncateAt.END);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1f);
        lp.leftMargin = (int) (16 * d);
        row.addView(t, lp);
        if (r.star) {
            View star = glyph("star", accent, 16);
            row.addView(star, new LinearLayout.LayoutParams((int) (24 * d), (int) (24 * d)));
        }
        return row;
    }

    private void load() {
        new Thread(() -> {
            List<Row> out = new ArrayList<>();
            Cursor c = null;
            try {
                c = getContentResolver().query(ContactsContract.Contacts.CONTENT_URI,
                        new String[]{ContactsContract.Contacts._ID, ContactsContract.Contacts.LOOKUP_KEY,
                                ContactsContract.Contacts.DISPLAY_NAME, ContactsContract.Contacts.STARRED},
                        ContactsContract.Contacts.DISPLAY_NAME + " IS NOT NULL", null,
                        ContactsContract.Contacts.DISPLAY_NAME + " COLLATE LOCALIZED ASC");
                while (c != null && c.moveToNext()) {
                    Row r = new Row();
                    r.id = c.getLong(0); r.lookup = c.getString(1); r.name = c.getString(2); r.star = c.getInt(3) == 1;
                    out.add(r);
                }
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            ui.post(() -> { all.clear(); all.addAll(out); filter(search == null ? "" : search.getText().toString().trim()); });
        }).start();
    }

    private void filter(String q) {
        shown.clear();
        final String nq = Fuzzy.norm(q);
        int n = 0;
        if (nq.isEmpty()) {
            String lastLetter = "";
            for (Row r : all) {
                String l = r.name.isEmpty() ? "#" : r.name.substring(0, 1).toUpperCase(Locale.getDefault());
                if (!Character.isLetter(l.charAt(0))) l = "#";
                if (!l.equals(lastLetter)) {
                    Row h = new Row(); h.header = true; h.name = l;
                    shown.add(h);
                    lastLetter = l;
                }
                shown.add(r);
                n++;
            }
        } else {
            // ranked flat list: accents/case ignored, every word matched, typos tolerated; digits match phone numbers
            final String dq = nq.replaceAll("[^0-9]", "");
            final boolean digits = nq.replace(" ", "").matches("[0-9+]{3,}");
            final List<Row> hits = new ArrayList<>();
            for (Row r : all) {
                r.score = digits ? (numbersOf(r).contains(dq) ? 50 : 0) : Fuzzy.score(nq, Fuzzy.norm(r.name));
                if (r.score > 0) hits.add(r);
            }
            Collections.sort(hits, (a, b) -> b.score - a.score);
            shown.addAll(hits);
            n = hits.size();
        }
        count.setText(n + (n == 1 ? " contacto" : " contactos"));
        adapter.notifyDataSetChanged();
    }

    private final Map<Long, String> digitCache = new HashMap<>();

    /** Digits of all numbers of a contact (queried lazily, cached). */
    private String numbersOf(Row r) {
        String d = digitCache.get(r.id);
        if (d != null) return d;
        StringBuilder sb = new StringBuilder();
        Cursor c = null;
        try {
            c = getContentResolver().query(CommonDataKinds.Phone.CONTENT_URI, new String[]{CommonDataKinds.Phone.NUMBER},
                    CommonDataKinds.Phone.CONTACT_ID + "=?", new String[]{String.valueOf(r.id)}, null);
            while (c != null && c.moveToNext()) { String v = c.getString(0); if (v != null) sb.append(v.replaceAll("[^0-9]", "")).append(' '); }
        } catch (Exception ignored) { } finally { if (c != null) c.close(); }
        d = sb.toString();
        digitCache.put(r.id, d);
        return d;
    }

    // ---- detail ------------------------------------------------------------------

    private View buildDetail() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        LinearLayout bar = new LinearLayout(this);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        View back = glyph("back", text, 22);
        back.setOnClickListener(v -> closeDetail());
        bar.addView(back, new LinearLayout.LayoutParams((int) (56 * d), (int) (56 * d)));
        View spacer = new View(this);
        bar.addView(spacer, new LinearLayout.LayoutParams(0, 1, 1f));
        TextView edit = new TextView(this);
        edit.setText("Editar");
        edit.setTextColor(accent);
        edit.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        edit.setPadding((int) (16 * d), (int) (12 * d), (int) (20 * d), (int) (12 * d));
        edit.setOnClickListener(v -> {
            if (current != null) startActivity(new Intent(Intent.ACTION_EDIT, ContactsContract.Contacts.getLookupUri(current.id, current.lookup)));
        });
        bar.addView(edit);
        col.addView(bar);

        ScrollView scroll = new ScrollView(this);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setGravity(Gravity.CENTER_HORIZONTAL);
        body.setPadding((int) (16 * d), 0, (int) (16 * d), (int) (24 * d));
        detailAvatar = new ImageView(this);
        body.addView(detailAvatar, new LinearLayout.LayoutParams((int) (96 * d), (int) (96 * d)));
        detailName = new TextView(this);
        detailName.setTextColor(text);
        detailName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28);
        detailName.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        detailName.setGravity(Gravity.CENTER);
        detailName.setPadding(0, (int) (12 * d), 0, 0);
        body.addView(detailName);
        detailSub = new TextView(this);
        detailSub.setTextColor(text2);
        detailSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        detailSub.setGravity(Gravity.CENTER);
        body.addView(detailSub);
        detailBody = new LinearLayout(this);
        detailBody.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams(-1, -2);
        bp.topMargin = (int) (20 * d);
        body.addView(detailBody, bp);
        scroll.addView(body);
        col.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1f));
        return col;
    }

    private void showDetail(Row r) {
        current = r;
        detailName.setText(r.name);
        detailAvatar.setImageBitmap(avatar(r.name, (int) (96 * d)));
        detailBody.removeAllViews();
        detailSub.setText("");
        boolean first = listPage.getVisibility() == View.VISIBLE;
        listPage.setVisibility(View.GONE);
        detailPage.setVisibility(View.VISIBLE);
        if (first) { detailPage.setAlpha(0f); detailPage.animate().alpha(1f).setDuration(160).start(); }
        final long id = r.id;
        new Thread(() -> {
            final List<String[]> items = new ArrayList<>();   // kind, label, value
            String org = null;
            Cursor c = null;
            try {
                c = getContentResolver().query(ContactsContract.Data.CONTENT_URI,
                        new String[]{ContactsContract.Data.MIMETYPE, ContactsContract.Data.DATA1, ContactsContract.Data.DATA2, ContactsContract.Data.DATA3},
                        ContactsContract.Data.CONTACT_ID + "=?", new String[]{String.valueOf(id)}, null);
                while (c != null && c.moveToNext()) {
                    String mt = c.getString(0), v = c.getString(1);
                    if (v == null || v.isEmpty()) continue;
                    if (CommonDataKinds.Phone.CONTENT_ITEM_TYPE.equals(mt)) {
                        items.add(new String[]{"phone", CommonDataKinds.Phone.getTypeLabel(getResources(), c.getInt(2), c.getString(3)).toString(), v});
                    } else if (CommonDataKinds.Email.CONTENT_ITEM_TYPE.equals(mt)) {
                        items.add(new String[]{"mail", CommonDataKinds.Email.getTypeLabel(getResources(), c.getInt(2), c.getString(3)).toString(), v});
                    } else if (CommonDataKinds.Organization.CONTENT_ITEM_TYPE.equals(mt)) {
                        org = v;
                    }
                }
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            final String fo = org;
            ui.post(() -> {
                if (current == null || current.id != id) return;
                detailSub.setText(fo == null ? "" : fo);
                for (String[] it : items) detailBody.addView(detailRow(it));
                if (items.isEmpty()) {
                    TextView none = new TextView(this);
                    none.setText("Sin teléfono ni correo");
                    none.setTextColor(text2);
                    none.setGravity(Gravity.CENTER);
                    detailBody.addView(none);
                }
            });
        }).start();
    }

    private View detailRow(final String[] it) {
        LinearLayout card = new LinearLayout(this);
        card.setGravity(Gravity.CENTER_VERTICAL);
        card.setBackground(pill(glass, glassStroke, 20));
        card.setPadding((int) (18 * d), (int) (10 * d), (int) (8 * d), (int) (10 * d));
        LinearLayout t = new LinearLayout(this);
        t.setOrientation(LinearLayout.VERTICAL);
        TextView l = new TextView(this);
        l.setText(it[1]);
        l.setTextColor(text2);
        l.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        TextView v = new TextView(this);
        v.setText(it[2]);
        v.setTextColor(text);
        v.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        v.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        v.setSingleLine();
        t.addView(l);
        t.addView(v);
        card.addView(t, new LinearLayout.LayoutParams(0, -2, 1f));
        boolean phone = it[0].equals("phone");
        card.addView(action(phone ? "message" : "mail", accent, () -> {
            try { startActivity(phone ? new Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + Uri.encode(it[2])))
                    : new Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:" + it[2]))); } catch (Exception ignored) { }
        }), new LinearLayout.LayoutParams((int) (48 * d), (int) (48 * d)));
        if (phone) card.addView(action("phone", ok, () -> {
            try { startActivity(new Intent(Intent.ACTION_CALL, Uri.parse("tel:" + Uri.encode(it[2])))); }
            catch (Exception e) { Toast.makeText(this, "No se puede llamar", Toast.LENGTH_SHORT).show(); }
        }), new LinearLayout.LayoutParams((int) (48 * d), (int) (48 * d)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.bottomMargin = (int) (8 * d);
        card.setLayoutParams(lp);
        return card;
    }

    private void closeDetail() {
        current = null;
        detailPage.setVisibility(View.GONE);
        listPage.setVisibility(View.VISIBLE);
    }

    // ---- helpers -------------------------------------------------------------------

    private View action(String kind, int color, Runnable r) {
        View v = glyph(kind, color, 22);
        v.setOnClickListener(x -> r.run());
        return v;
    }

    private GradientDrawable pill(int fill, int stroke, int radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setStroke(Math.max(1, (int) d), stroke);
        g.setCornerRadius(radiusDp * d);
        return g;
    }

    private Bitmap avatar(String name, int s) {
        int[] palette = {0xFF6366F1, 0xFFEC4899, 0xFF14B8A6, 0xFFF59E0B, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEF4444};
        String n = name == null ? "?" : name;
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(palette[Math.abs(n.hashCode()) % palette.length]);
        c.drawCircle(s / 2f, s / 2f, s / 2f, p);
        p.setColor(Color.WHITE);
        p.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        p.setTextSize(s * 0.46f);
        p.setTextAlign(Paint.Align.CENTER);
        String l = n.isEmpty() ? "?" : n.substring(0, 1).toUpperCase();
        if (!Character.isLetter(l.charAt(0))) l = "#";
        c.drawText(l, s / 2f, s / 2f + p.getTextSize() * 0.35f, p);
        return b;
    }

    private View glyph(final String kind, final int color, final int sizeDp) {
        return new View(this) {
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
                    case "back": cv.drawLine(30, 8, 14, 24, p); cv.drawLine(14, 24, 30, 40, p); break;
                    case "star": {
                        p.setStyle(Paint.Style.FILL);
                        Path st = new Path();
                        for (int i = 0; i < 10; i++) {
                            double a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 == 0 ? 20 : 8.5;
                            float x = 24 + (float) (Math.cos(a) * r), y = 25 + (float) (Math.sin(a) * r);
                            if (i == 0) st.moveTo(x, y); else st.lineTo(x, y);
                        }
                        st.close();
                        cv.drawPath(st, p);
                        break;
                    }
                    case "message": {
                        RectF r = new RectF(8, 10, 40, 32);
                        cv.drawRoundRect(r, 9, 9, p);
                        cv.drawLine(16, 32, 15, 39, p); cv.drawLine(15, 39, 23, 32, p);
                        break;
                    }
                    case "mail": {
                        cv.drawRoundRect(new RectF(7, 12, 41, 36), 5, 5, p);
                        cv.drawLine(9, 15, 24, 26, p); cv.drawLine(24, 26, 39, 15, p);
                        break;
                    }
                    default: { // phone
                        Path h = new Path();
                        h.moveTo(14, 10); h.lineTo(19.5f, 10); h.lineTo(21.5f, 17); h.lineTo(18, 19.5f);
                        h.cubicTo(20, 24, 24, 28, 28.5f, 30); h.lineTo(31, 26.5f); h.lineTo(38, 28.5f); h.lineTo(38, 34);
                        h.cubicTo(38, 36, 36.5f, 37.5f, 34.5f, 37.5f); h.cubicTo(22, 37, 11, 26, 10.5f, 13.5f);
                        h.cubicTo(10.5f, 11.5f, 12, 10, 14, 10); h.close();
                        cv.drawPath(h, p);
                    }
                }
                cv.restore();
            }
        };
    }
}
