package com.scratch.iosnotes;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

/** Local storage shared by the notes provider. */
public class NotesDb extends SQLiteOpenHelper {
    public NotesDb(Context context) { super(context, "notes.db", null, 1); }

    @Override public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE notes (_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "body TEXT NOT NULL, updated INTEGER NOT NULL, pinned INTEGER NOT NULL DEFAULT 0)");
    }

    @Override public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        // Version 1 is the initial schema; future versions must preserve existing notes.
    }
}
