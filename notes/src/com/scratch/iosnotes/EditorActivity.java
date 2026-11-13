package com.scratch.iosnotes;

import android.app.AlertDialog;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.*;

public class EditorActivity extends NotesBase {
    private EditText editor;
    private TextView pinButton;
    private long noteId = -1;
    private boolean pinned, deleted;
    private String savedBody;
    private boolean savedPinned;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        String body = "";
        if (state != null) {
            noteId = state.getLong("note_id", -1); pinned = state.getBoolean("pinned");
            body = state.getString("body", ""); savedBody = state.getString("saved_body");
            savedPinned = state.getBoolean("saved_pinned"); deleted = state.getBoolean("deleted");
        } else if (Intent.ACTION_SEND.equals(getIntent().getAction())) {
            CharSequence shared = getIntent().getCharSequenceExtra(Intent.EXTRA_TEXT);
            if (shared != null) body = shared.toString();
        } else {
            noteId = getIntent().getLongExtra("note_id", -1);
            if (noteId >= 0) {
                try (Cursor cursor = getContentResolver().query(noteUri(), new String[]{"body", "pinned"}, null, null, null)) {
                    if (cursor == null || !cursor.moveToFirst()) { unavailable(); return; }
                    body = cursor.getString(0); if (body == null) body = "";
                    pinned = cursor.getInt(1) != 0; savedBody = body; savedPinned = pinned;
                } catch (RuntimeException failure) { unavailable(); return; }
            }
        }
        FrameLayout root = root();
        LinearLayout column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(0, statusInset(), 0, 0);
        column.setOnApplyWindowInsetsListener((v, insets) -> {
            column.setPadding(0, insets.getSystemWindowInsetTop(), 0, 0); return insets;
        });
        LinearLayout toolbar = new LinearLayout(this); toolbar.setGravity(Gravity.CENTER_VERTICAL);
        toolbar.setPadding(dp(12), dp(10), dp(12), 0);
        TextView back = pill("‹ Notas"); back.setOnClickListener(v -> finish()); toolbar.addView(back);
        Space spacer = new Space(this); toolbar.addView(spacer, new LinearLayout.LayoutParams(0, 1, 1));
        pinButton = pill(pinned ? "Quitar fijado" : "Fijar"); pinButton.setSelected(pinned);
        pinButton.setOnClickListener(v -> {
            pinned = !pinned; pinButton.setText(pinned ? "Quitar fijado" : "Fijar"); pinButton.setSelected(pinned);
        }); toolbar.addView(pinButton);
        TextView delete = pill("Borrar"); LinearLayout.LayoutParams deleteParams = new LinearLayout.LayoutParams(-2, -2);
        deleteParams.leftMargin = dp(6); toolbar.addView(delete, deleteParams); delete.setOnClickListener(v -> confirmDelete());
        column.addView(toolbar, new LinearLayout.LayoutParams(-1, -2));
        editor = new EditText(this); editor.setId(1001); editor.setSaveEnabled(false);
        editor.setTextSize(18); editor.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        editor.setTextColor(ink); editor.setHintTextColor(subtle); editor.setBackground(null);
        editor.setHint("Escribe algo…"); editor.setGravity(Gravity.TOP | Gravity.LEFT);
        editor.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE
                | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES | InputType.TYPE_TEXT_FLAG_AUTO_CORRECT);
        editor.setPadding(dp(20), dp(20), dp(20), dp(20)); editor.setText(body);
        column.addView(editor, new LinearLayout.LayoutParams(-1, 0, 1));
        root.addView(column, new FrameLayout.LayoutParams(-1, -1)); setContentView(root);
        if (state != null) {
            int start = Math.max(0, Math.min(body.length(), state.getInt("selection_start", body.length())));
            int end = Math.max(0, Math.min(body.length(), state.getInt("selection_end", start)));
            editor.setSelection(start, end);
        } else editor.setSelection(body.length());
        if (noteId < 0) {
            editor.requestFocus();
            getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE | WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
            editor.post(() -> {
                if (isFinishing() || isDestroyed() || !editor.hasFocus()) return;
                InputMethodManager keyboard = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
                if (keyboard != null) keyboard.showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT);
            });
        } else getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE | WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN);
    }
    private TextView pill(String text) {
        TextView view = label(text, 14, "sans-serif-light"); view.setTextColor(accent);
        view.setGravity(Gravity.CENTER); view.setMinHeight(dp(44));
        view.setPadding(dp(12), dp(8), dp(12), dp(8)); view.setBackground(glass(24)); return view;
    }
    private Uri noteUri() { return ContentUris.withAppendedId(NotesProvider.CONTENT_URI, noteId); }
    private void unavailable() {
        Toast.makeText(this, "No se pudo abrir la nota", Toast.LENGTH_SHORT).show();
        deleted = true; finish();
    }
    private boolean blank(String text) {
        for (int i = 0; i < text.length(); i++) {
            if (!Character.isWhitespace(text.charAt(i)) && !Character.isSpaceChar(text.charAt(i))) return false;
        }
        return true;
    }
    private boolean saveNote() {
        if (editor == null || deleted) return true;
        String body = editor.getText().toString();
        try {
            if (blank(body)) {
                if (noteId >= 0) { getContentResolver().delete(noteUri(), null, null); noteId = -1; }
                savedBody = body; savedPinned = pinned; return true;
            }
            if (noteId >= 0 && body.equals(savedBody) && pinned == savedPinned) return true;
            ContentValues values = new ContentValues(); values.put("body", body); values.put("pinned", pinned ? 1 : 0);
            if (noteId < 0) {
                Uri inserted = getContentResolver().insert(NotesProvider.CONTENT_URI, values);
                if (inserted == null) throw new IllegalStateException("Insert failed");
                noteId = ContentUris.parseId(inserted);
            } else if (getContentResolver().update(noteUri(), values, null, null) == 0) {
                Toast.makeText(this, "La nota ya no existe", Toast.LENGTH_SHORT).show(); return false;
            }
            savedBody = body; savedPinned = pinned; return true;
        } catch (RuntimeException failure) {
            Toast.makeText(this, "No se pudo guardar la nota", Toast.LENGTH_SHORT).show(); return false;
        }
    }
    private void confirmDelete() {
        new AlertDialog.Builder(this).setTitle("¿Borrar nota?").setMessage("Esta acción no se puede deshacer.")
                .setNegativeButton("Cancelar", null).setPositiveButton("Borrar", (dialog, which) -> {
                    try {
                        if (noteId >= 0) getContentResolver().delete(noteUri(), null, null);
                        deleted = true; finish();
                    } catch (RuntimeException failure) { Toast.makeText(this, "No se pudo borrar la nota", Toast.LENGTH_SHORT).show(); }
                }).show();
    }
    @Override protected void onPause() { saveNote(); super.onPause(); }
    @Override protected void onSaveInstanceState(Bundle state) {
        saveNote();
        state.putLong("note_id", noteId); state.putBoolean("pinned", pinned); state.putBoolean("deleted", deleted);
        state.putString("saved_body", savedBody); state.putBoolean("saved_pinned", savedPinned);
        if (editor != null) {
            state.putString("body", editor.getText().toString()); state.putInt("selection_start", editor.getSelectionStart());
            state.putInt("selection_end", editor.getSelectionEnd());
        }
        super.onSaveInstanceState(state);
    }
    @Override public void finish() { if (saveNote()) super.finish(); }
}
