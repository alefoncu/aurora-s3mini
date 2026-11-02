package com.scratch.iosmessages;

import android.app.Activity;
import android.content.ContentValues;
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
import android.telephony.SmsManager;
import android.text.format.DateUtils;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.util.*;

/**
 * Own Messages app: conversation list, thread view and composer on glass over the wallpaper.
 * It reads the SMS provider and sends through SmsManager; it is NOT the default SMS app, so the stock app still
 * receives SMS/MMS and owns the provider (sent messages are stored only when the provider allows it).
 */
public class MessagesActivity extends Activity {
    private static final Uri SMS = Uri.parse("content://sms");

    private float d;
    private boolean night;
    private int text, text2, scrim, glass, glassStroke, accent, bubbleIn, bubbleOut, onOut;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private FrameLayout stage;
    private View listPage, threadPage;
    private BaseAdapter listAdapter, threadAdapter;
    private final List<Conv> convs = new ArrayList<>();
    private final List<Msg> msgs = new ArrayList<>();
    private Conv open;
    private String newAddress;                 // address typed for a conversation that has no thread yet
    private EditText input, toField;
    private TextView threadTitle;
    private final Map<String, String> nameCache = new HashMap<>();

    private static class Conv { long thread; String address, name, last; long date; int unread; }
    private static class Msg { String body; boolean out; long date; boolean pending, failed; }

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
        bubbleIn = night ? 0x33FFFFFF : 0xCCFFFFFF;
        bubbleOut = night ? 0xFF4F6BFF : 0xFF3B6BEA;
        onOut = Color.WHITE;

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
        threadPage = buildThread();
        stage.addView(listPage, new FrameLayout.LayoutParams(-1, -1));
        stage.addView(threadPage, new FrameLayout.LayoutParams(-1, -1));
        threadPage.setVisibility(View.GONE);
        handleIntent(getIntent());
    }

    @Override protected void onNewIntent(Intent i) { super.onNewIntent(i); handleIntent(i); }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }
    @Override protected void onResume() { super.onResume(); loadConvs(); if (open != null) loadThread(); }

    @Override
    public void onBackPressed() {
        if (threadPage.getVisibility() == View.VISIBLE) showList(); else super.onBackPressed();
    }

    private void handleIntent(Intent i) {
        if (i == null || i.getData() == null) return;
        String ssp = i.getData().getSchemeSpecificPart();
        if (ssp == null) return;
        String addr = ssp.split("\\?")[0];
        Conv c = new Conv();
        c.address = addr; c.name = nameFor(addr); c.thread = -1;
        for (Conv k : convs) if (k.address != null && sameNumber(k.address, addr)) c = k;
        openThread(c);
        String body = i.getStringExtra("sms_body");
        if (body != null) input.setText(body);
    }

    // ---- list ------------------------------------------------------------------

    private View buildList() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        LinearLayout head = new LinearLayout(this);
        head.setGravity(Gravity.CENTER_VERTICAL);
        TextView t = new TextView(this);
        t.setText("Mensajes");
        t.setTextColor(text);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
        t.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        t.setPadding((int) (22 * d), (int) (12 * d), 0, (int) (8 * d));
        head.addView(t, new LinearLayout.LayoutParams(0, -2, 1f));
        View plus = glyph("plus", text, 22);
        plus.setOnClickListener(v -> openNew());
        head.addView(plus, new LinearLayout.LayoutParams((int) (56 * d), (int) (56 * d)));
        col.addView(head);

        ListView list = new ListView(this);
        list.setDivider(null);
        list.setSelector(new android.graphics.drawable.ColorDrawable(night ? 0x1FFFFFFF : 0x1F14123A));
        listAdapter = new BaseAdapter() {
            @Override public int getCount() { return convs.size(); }
            @Override public Object getItem(int i) { return convs.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public View getView(int i, View v, ViewGroup p) { return convRow(convs.get(i)); }
        };
        list.setAdapter(listAdapter);
        list.setOnItemClickListener((p, v, i, id) -> openThread(convs.get(i)));
        TextView empty = new TextView(this);
        empty.setText("Sin conversaciones");
        empty.setTextColor(text2);
        empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        empty.setGravity(Gravity.CENTER);
        FrameLayout box = new FrameLayout(this);
        box.addView(empty, new FrameLayout.LayoutParams(-1, -1));
        box.addView(list, new FrameLayout.LayoutParams(-1, -1));
        list.setEmptyView(empty);
        col.addView(box, new LinearLayout.LayoutParams(-1, 0, 1f));
        return col;
    }

    private View convRow(Conv c) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding((int) (20 * d), (int) (10 * d), (int) (20 * d), (int) (10 * d));
        ImageView av = new ImageView(this);
        int s = (int) (46 * d);
        av.setImageBitmap(avatar(c.name != null ? c.name : c.address, s));
        row.addView(av, new LinearLayout.LayoutParams(s, s));
        LinearLayout t = new LinearLayout(this);
        t.setOrientation(LinearLayout.VERTICAL);
        TextView n = new TextView(this);
        n.setText(c.name != null ? c.name : c.address);
        n.setTextColor(text);
        n.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        n.setTypeface(Typeface.create(c.unread > 0 ? "sans-serif-medium" : "sans-serif-light", Typeface.NORMAL));
        n.setSingleLine();
        n.setEllipsize(android.text.TextUtils.TruncateAt.END);
        TextView l = new TextView(this);
        l.setText(c.last);
        l.setTextColor(text2);
        l.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        l.setSingleLine();
        l.setEllipsize(android.text.TextUtils.TruncateAt.END);
        t.addView(n);
        t.addView(l);
        LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(0, -2, 1f);
        tp.leftMargin = (int) (14 * d);
        row.addView(t, tp);
        LinearLayout right = new LinearLayout(this);
        right.setOrientation(LinearLayout.VERTICAL);
        right.setGravity(Gravity.END);
        TextView when = new TextView(this);
        when.setText(DateUtils.isToday(c.date) ? DateUtils.formatDateTime(this, c.date, DateUtils.FORMAT_SHOW_TIME)
                : DateUtils.getRelativeTimeSpanString(c.date, System.currentTimeMillis(), DateUtils.DAY_IN_MILLIS, DateUtils.FORMAT_ABBREV_RELATIVE));
        when.setTextColor(text2);
        when.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        right.addView(when);
        if (c.unread > 0) {
            TextView u = new TextView(this);
            u.setText(String.valueOf(c.unread));
            u.setTextColor(Color.WHITE);
            u.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
            u.setGravity(Gravity.CENTER);
            GradientDrawable g = new GradientDrawable();
            g.setColor(accent);
            g.setCornerRadius(10 * d);
            u.setBackground(g);
            u.setPadding((int) (7 * d), (int) (1 * d), (int) (7 * d), (int) (1 * d));
            LinearLayout.LayoutParams up = new LinearLayout.LayoutParams(-2, -2);
            up.topMargin = (int) (4 * d);
            right.addView(u, up);
        }
        row.addView(right);
        return row;
    }

    private void loadConvs() {
        new Thread(() -> {
            Map<Long, Conv> byThread = new LinkedHashMap<>();
            Cursor c = null;
            try {
                c = getContentResolver().query(SMS, new String[]{"thread_id", "address", "body", "date", "read", "type"},
                        null, null, "date DESC LIMIT 600");
                while (c != null && c.moveToNext()) {
                    long th = c.getLong(0);
                    Conv k = byThread.get(th);
                    if (k == null) {
                        k = new Conv();
                        k.thread = th; k.address = c.getString(1); k.last = c.getString(2); k.date = c.getLong(3);
                        k.name = nameFor(k.address);
                        byThread.put(th, k);
                    }
                    if (c.getInt(4) == 0 && c.getInt(5) == 1) k.unread++;
                }
            } catch (Exception ignored) { } finally { if (c != null) c.close(); }
            final List<Conv> out = new ArrayList<>(byThread.values());
            ui.post(() -> { convs.clear(); convs.addAll(out); listAdapter.notifyDataSetChanged(); });
        }).start();
    }

    // ---- thread ----------------------------------------------------------------

    private View buildThread() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        LinearLayout head = new LinearLayout(this);
        head.setGravity(Gravity.CENTER_VERTICAL);
        View back = glyph("back", text, 22);
        back.setOnClickListener(v -> showList());
        head.addView(back, new LinearLayout.LayoutParams((int) (56 * d), (int) (56 * d)));
        threadTitle = new TextView(this);
        threadTitle.setTextColor(text);
        threadTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        threadTitle.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        threadTitle.setSingleLine();
        head.addView(threadTitle, new LinearLayout.LayoutParams(0, -2, 1f));
        col.addView(head);

        toField = new EditText(this);
        toField.setHint("Para: número");
        toField.setHintTextColor(text2);
        toField.setTextColor(text);
        toField.setInputType(android.text.InputType.TYPE_CLASS_PHONE);
        toField.setSingleLine();
        toField.setPadding((int) (18 * d), (int) (8 * d), (int) (18 * d), (int) (8 * d));
        toField.setBackground(pill(glass, glassStroke, 22));
        LinearLayout.LayoutParams tl = new LinearLayout.LayoutParams(-1, -2);
        tl.setMargins((int) (14 * d), 0, (int) (14 * d), (int) (4 * d));
        col.addView(toField, tl);
        toField.setVisibility(View.GONE);

        ListView list = new ListView(this);
        list.setDivider(null);
        list.setSelector(new android.graphics.drawable.ColorDrawable(Color.TRANSPARENT));
        list.setTranscriptMode(ListView.TRANSCRIPT_MODE_ALWAYS_SCROLL);
        list.setStackFromBottom(true);
        threadAdapter = new BaseAdapter() {
            @Override public int getCount() { return msgs.size(); }
            @Override public Object getItem(int i) { return msgs.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public View getView(int i, View v, ViewGroup p) { return bubble(msgs.get(i)); }
        };
        list.setAdapter(threadAdapter);
        col.addView(list, new LinearLayout.LayoutParams(-1, 0, 1f));

        LinearLayout bar = new LinearLayout(this);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setPadding((int) (12 * d), (int) (6 * d), (int) (12 * d), (int) (10 * d));
        input = new EditText(this);
        input.setHint("Mensaje");
        input.setHintTextColor(text2);
        input.setTextColor(text);
        input.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        input.setMaxLines(4);
        input.setPadding((int) (18 * d), (int) (10 * d), (int) (18 * d), (int) (10 * d));
        input.setBackground(pill(glass, glassStroke, 24));
        bar.addView(input, new LinearLayout.LayoutParams(0, -2, 1f));
        FrameLayout send = new FrameLayout(this);
        View arrow = glyph("send", Color.WHITE, 20);
        send.addView(arrow, new FrameLayout.LayoutParams(-1, -1));
        GradientDrawable sg = new GradientDrawable();
        sg.setShape(GradientDrawable.OVAL);
        sg.setColor(accent);
        send.setBackground(sg);
        send.setOnClickListener(v -> send());
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams((int) (44 * d), (int) (44 * d));
        sp.leftMargin = (int) (8 * d);
        bar.addView(send, sp);
        col.addView(bar);
        return col;
    }

    private void openNew() {
        Conv c = new Conv();
        c.thread = -1;
        open = c;
        showThread(true);
    }

    private void openThread(Conv c) {
        open = c;
        msgs.clear();
        showThread(false);
        loadThread();
    }

    private void showThread(boolean isNew) {
        threadTitle.setText(isNew ? "Nuevo mensaje" : (open.name != null ? open.name : open.address));
        toField.setVisibility(isNew ? View.VISIBLE : View.GONE);
        if (isNew) { toField.setText(""); msgs.clear(); threadAdapter.notifyDataSetChanged(); }
        listPage.setVisibility(View.GONE);
        threadPage.setVisibility(View.VISIBLE);
        threadPage.setAlpha(0f);
        threadPage.animate().alpha(1f).setDuration(160).start();
        (isNew ? toField : input).requestFocus();
    }

    private void showList() {
        ((android.view.inputmethod.InputMethodManager) getSystemService(INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(input.getWindowToken(), 0);
        threadPage.setVisibility(View.GONE);
        listPage.setVisibility(View.VISIBLE);
        open = null;
        loadConvs();
    }

    private void loadThread() {
        final Conv c = open;
        if (c == null || c.thread < 0) return;
        new Thread(() -> {
            List<Msg> out = new ArrayList<>();
            Cursor cur = null;
            try {
                cur = getContentResolver().query(SMS, new String[]{"body", "type", "date"}, "thread_id=?",
                        new String[]{String.valueOf(c.thread)}, "date ASC LIMIT 500");
                while (cur != null && cur.moveToNext()) {
                    Msg m = new Msg();
                    m.body = cur.getString(0);
                    int type = cur.getInt(1);
                    m.out = type != 1;
                    m.failed = type == 5;
                    m.date = cur.getLong(2);
                    out.add(m);
                }
            } catch (Exception ignored) { } finally { if (cur != null) cur.close(); }
            ui.post(() -> {
                if (open != c) return;
                List<Msg> keep = new ArrayList<>();
                for (Msg m : msgs) if (m.pending) keep.add(m);
                msgs.clear(); msgs.addAll(out); msgs.addAll(keep);
                threadAdapter.notifyDataSetChanged();
            });
        }).start();
    }

    private View bubble(Msg m) {
        FrameLayout row = new FrameLayout(this);
        row.setPadding((int) (12 * d), (int) (3 * d), (int) (12 * d), (int) (3 * d));
        TextView t = new TextView(this);
        t.setText(m.body);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        t.setMaxWidth((int) (getResources().getDisplayMetrics().widthPixels * 0.74f));
        t.setTextColor(m.out ? onOut : text);
        t.setPadding((int) (14 * d), (int) (9 * d), (int) (14 * d), (int) (9 * d));
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(20 * d);
        g.setColor(m.out ? (m.failed ? 0xFFDC2626 : bubbleOut) : bubbleIn);
        if (!m.out) g.setStroke(Math.max(1, (int) d), glassStroke);
        t.setBackground(g);
        t.setAlpha(m.pending ? 0.6f : 1f);
        row.addView(t, new FrameLayout.LayoutParams(-2, -2, m.out ? Gravity.END : Gravity.START));
        return row;
    }

    // ---- sending -----------------------------------------------------------------

    private void send() {
        final String body = input.getText().toString().trim();
        if (body.isEmpty() || open == null) return;
        String addr = open.address;
        if (toField.getVisibility() == View.VISIBLE) addr = toField.getText().toString().trim();
        if (addr == null || addr.replaceAll("[^0-9+]", "").length() < 3) {
            Toast.makeText(this, "Indica un número", Toast.LENGTH_SHORT).show();
            return;
        }
        final Msg m = new Msg();
        m.body = body; m.out = true; m.pending = true; m.date = System.currentTimeMillis();
        msgs.add(m);
        threadAdapter.notifyDataSetChanged();
        input.setText("");
        try {
            SmsManager sm = SmsManager.getDefault();
            ArrayList<String> parts = sm.divideMessage(body);
            sm.sendMultipartTextMessage(addr, null, parts, null, null);
            ContentValues v = new ContentValues();
            v.put("address", addr); v.put("body", body); v.put("read", 1); v.put("date", m.date);
            try { getContentResolver().insert(Uri.parse("content://sms/sent"), v); } catch (Exception ignored) { /* not the default SMS app */ }
            m.pending = false;
        } catch (Exception e) {
            m.pending = false; m.failed = true;
            Toast.makeText(this, "No se pudo enviar (¿hay SIM?)", Toast.LENGTH_LONG).show();
        }
        threadAdapter.notifyDataSetChanged();
        if (open.address == null) { open.address = addr; open.name = nameFor(addr); }
        toField.setVisibility(View.GONE);
        threadTitle.setText(open.name != null ? open.name : open.address);
    }

    // ---- helpers ---------------------------------------------------------------------

    private String nameFor(String number) {
        if (number == null) return null;
        if (nameCache.containsKey(number)) return nameCache.get(number);
        String name = null;
        Cursor c = null;
        try {
            c = getContentResolver().query(Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number)),
                    new String[]{ContactsContract.PhoneLookup.DISPLAY_NAME}, null, null, null);
            if (c != null && c.moveToFirst()) name = c.getString(0);
        } catch (Exception ignored) { } finally { if (c != null) c.close(); }
        nameCache.put(number, name);
        return name;
    }

    private static boolean sameNumber(String a, String b) {
        String x = a.replaceAll("[^0-9]", ""), y = b.replaceAll("[^0-9]", "");
        if (x.length() < 7 || y.length() < 7) return x.equals(y);
        return x.endsWith(y.substring(y.length() - 7)) || y.endsWith(x.substring(x.length() - 7));
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

    /** Small line glyph on a 48-unit grid. */
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
                    default: // send: arrow up
                        cv.drawLine(24, 38, 24, 11, p); cv.drawLine(24, 11, 14, 21, p); cv.drawLine(24, 11, 34, 21, p); break;
                }
                cv.restore();
            }
        };
    }
}
