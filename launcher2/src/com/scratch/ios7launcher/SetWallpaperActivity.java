package com.scratch.ios7launcher;

import android.app.Activity;
import android.app.WallpaperManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.Log;

/** Helper: `am start -n com.scratch.ios7launcher/.SetWallpaperActivity --es path /sdcard/x.jpg` sets home + lock wallpaper. */
public class SetWallpaperActivity extends Activity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        String path = getIntent().getStringExtra("path");
        try {
            Bitmap bmp = BitmapFactory.decodeFile(path);
            Log.d("SetWallpaper", "decoded " + path + " -> " + (bmp == null ? "null" : bmp.getWidth() + "x" + bmp.getHeight()));
            if (bmp != null) {
                WallpaperManager wm = WallpaperManager.getInstance(this);
                int r = wm.setBitmap(bmp, null, true, WallpaperManager.FLAG_SYSTEM | WallpaperManager.FLAG_LOCK);
                Log.d("SetWallpaper", "setBitmap id=" + r);
            }
        } catch (Exception e) {
            Log.e("SetWallpaper", "failed", e);
        }
        finish();
    }
}
