package com.scratch.iosgallery;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.*;
import android.widget.*;

import java.util.ArrayList;
import java.util.List;

/** Photo/video grid on glass over the wallpaper; follows the system day/night mode. */
public class GalleryActivity extends Activity {
    private static final int COLS = 3;
    private float d;
    private boolean night;
    private int text, text2, scrim, glass, glassStroke, accent;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final List<Media.Item> all = new ArrayList<>();
    private final List<Media.Item> shown = new ArrayList<>();
    private int filter = 0;                       // 0 all, 1 photos, 2 videos
    private GridView grid;
    private TextView count, empty;
    private final TextView[] chips = new TextView[3];
    private BaseAdapter adapter;
    private int cell;
    private android.os.Parcelable pendingGridState;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (b != null) {
            filter = Math.max(0, Math.min(2, b.getInt("filter", 0)));
            pendingGridState = b.getParcelable("grid_state");
        }
        boolean compact = getResources().getConfiguration().screenHeightDp < 400;
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        text2 = night ? 0xB3FFFFFF : 0x9914123A;
        scrim = night ? 0x9914123A : 0x66F6F5FF;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        glassStroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;

        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        FrameLayout root = new FrameLayout(this);
        View sc = new View(this);
        sc.setBackgroundColor(scrim);
        root.addView(sc, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding(0, (int) (24 * d), 0, 0);

        TextView title = new TextView(this);
        title.setText("Fotos");
        title.setTextColor(text);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, compact ? 24 : 34);
        title.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        title.setPadding((int) (22 * d), (int) ((compact ? 4 : 12) * d), 0, 0);
        col.addView(title);
        count = new TextView(this);
        count.setTextColor(text2);
        count.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        count.setPadding((int) (24 * d), 0, 0, (int) (8 * d));
        col.addView(count);

        LinearLayout chipRow = new LinearLayout(this);
        chipRow.setPadding((int) (20 * d), 0, (int) (20 * d), (int) (10 * d));
        String[] names = {"Todo", "Fotos", "Vídeos"};
        for (int i = 0; i < 3; i++) {
            final int idx = i;
            TextView t = new TextView(this);
            t.setText(names[i]);
            t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
            t.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
            t.setPadding((int) (16 * d), (int) (7 * d), (int) (16 * d), (int) (7 * d));
            t.setOnClickListener(v -> { pendingGridState = null; filter = idx; applyFilter(); });
            chips[i] = t;
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
            lp.rightMargin = (int) (8 * d);
            chipRow.addView(t, lp);
        }
        col.addView(chipRow);

        int w = getResources().getDisplayMetrics().widthPixels;
        int gap = (int) (2 * d);
        cell = (w - gap * (COLS - 1)) / COLS;
        FrameLayout box = new FrameLayout(this);
        grid = new GridView(this);
        grid.setNumColumns(COLS);
        grid.setHorizontalSpacing(gap);
        grid.setVerticalSpacing(gap);
        grid.setSelector(new android.graphics.drawable.ColorDrawable(Color.TRANSPARENT));
        adapter = new BaseAdapter() {
            @Override public int getCount() { return shown.size(); }
            @Override public Object getItem(int i) { return shown.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public View getView(int i, View v, ViewGroup p) {
                Thumb t = v instanceof Thumb ? (Thumb) v : new Thumb(GalleryActivity.this);
                t.bind(shown.get(i));
                return t;
            }
        };
        grid.setAdapter(adapter);
        grid.addOnLayoutChangeListener((v, l, t, r, btm, oldL, oldT, oldR, oldB) -> {
            int next = Math.max(1, (r - l - gap * (COLS - 1)) / COLS);
            if (next != cell) { cell = next; adapter.notifyDataSetChanged(); }
        });
        grid.setOnItemClickListener((p, v, i, id) -> {
            Media.current = new ArrayList<>(shown);
            startActivity(new Intent(this, ViewerActivity.class).putExtra("pos", i));
            { int enterId = getResources().getIdentifier("app_enter", "anim", getPackageName()); if (enterId != 0) overridePendingTransition(enterId, 0); }
        });
        empty = new TextView(this);
        empty.setText("Sin fotos ni vídeos");
        empty.setTextColor(text2);
        empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        empty.setGravity(Gravity.CENTER);
        box.addView(empty, new FrameLayout.LayoutParams(-1, -1));
        box.addView(grid, new FrameLayout.LayoutParams(-1, -1));
        grid.setEmptyView(empty);
        col.addView(box, new LinearLayout.LayoutParams(-1, 0, 1f));
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            col.setPadding(col.getPaddingLeft(), insets.getSystemWindowInsetTop(), col.getPaddingRight(), col.getPaddingBottom());
            return insets;
        });
        setContentView(root);
        styleChips();
    }

    @Override
    protected void onResume() {
        super.onResume();
        new Thread(() -> {
            final List<Media.Item> items = Media.query(getContentResolver());
            ui.post(() -> {
                if (isFinishing() || isDestroyed()) return;
                all.clear(); all.addAll(items); applyFilter();
                if (pendingGridState != null) {
                    grid.onRestoreInstanceState(pendingGridState); pendingGridState = null;
                }
            });
        }).start();
    }

    @Override protected void onSaveInstanceState(Bundle state) {
        state.putInt("filter", filter);
        state.putParcelable("grid_state", pendingGridState != null ? pendingGridState : grid.onSaveInstanceState());
        super.onSaveInstanceState(state);
    }

    @Override
    public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }

    private void applyFilter() {
        shown.clear();
        for (Media.Item it : all) if (filter == 0 || (filter == 1 && it.type == Media.IMAGE) || (filter == 2 && it.type == Media.VIDEO)) shown.add(it);
        count.setText(shown.size() + (shown.size() == 1 ? " elemento" : " elementos"));
        adapter.notifyDataSetChanged();
        styleChips();
    }

    private void styleChips() {
        for (int i = 0; i < 3; i++) {
            GradientDrawable g = new GradientDrawable();
            g.setCornerRadius(20 * d);
            boolean on = i == filter;
            g.setColor(on ? accent : glass);
            g.setStroke(Math.max(1, (int) d), on ? accent : glassStroke);
            chips[i].setBackground(g);
            chips[i].setTextColor(on ? Color.WHITE : text);
        }
    }

    /** Square thumbnail with a small play badge on videos. */
    private class Thumb extends ImageView {
        private Media.Item item;
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        Thumb(Context c) {
            super(c);
            setScaleType(ScaleType.CENTER_CROP);
            setLayoutParams(new AbsListView.LayoutParams(cell, cell));
            setBackgroundColor(glass);
        }
        void bind(final Media.Item it) {
            item = it;
            setImageBitmap(null);
            Media.thumb(it, cell, b -> { if (item == it) setImageBitmap(b); });
        }
        @Override protected void onMeasure(int w, int h) { setMeasuredDimension(cell, cell); }
        @Override protected void onDraw(Canvas cv) {
            super.onDraw(cv);
            if (item != null && item.type == Media.VIDEO) {
                float r = 13 * d, cx = getWidth() - r - 6 * d, cy = getHeight() - r - 6 * d;
                p.setColor(0x99000000);
                cv.drawCircle(cx, cy, r, p);
                cv.save();
                cv.translate(cx - r * 0.55f, cy - r * 0.55f);
                Icons.draw(cv, "play", r * 1.1f, Color.WHITE, 2f);
                cv.restore();
            }
        }
    }

    /** Aurora exit transition (res/anim/app_exit): soft zoom-out and fade instead of the ROM default. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
