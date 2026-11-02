package com.scratch.iosgallery;

import android.content.ContentResolver;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.util.LruCache;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Media items from the MediaStore plus a small thumbnail loader (low RAM: 2 threads, 5 MB cache). */
final class Media {
    static final int IMAGE = 1, VIDEO = 3;

    static final class Item {
        final long id; final String path; final int type; final long date;
        Item(long id, String path, int type, long date) { this.id = id; this.path = path; this.type = type; this.date = date; }
    }

    /** Shared with the viewer: the list currently shown by the grid. */
    static List<Item> current = new ArrayList<>();

    private static final ExecutorService POOL = Executors.newFixedThreadPool(2);
    private static final Handler UI = new Handler(Looper.getMainLooper());
    private static final LruCache<String, Bitmap> CACHE = new LruCache<String, Bitmap>(5 * 1024 * 1024) {
        @Override protected int sizeOf(String k, Bitmap b) { return b.getByteCount(); }
    };

    interface Done { void on(Bitmap b); }

    static List<Item> query(ContentResolver cr) {
        List<Item> out = new ArrayList<>();
        Cursor c = null;
        try {
            c = cr.query(MediaStore.Files.getContentUri("external"),
                    new String[]{MediaStore.Files.FileColumns._ID, MediaStore.Files.FileColumns.DATA,
                            MediaStore.Files.FileColumns.MEDIA_TYPE, MediaStore.Files.FileColumns.DATE_MODIFIED},
                    "(" + MediaStore.Files.FileColumns.MEDIA_TYPE + "=1 OR " + MediaStore.Files.FileColumns.MEDIA_TYPE + "=3) AND "
                            + MediaStore.Files.FileColumns.DATA + " NOT LIKE '%/.thumbnails/%'",
                    null, MediaStore.Files.FileColumns.DATE_MODIFIED + " DESC LIMIT 800");
            while (c != null && c.moveToNext()) {
                String p = c.getString(1);
                if (p != null && new File(p).exists()) out.add(new Item(c.getLong(0), p, c.getInt(2), c.getLong(3) * 1000L));
            }
        } catch (Exception ignored) { } finally { if (c != null) c.close(); }
        return out;
    }

    /** Square, centre-cropped thumbnail, decoded off the UI thread. */
    static void thumb(final Item it, final int size, final Done done) {
        Bitmap hit = CACHE.get(it.path);
        if (hit != null) { done.on(hit); return; }
        POOL.execute(() -> {
            Bitmap b = it.type == VIDEO ? videoThumb(it.path, size) : decode(it.path, size, true);
            if (b != null) {
                CACHE.put(it.path, b);
                final Bitmap fb = b;
                UI.post(() -> done.on(fb));
            }
        });
    }

    private static Bitmap videoThumb(String path, int size) {
        Bitmap b = android.media.ThumbnailUtils.createVideoThumbnail(path, MediaStore.Video.Thumbnails.MINI_KIND);
        return b == null ? null : crop(b, size);
    }

    /** Decodes with sub-sampling, applies the EXIF rotation, optionally centre-crops to a square. */
    static Bitmap decode(String path, int target, boolean square) {
        try {
            BitmapFactory.Options o = new BitmapFactory.Options();
            o.inJustDecodeBounds = true;
            BitmapFactory.decodeFile(path, o);
            int s = 1;
            while (o.outWidth / (s * 2) >= target && o.outHeight / (s * 2) >= target) s *= 2;
            o.inJustDecodeBounds = false;
            o.inSampleSize = s;
            Bitmap b = BitmapFactory.decodeFile(path, o);
            if (b == null) return null;
            int deg = rotation(path);
            if (deg != 0) {
                Matrix m = new Matrix();
                m.postRotate(deg);
                Bitmap r = Bitmap.createBitmap(b, 0, 0, b.getWidth(), b.getHeight(), m, true);
                if (r != b) b.recycle();
                b = r;
            }
            return square ? crop(b, target) : b;
        } catch (OutOfMemoryError e) {
            return null;
        }
    }

    private static Bitmap crop(Bitmap b, int size) {
        int w = b.getWidth(), h = b.getHeight(), m = Math.min(w, h);
        Bitmap sq = Bitmap.createBitmap(b, (w - m) / 2, (h - m) / 2, m, m);
        Bitmap out = Bitmap.createScaledBitmap(sq, size, size, true);
        if (sq != b) sq.recycle();
        if (out != b) b.recycle();
        return out;
    }

    private static int rotation(String path) {
        try {
            int o = new ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1);
            return o == 6 ? 90 : o == 3 ? 180 : o == 8 ? 270 : 0;
        } catch (Exception e) {
            return 0;
        }
    }
}
