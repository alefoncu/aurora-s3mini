package com.scratch.iosnotes;

import android.app.AlertDialog;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Intent;
import android.database.ContentObserver;
import android.database.Cursor;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.animation.DecelerateInterpolator;
import android.widget.*;
import java.text.Normalizer;
import java.text.SimpleDateFormat;
import java.util.*;

public class NotesActivity extends NotesBase {
    private final List<Note> notes = new ArrayList<>();
    private LinearLayout cards;
    private TextView count;
    private EditText search;
    private boolean observing;
    private final ContentObserver observer = new ContentObserver(new Handler(Looper.getMainLooper())) {
        @Override public void onChange(boolean selfChange) { if (!isFinishing() && !isDestroyed()) reload(); }
    };
    private static class Note { long id, updated; String body; boolean pinned; }

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        FrameLayout root = root();
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true); scroll.setClipToPadding(true);
        scroll.setPadding(0, statusInset(), 0, 0);
        scroll.setOnApplyWindowInsetsListener((v, insets) -> {
            scroll.setPadding(0, insets.getSystemWindowInsetTop(), 0, 0); return insets;
        });
        LinearLayout column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(dp(20), dp(20), dp(20), dp(100));
        column.addView(label("Notas", 34, "sans-serif-thin"));
        count = label("0 notas", 14, "sans-serif-light"); count.setTextColor(subtle);
        count.setPadding(0, dp(4), 0, dp(20)); column.addView(count);
        search = new EditText(this); search.setSingleLine(true); search.setHint("Buscar notas");
        search.setTextColor(ink); search.setHintTextColor(subtle); search.setTextSize(16);
        search.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        search.setPadding(dp(16), dp(12), dp(16), dp(12)); search.setBackground(glass(20));
        column.addView(search, new LinearLayout.LayoutParams(-1, -2));
        cards = new LinearLayout(this); cards.setOrientation(LinearLayout.VERTICAL); cards.setPadding(0, dp(20), 0, 0);
        column.addView(cards, new LinearLayout.LayoutParams(-1, -2));
        scroll.addView(column, new ScrollView.LayoutParams(-1, -2)); root.addView(scroll, new FrameLayout.LayoutParams(-1, -1));
        Glyph add = new Glyph(true); add.setBackground(glass(28)); add.setContentDescription("Crear nota");
        add.setOnClickListener(v -> startActivity(new Intent(this, EditorActivity.class)));
        FrameLayout.LayoutParams fab = new FrameLayout.LayoutParams(dp(56), dp(56), Gravity.BOTTOM | Gravity.RIGHT);
        fab.setMargins(dp(20), dp(20), dp(24), dp(24)); root.addView(add, fab);
        setContentView(root); column.setFocusableInTouchMode(true); column.requestFocus();
        search.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            public void onTextChanged(CharSequence s, int start, int before, int count) { render(false); }
            public void afterTextChanged(Editable s) { }
        });
        if (state != null) {
            search.setText(state.getString("query", ""));
            scroll.post(() -> scroll.scrollTo(0, state.getInt("scroll_y", 0)));
        }
    }
    @Override protected void onSaveInstanceState(Bundle state) {
        state.putString("query", search.getText().toString());
        state.putInt("scroll_y", ((ScrollView) cards.getParent().getParent()).getScrollY());
        super.onSaveInstanceState(state);
    }
    @Override protected void onStart() {
        super.onStart();
        if (!observing) { getContentResolver().registerContentObserver(NotesProvider.CONTENT_URI, true, observer); observing = true; }
        reload();
    }
    @Override protected void onStop() {
        if (observing) { getContentResolver().unregisterContentObserver(observer); observing = false; }
        super.onStop();
    }
    private void reload() {
        List<Note> loaded = new ArrayList<>();
        try (Cursor cursor = getContentResolver().query(NotesProvider.CONTENT_URI,
                new String[]{"_id", "body", "updated", "pinned"}, null, null, null)) {
            if (cursor == null) { Toast.makeText(this, "No se pudieron cargar las notas", Toast.LENGTH_SHORT).show(); return; }
            while (cursor.moveToNext()) {
                Note note = new Note(); note.id = cursor.getLong(0); note.body = cursor.getString(1);
                if (note.body == null) note.body = "";
                note.updated = cursor.getLong(2); note.pinned = cursor.getInt(3) != 0; loaded.add(note);
            }
        } catch (RuntimeException failure) { Toast.makeText(this, "No se pudieron cargar las notas", Toast.LENGTH_SHORT).show(); return; }
        notes.clear(); notes.addAll(loaded); render(true);
    }
    private static String folded(String value) {
        return Normalizer.normalize(value, Normalizer.Form.NFD).replaceAll("\\p{M}+", "").toLowerCase(Locale.ROOT);
    }
    private void render(boolean animate) {
        cards.removeAllViews(); count.setText(notes.size() + (notes.size() == 1 ? " nota" : " notas"));
        String filter = folded(search.getText().toString()); int shown = 0;
        for (Note note : notes) {
            if (!folded(note.body).contains(filter)) continue;
            LinearLayout card = new LinearLayout(this); card.setOrientation(LinearLayout.VERTICAL);
            card.setPadding(dp(16), dp(14), dp(16), dp(14)); card.setBackground(glass(20));
            LinearLayout row = new LinearLayout(this); row.setGravity(Gravity.CENTER_VERTICAL);
            String body = note.body.trim(); int newline = body.indexOf('\n');
            TextView title = label(newline < 0 ? body : body.substring(0, newline), 17, "sans-serif");
            title.setSingleLine(true); title.setEllipsize(TextUtils.TruncateAt.END);
            row.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
            if (note.pinned) row.addView(new Glyph(false), new LinearLayout.LayoutParams(dp(22), dp(22)));
            TextView date = label(relativeDate(note.updated), 11, "sans-serif-light"); date.setTextColor(subtle);
            date.setPadding(dp(8), 0, 0, 0); row.addView(date); card.addView(row);
            if (newline >= 0 && newline + 1 < body.length()) {
                TextView preview = label(body.substring(newline + 1), 15, "sans-serif-light");
                preview.setTextColor(subtle); preview.setMaxLines(2); preview.setEllipsize(TextUtils.TruncateAt.END);
                preview.setPadding(0, dp(7), 0, 0); card.addView(preview);
            }
            card.setOnClickListener(v -> startActivity(new Intent(this, EditorActivity.class).putExtra("note_id", note.id)));
            card.setOnLongClickListener(v -> { actions(note); return true; });
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2); params.bottomMargin = dp(12); cards.addView(card, params);
            if (animate && shown < 10) {
                card.setAlpha(0); card.setTranslationY(dp(24));
                card.animate().alpha(1).translationY(0).setStartDelay(shown * 40L).setDuration(420)
                        .setInterpolator(new DecelerateInterpolator()).start();
            }
            shown++;
        }
        if (shown == 0) {
            TextView empty = label(notes.isEmpty() ? "Sin notas. Toca + para crear una." : "Sin resultados.", 17, "sans-serif-light");
            empty.setTextColor(subtle); empty.setGravity(Gravity.CENTER); empty.setPadding(0, dp(40), 0, 0); cards.addView(empty);
        }
    }
    private String relativeDate(long stamp) {
        Calendar day = Calendar.getInstance(); day.set(Calendar.HOUR_OF_DAY, 0); day.set(Calendar.MINUTE, 0);
        day.set(Calendar.SECOND, 0); day.set(Calendar.MILLISECOND, 0);
        long today = day.getTimeInMillis(); day.add(Calendar.DAY_OF_YEAR, -1);
        if (stamp >= today) return "hoy " + new SimpleDateFormat("HH:mm", new Locale("es", "ES")).format(new Date(stamp));
        if (stamp >= day.getTimeInMillis()) return "ayer";
        Calendar date = Calendar.getInstance(); date.setTimeInMillis(stamp);
        return new String[]{"dom", "lun", "mar", "mié", "jue", "vie", "sáb"}[date.get(Calendar.DAY_OF_WEEK) - 1] + " " + date.get(Calendar.DAY_OF_MONTH);
    }
    private void actions(Note note) {
        new AlertDialog.Builder(this).setItems(new String[]{note.pinned ? "Quitar fijado" : "Fijar", "Borrar"}, (dialog, which) -> {
            if (which == 0) {
                ContentValues values = new ContentValues(); values.put("pinned", note.pinned ? 0 : 1);
                try { getContentResolver().update(ContentUris.withAppendedId(NotesProvider.CONTENT_URI, note.id), values, null, null); }
                catch (RuntimeException failure) { Toast.makeText(this, "No se pudo fijar la nota", Toast.LENGTH_SHORT).show(); }
            } else new AlertDialog.Builder(this).setTitle("¿Borrar nota?").setMessage("Esta acción no se puede deshacer.")
                    .setNegativeButton("Cancelar", null).setPositiveButton("Borrar", (d, w) -> {
                        try { getContentResolver().delete(ContentUris.withAppendedId(NotesProvider.CONTENT_URI, note.id), null, null); }
                        catch (RuntimeException failure) { Toast.makeText(this, "No se pudo borrar la nota", Toast.LENGTH_SHORT).show(); }
                    }).show();
        }).show();
    }
    private class Glyph extends View {
        private final boolean plus;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        Glyph(boolean plus) { super(NotesActivity.this); this.plus = plus; if (!plus) setContentDescription("Nota fijada"); }
        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas); canvas.save(); canvas.translate(getWidth() / 2f, getHeight() / 2f);
            paint.setColor(accent); paint.setStrokeWidth(dp(plus ? 2.5f : 1.5f)); paint.setStrokeCap(Paint.Cap.ROUND);
            if (plus) {
                canvas.drawLine(-dp(10), 0, dp(10), 0, paint); canvas.drawLine(0, -dp(10), 0, dp(10), paint);
            } else {
                canvas.rotate(30); Path pin = new Path(); pin.moveTo(-dp(4), -dp(7)); pin.lineTo(dp(4), -dp(7));
                pin.lineTo(dp(3), -dp(1)); pin.lineTo(dp(6), dp(2)); pin.lineTo(-dp(6), dp(2)); pin.lineTo(-dp(3), -dp(1)); pin.close();
                canvas.drawPath(pin, paint); canvas.drawLine(0, dp(2), 0, dp(8), paint);
            }
            canvas.restore();
        }
    }
}
