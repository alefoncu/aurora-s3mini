package com.scratch.iosnotes;

import android.content.ContentProvider;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.text.TextUtils;

/** Public provider for notes and shared-text integrations. */
public class NotesProvider extends ContentProvider {
    public static final Uri CONTENT_URI = Uri.parse("content://com.scratch.iosnotes/notes");
    private static final int NOTES = 1, NOTE = 2;
    private static final UriMatcher MATCHER = new UriMatcher(UriMatcher.NO_MATCH);
    static {
        MATCHER.addURI("com.scratch.iosnotes", "notes", NOTES);
        MATCHER.addURI("com.scratch.iosnotes", "notes/#", NOTE);
    }
    private NotesDb helper;

    @Override public boolean onCreate() {
        if (getContext() == null) return false;
        helper = new NotesDb(getContext());
        return true;
    }

    private int match(Uri uri) {
        int match = MATCHER.match(uri);
        if (match != NOTES && match != NOTE) throw new IllegalArgumentException("Unknown notes URI: " + uri);
        return match;
    }
    private SQLiteDatabase database() {
        if (helper == null) throw new IllegalStateException("Notes provider is not initialized");
        return helper.getWritableDatabase();
    }
    private String where(Uri uri, String selection) {
        if (match(uri) == NOTES) return selection;
        // ContentUris validates the numeric segment; no untrusted text enters the SQL.
        String id = "_id = " + ContentUris.parseId(uri);
        return TextUtils.isEmpty(selection) ? id : id + " AND (" + selection + ")";
    }
    private void changed(Uri uri) {
        if (getContext() != null) getContext().getContentResolver().notifyChange(uri, null);
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection,
                                  String[] selectionArgs, String sortOrder) {
        Cursor cursor = database().query("notes", projection, where(uri, selection), selectionArgs,
                null, null, TextUtils.isEmpty(sortOrder) ? "pinned DESC, updated DESC" : sortOrder);
        if (cursor != null && getContext() != null) {
            cursor.setNotificationUri(getContext().getContentResolver(), uri);
        }
        return cursor;
    }

    private ContentValues values(ContentValues source, boolean inserting) {
        ContentValues values = new ContentValues();
        if (inserting || (source != null && source.containsKey("body"))) {
            String body = source == null ? null : source.getAsString("body");
            if (body == null) throw new IllegalArgumentException("A note requires a body");
            values.put("body", body);
        }
        if (source != null && source.containsKey("pinned")) {
            Integer pinned = source.getAsInteger("pinned");
            values.put("pinned", pinned != null && pinned != 0 ? 1 : 0);
        }
        values.put("updated", System.currentTimeMillis());
        return values;
    }

    @Override public Uri insert(Uri uri, ContentValues source) {
        if (match(uri) != NOTES) throw new IllegalArgumentException("Insert requires the notes collection");
        long id = database().insertOrThrow("notes", null, values(source, true));
        Uri result = ContentUris.withAppendedId(CONTENT_URI, id);
        changed(result);
        return result;
    }

    @Override public int update(Uri uri, ContentValues source, String selection, String[] selectionArgs) {
        String where = where(uri, selection);
        int count = database().update("notes", values(source, false), where, selectionArgs);
        if (count > 0) changed(uri);
        return count;
    }

    @Override public int delete(Uri uri, String selection, String[] selectionArgs) {
        int count = database().delete("notes", where(uri, selection), selectionArgs);
        if (count > 0) changed(uri);
        return count;
    }

    @Override public String getType(Uri uri) {
        return match(uri) == NOTES ? "vnd.android.cursor.dir/vnd.com.scratch.iosnotes.note"
                : "vnd.android.cursor.item/vnd.com.scratch.iosnotes.note";
    }

    @Override public void shutdown() {
        if (helper != null) helper.close();
        super.shutdown();
    }
}
