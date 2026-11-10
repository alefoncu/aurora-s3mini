package com.scratch.iosnotes;

import android.app.Activity;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;

/** Shared wallpaper, glass and typography, matching the weather app. */
public abstract class NotesBase extends Activity {
    protected float density;
    protected boolean night;
    protected int ink, subtle, glass, stroke, accent;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        density = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        ink = night ? Color.WHITE : 0xFF14123A;
        subtle = night ? 0xB3FFFFFF : 0x9914123A;
        glass = night ? 0x2EFFFFFF : 0x66FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xB3FFFFFF;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
    }
    protected int dp(float value) { return (int) (value * density + 0.5f); }
    protected int statusInset() {
        int id = getResources().getIdentifier("status_bar_height", "dimen", "android");
        return id == 0 ? dp(24) : getResources().getDimensionPixelSize(id);
    }
    protected TextView label(String text, int size, String font) {
        TextView view = new TextView(this); view.setText(text); view.setTextColor(ink);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, size);
        view.setTypeface(Typeface.create(font, Typeface.NORMAL)); return view;
    }
    protected GradientDrawable glass(float radius) {
        GradientDrawable bg = new GradientDrawable(); bg.setColor(glass); bg.setCornerRadius(dp(radius));
        bg.setStroke(Math.max(1, dp(0.5f)), stroke); return bg;
    }
    protected FrameLayout root() {
        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(Color.TRANSPARENT);
        window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this); scrim.setBackgroundColor(night ? 0x6614123A : 0x33F6F5FF);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1)); return root;
    }
    @Override public void onConfigurationChanged(Configuration config) { super.onConfigurationChanged(config); recreate(); }
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
