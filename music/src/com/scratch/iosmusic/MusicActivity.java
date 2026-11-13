package com.scratch.iosmusic;

import android.app.Activity;
import android.content.*;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.database.Cursor;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.media.*;
import android.net.Uri;
import android.os.*;
import android.provider.MediaStore;
import android.view.*;
import android.widget.*;
import java.lang.ref.WeakReference;
import java.util.*;
import java.util.concurrent.*;

/** Aurora music: framework-only UI and an Activity-owned player retained on recreation. */
public class MusicActivity extends Activity {
    private static final PlayerState PLAYER = new PlayerState();
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler handler = new Handler();
    private float d;
    private boolean night, destroyed, now, loading = true, seeking;
    private int text, accent, glass, stroke, tab, artRequest;
    private String group;
    private LinearLayout col, content;
    private TextView heading, miniTitle, miniPlay, bigPlay, shuffle, repeat, elapsed, total, songTitle, songArtist;
    private SeekBar progress;
    private ImageView art;
    private TextView artNote;
    private Song shownArt;
    private final ArrayList<Song> library = new ArrayList<>();
    private final ArrayList<Object> rows = new ArrayList<>();
    private final Runnable ticker = new Runnable() {
        public void run() { if (!destroyed) { refresh(); handler.postDelayed(this, 500); } }
    };

    private static class Song {
        final Uri uri;
        final String title, artist, album;
        final long duration, albumId;
        Song(Uri u, String t, String a, String al, long du, long id) {
            uri = u; title = clean(t, "Sin título"); artist = clean(a, "Artista desconocido");
            album = clean(al, "Álbum desconocido"); duration = du; albumId = id;
        }
        static String clean(String v, String fallback) { return v == null || v.trim().length() == 0 || "<unknown>".equals(v) ? fallback : v; }
    }

    /** Contains no strong Activity reference; listeners are rebound via the weak owner. */
    private static class PlayerState implements AudioManager.OnAudioFocusChangeListener {
        final ArrayList<Song> queue = new ArrayList<>();
        final Random random = new Random();
        WeakReference<MusicActivity> owner = new WeakReference<>(null);
        MediaPlayer player;
        AudioManager audio;
        Song current;
        boolean ready, preparing, shuffle, resumeOnFocus, focused, ducked;
        int repeat; // 0 off, 1 all, 2 one
        String error;
        void update() { MusicActivity a = owner.get(); if (a != null && !a.destroyed) a.refresh(); }
        void fail(String message) { releasePlayer(); error = message; abandon(); update(); }
        void releasePlayer() {
            ready = preparing = false;
            if (player != null) { player.setOnPreparedListener(null); player.setOnCompletionListener(null); player.setOnErrorListener(null); player.release(); player = null; }
        }
        boolean playing() { try { return ready && player != null && player.isPlaying(); } catch (IllegalStateException e) { return false; } }
        int position() { try { return ready ? player.getCurrentPosition() : 0; } catch (RuntimeException e) { return 0; } }
        int duration() { try { return ready ? Math.max(0, player.getDuration()) : 0; } catch (RuntimeException e) { return 0; } }
        boolean focus() {
            focused = audio != null && audio.requestAudioFocus(this, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
            return focused;
        }
        void abandon() { resumeOnFocus = false; ducked = false; if (audio != null) audio.abandonAudioFocus(this); focused = false; }
        void play(Context context, Song song) {
            releasePlayer(); abandon(); current = song; error = null;
            if (!focus()) { error = "El audio está ocupado. Pulsa reproducir para reintentar."; update(); return; }
            try {
                player = new MediaPlayer();
                player.setAudioStreamType(AudioManager.STREAM_MUSIC);
                player.setWakeMode(context.getApplicationContext(), PowerManager.PARTIAL_WAKE_LOCK);
                player.setDataSource(context.getApplicationContext(), song.uri);
                preparing = true;
                player.setOnPreparedListener(p -> {
                    if (p != player) return;
                    preparing = false; ready = true;
                    if (focused) { try { p.setVolume(ducked ? 0.2f : 1f, ducked ? 0.2f : 1f); p.start(); } catch (RuntimeException e) { fail("No se pudo reproducir este archivo."); } }
                    update();
                });
                player.setOnErrorListener((p, what, extra) -> { if (p == player) fail("No se puede abrir esta canción. Prueba con otra."); return true; });
                player.setOnCompletionListener(p -> {
                    if (repeat == 2) { try { p.seekTo(0); p.start(); } catch (RuntimeException e) { fail("No se pudo repetir la canción."); } }
                    else if (!next(1, true)) { abandon(); update(); }
                });
                player.prepareAsync();
            } catch (Exception e) { fail("Archivo no disponible o sin permiso de lectura."); }
            update();
        }
        void toggle() {
            MusicActivity a = owner.get(); if (a == null) return;
            if (preparing) return;
            if (current == null) { if (!queue.isEmpty()) play(a, queue.get(0)); return; }
            if (!ready) { play(a, current); return; }
            try {
                if (playing()) { player.pause(); abandon(); }
                else if (focus()) { player.setVolume(1f, 1f); player.start(); error = null; }
            } catch (RuntimeException e) { fail("No se pudo reanudar la canción."); }
            update();
        }
        boolean next(int direction, boolean automatic) {
            MusicActivity a = owner.get(); if (a == null || queue.isEmpty()) return false;
            int index = -1;
            for (int i = 0; i < queue.size(); i++) if (current != null && queue.get(i).uri.equals(current.uri)) { index = i; break; }
            if (direction < 0 && position() > 3000) { seek(0); return true; }
            int next = index + direction;
            if (shuffle && queue.size() > 1) { do { next = random.nextInt(queue.size()); } while (next == index); }
            else if (automatic && next >= queue.size() && repeat == 0) return false;
            next = (next % queue.size() + queue.size()) % queue.size();
            play(a, queue.get(next)); return true;
        }
        void seek(int position) { try { if (ready) player.seekTo(position); } catch (RuntimeException e) { fail("No se pudo cambiar la posición."); } }
        public void onAudioFocusChange(int change) {
            try {
                if (change == AudioManager.AUDIOFOCUS_GAIN) {
                    focused = true; ducked = false;
                    if (player != null) { player.setVolume(1f, 1f); if (resumeOnFocus && ready) player.start(); }
                    resumeOnFocus = false;
                } else if (change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
                    ducked = true;
                    if (player != null && ready) player.setVolume(0.2f, 0.2f);
                } else {
                    resumeOnFocus = change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT && (playing() || preparing);
                    focused = false;
                    if (playing()) player.pause();
                    if (change == AudioManager.AUDIOFOCUS_LOSS) abandon();
                }
            } catch (RuntimeException e) { fail("Se ha interrumpido la reproducción."); }
            update();
        }
    }

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        setVolumeControlStream(AudioManager.STREAM_MUSIC);
        PLAYER.owner = new WeakReference<>(this);
        PLAYER.audio = (AudioManager) getApplicationContext().getSystemService(AUDIO_SERVICE);
        if (state != null) { now = state.getBoolean("now"); tab = state.getInt("tab"); group = state.getString("group"); }
        build();
        if (state == null) openIntent(getIntent());
        loadLibrary();
    }
    private int dp(float value) { return (int) (value * d + 0.5f); }
    private GradientDrawable glass(float radius) {
        GradientDrawable g = new GradientDrawable(); g.setColor(glass); g.setCornerRadius(dp(radius)); g.setStroke(Math.max(1, dp(1)), stroke); return g;
    }
    private TextView label(String value, float size, boolean thin) {
        TextView t = new TextView(this); t.setText(value); t.setTextColor(text); t.setTextSize(size);
        t.setTypeface(Typeface.create(thin ? "sans-serif-thin" : "sans-serif-light", Typeface.NORMAL)); return t;
    }
    private void spring(View v) {
        v.setOnTouchListener((view, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                view.animate().cancel(); view.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
            } else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) {
                view.animate().scaleX(1f).scaleY(1f).setDuration(320).setInterpolator(new android.view.animation.OvershootInterpolator(3.2f)).start();
            } return false;
        });
    }
    private TextView button(String value, String description, Runnable action) {
        TextView v = label(value, 23, false); v.setGravity(Gravity.CENTER); v.setTextColor(accent); v.setBackground(glass(20));
        v.setContentDescription(description); spring(v); v.setOnClickListener(w -> action.run()); return v;
    }
    private boolean compact() { return getResources().getConfiguration().screenHeightDp < 400; }
    private void build() {
        seeking = false;
        artRequest++; shownArt = null;
        miniTitle = miniPlay = bigPlay = shuffle = repeat = elapsed = total = songTitle = songArtist = null;
        progress = null; art = null; artNote = null;
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this); scrim.setBackgroundColor(night ? 0x9914123A : 0x66F6F5FF); root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));
        col = new LinearLayout(this); col.setOrientation(LinearLayout.VERTICAL); col.setPadding(dp(12), dp(android.os.Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode() ? 0 : 24), dp(12), dp(8)); root.addView(col, new FrameLayout.LayoutParams(-1, -1));
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            col.setPadding(col.getPaddingLeft(), insets.getSystemWindowInsetTop(), col.getPaddingRight(), col.getPaddingBottom());
            return insets;
        });
        LinearLayout header = new LinearLayout(this); header.setGravity(Gravity.CENTER_VERTICAL);
        if (now || group != null) { TextView back = button("‹", "Volver a la biblioteca", () -> { if (now) now = false; else group = null; build(); }); header.addView(back, new LinearLayout.LayoutParams(dp(44), dp(44))); }
        heading = label(now ? "Reproduciendo" : group != null ? group : new String[]{"Canciones", "Artistas", "Álbumes"}[tab], now ? 26 : 32, true);
        heading.setSingleLine(true); heading.setEllipsize(android.text.TextUtils.TruncateAt.END); heading.setPadding(dp(8), 0, 0, 0); header.addView(heading, new LinearLayout.LayoutParams(0, dp(56), 1)); heading.setGravity(Gravity.CENTER_VERTICAL);
        col.addView(header);
        content = new LinearLayout(this); content.setOrientation(LinearLayout.VERTICAL); col.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));
        if (now) buildNow(); else buildLibrary();
        if (!now || !compact()) {
            if (!compact() || PLAYER.current != null) buildMini();
            buildTabs();
        }
        setContentView(root); refresh();
    }
    private void buildMini() {
        LinearLayout mini = new LinearLayout(this); mini.setGravity(Gravity.CENTER_VERTICAL); mini.setPadding(dp(10), dp(4), dp(4), dp(4)); mini.setBackground(glass(18));
        miniTitle = label("Elige una canción", 15, false); miniTitle.setSingleLine(true); miniTitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
        mini.addView(miniTitle, new LinearLayout.LayoutParams(0, -1, 1)); miniTitle.setGravity(Gravity.CENTER_VERTICAL);
        mini.setOnClickListener(v -> { now = true; build(); }); spring(miniTitle); miniTitle.setOnClickListener(v -> { now = true; build(); });
        miniPlay = button("▶", "Reproducir o pausar", () -> PLAYER.toggle()); mini.addView(miniPlay, new LinearLayout.LayoutParams(dp(46), dp(46)));
        mini.addView(button("››", "Siguiente canción", () -> PLAYER.next(1, false)), new LinearLayout.LayoutParams(dp(46), dp(46)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(58)); lp.setMargins(0, dp(6), 0, dp(6)); col.addView(mini, lp);
    }
    private void buildTabs() {
        LinearLayout tabs = new LinearLayout(this); tabs.setBackground(glass(20));
        String[] names = {"Canciones", "Artistas", "Álbumes"};
        for (int i = 0; i < names.length; i++) {
            final int selected = i;
            TextView t = label(names[i], 14, false); t.setGravity(Gravity.CENTER); t.setTextColor(tab == i && !now ? accent : text); spring(t);
            t.setOnClickListener(v -> { now = false; tab = selected; group = null; build(); }); tabs.addView(t, new LinearLayout.LayoutParams(0, dp(48), 1));
        } col.addView(tabs);
    }
    private void buildLibrary() {
        rows.clear();
        if (loading || library.isEmpty()) {
            TextView empty = label(loading ? "Buscando tu música…" : "Tu música empieza aquí\n\nCopia tus canciones al teléfono y vuelve a abrir Música.", 21, true);
            empty.setGravity(Gravity.CENTER); empty.setPadding(dp(20), dp(12), dp(20), dp(12)); content.addView(empty, new LinearLayout.LayoutParams(-1, 0, 1));
            if (!loading) content.addView(button("Actualizar", "Volver a buscar música", () -> loadLibrary()), new LinearLayout.LayoutParams(-1, dp(48)));
            return;
        }
        if (tab == 0 || group != null) {
            for (Song s : library) if (group == null || group.equals(tab == 1 ? s.artist : s.album)) rows.add(s);
        } else {
            TreeSet<String> groups = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
            for (Song s : library) groups.add(tab == 1 ? s.artist : s.album);
            rows.addAll(groups);
        }
        ListView list = new ListView(this); list.setCacheColorHint(Color.TRANSPARENT); list.setDivider(new android.graphics.drawable.ColorDrawable(stroke)); list.setDividerHeight(dp(1));
        list.setAdapter(new BaseAdapter() {
            public int getCount() { return rows.size(); }
            public Object getItem(int p) { return rows.get(p); }
            public long getItemId(int p) { return p; }
            public View getView(int p, View recycled, android.view.ViewGroup parent) {
                Object row = rows.get(p);
                LinearLayout line = new LinearLayout(MusicActivity.this); line.setPadding(dp(10), dp(9), dp(8), dp(9)); line.setGravity(Gravity.CENTER_VERTICAL);
                LinearLayout titles = new LinearLayout(MusicActivity.this); titles.setOrientation(LinearLayout.VERTICAL);
                TextView name = label(row instanceof Song ? ((Song) row).title : (String) row, 18, false); name.setSingleLine(true); name.setEllipsize(android.text.TextUtils.TruncateAt.END); titles.addView(name);
                String sub;
                if (row instanceof Song) sub = ((Song) row).artist;
                else { int count = 0; for (Song s : library) if (row.equals(tab == 1 ? s.artist : s.album)) count++; sub = count + (count == 1 ? " canción" : " canciones"); }
                TextView subtitle = label(sub, 13, false); subtitle.setAlpha(0.65f); subtitle.setSingleLine(true); subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END); titles.addView(subtitle);
                line.addView(titles, new LinearLayout.LayoutParams(0, -2, 1));
                TextView length = label(row instanceof Song ? time(((Song) row).duration) : "›", 13, false); length.setPadding(dp(6), 0, 0, 0); line.addView(length); return line;
            }
        });
        list.setOnItemClickListener((parent, view, position, id) -> {
            Object row = rows.get(position);
            if (row instanceof Song) { PLAYER.queue.clear(); for (Object item : rows) if (item instanceof Song) PLAYER.queue.add((Song) item); PLAYER.play(this, (Song) row); if (compact() && miniPlay == null) build(); }
            else { group = (String) row; build(); }
        });
        content.addView(list, new LinearLayout.LayoutParams(-1, -1));
    }
    private void buildNow() {
        if (compact()) {
            LinearLayout host = content;
            ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true);
            content = new LinearLayout(this); content.setOrientation(LinearLayout.VERTICAL);
            scroll.addView(content, new ScrollView.LayoutParams(-1, -2));
            host.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
        }
        FrameLayout cover = new FrameLayout(this) {
            @Override protected void onMeasure(int widthSpec, int heightSpec) {
                int side = Math.min(View.MeasureSpec.getSize(widthSpec), View.MeasureSpec.getSize(heightSpec));
                super.onMeasure(View.MeasureSpec.makeMeasureSpec(side, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(side, View.MeasureSpec.EXACTLY));
            }
        };
        GradientDrawable gradient = new GradientDrawable(GradientDrawable.Orientation.TL_BR, new int[]{0xFFFF82B8, 0xFFE93994, 0xFF8B48C7}); gradient.setCornerRadius(dp(24)); cover.setBackground(gradient); cover.setClipToOutline(true);
        art = new ImageView(this); art.setScaleType(ImageView.ScaleType.CENTER_CROP); cover.addView(art, new FrameLayout.LayoutParams(-1, -1));
        artNote = label("♫", 86, true); artNote.setGravity(Gravity.CENTER); artNote.setTextColor(Color.WHITE); cover.addView(artNote, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout.LayoutParams artwork = new LinearLayout.LayoutParams(-1, compact() ? dp(80) : 0, compact() ? 0 : 1); artwork.gravity = Gravity.CENTER_HORIZONTAL; artwork.setMargins(dp(26), dp(6), dp(26), dp(10)); content.addView(cover, artwork);
        songTitle = label("Elige una canción", 26, true); songTitle.setSingleLine(true); songTitle.setEllipsize(android.text.TextUtils.TruncateAt.END); content.addView(songTitle);
        songArtist = label("Tu biblioteca, a tu ritmo", 17, false); songArtist.setSingleLine(true); songArtist.setEllipsize(android.text.TextUtils.TruncateAt.END); songArtist.setTextColor(accent); content.addView(songArtist);
        progress = new SeekBar(this); progress.setProgressTintList(android.content.res.ColorStateList.valueOf(accent)); progress.setThumbTintList(android.content.res.ColorStateList.valueOf(accent));
        content.addView(progress, new LinearLayout.LayoutParams(-1, dp(48)));
        progress.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onStartTrackingTouch(SeekBar bar) { seeking = true; }
            public void onProgressChanged(SeekBar bar, int value, boolean user) { if (user) elapsed.setText(time(value)); }
            public void onStopTrackingTouch(SeekBar bar) { PLAYER.seek(bar.getProgress()); seeking = false; refresh(); }
        });
        LinearLayout times = new LinearLayout(this); elapsed = label("0:00", 12, false); total = label("0:00", 12, false); total.setGravity(Gravity.RIGHT);
        times.addView(elapsed, new LinearLayout.LayoutParams(0, dp(20), 1)); times.addView(total, new LinearLayout.LayoutParams(0, dp(20), 1)); content.addView(times);
        LinearLayout controls = new LinearLayout(this);
        controls.addView(button("‹‹", "Canción anterior", () -> PLAYER.next(-1, false)), new LinearLayout.LayoutParams(0, dp(52), 1));
        bigPlay = button("▶", "Reproducir o pausar", () -> PLAYER.toggle()); controls.addView(bigPlay, new LinearLayout.LayoutParams(0, dp(52), 1));
        controls.addView(button("››", "Siguiente canción", () -> PLAYER.next(1, false)), new LinearLayout.LayoutParams(0, dp(52), 1)); content.addView(controls);
        LinearLayout modes = new LinearLayout(this);
        shuffle = button("Aleatorio", "Cambiar reproducción aleatoria", () -> { PLAYER.shuffle = !PLAYER.shuffle; refresh(); }); shuffle.setTextSize(13);
        repeat = button("Repetir", "Cambiar modo de repetición", () -> { PLAYER.repeat = (PLAYER.repeat + 1) % 3; refresh(); }); repeat.setTextSize(13);
        modes.addView(shuffle, new LinearLayout.LayoutParams(0, dp(48), 1)); modes.addView(repeat, new LinearLayout.LayoutParams(0, dp(48), 1)); content.addView(modes);
    }
    private static String time(long ms) { long sec = Math.max(0, ms / 1000); return String.format(Locale.US, "%d:%02d", sec / 60, sec % 60); }
    private void refresh() {
        Song s = PLAYER.current;
        String status = PLAYER.error != null ? PLAYER.error : PLAYER.preparing ? "Cargando…" : s == null ? "Elige una canción" : s.title;
        if (miniTitle != null) miniTitle.setText(status);
        String play = PLAYER.playing() ? "Ⅱ" : "▶";
        if (miniPlay != null) { miniPlay.setText(play); miniPlay.setContentDescription(PLAYER.playing() ? "Pausar" : "Reproducir"); }
        if (bigPlay != null) { bigPlay.setText(play); bigPlay.setContentDescription(PLAYER.playing() ? "Pausar" : "Reproducir"); }
        if (songTitle != null) { songTitle.setText(s == null ? "Elige una canción" : s.title); songArtist.setText(PLAYER.error != null ? PLAYER.error : s == null ? "Tu biblioteca, a tu ritmo" : s.artist); }
        if (progress != null) {
            progress.setEnabled(PLAYER.ready); if (!seeking) { progress.setMax(PLAYER.duration()); progress.setProgress(PLAYER.position()); elapsed.setText(time(PLAYER.position())); } total.setText(time(PLAYER.duration()));
            shuffle.setAlpha(PLAYER.shuffle ? 1f : 0.5f); shuffle.setText(PLAYER.shuffle ? "Aleatorio · Sí" : "Aleatorio");
            repeat.setAlpha(PLAYER.repeat == 0 ? 0.5f : 1f); repeat.setText(PLAYER.repeat == 0 ? "Repetir · No" : PLAYER.repeat == 1 ? "Repetir · Todo" : "Repetir · Una");
            if (s != shownArt) { shownArt = s; loadArt(s); }
        }
    }
    private void loadArt(Song song) {
        final int request = ++artRequest;
        art.setImageDrawable(null); artNote.setVisibility(View.VISIBLE);
        if (song == null || song.albumId < 0) return;
        worker.execute(() -> {
            Bitmap bitmap = null;
            String path = null;
            try (Cursor cursor = getContentResolver().query(ContentUris.withAppendedId(MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI, song.albumId), new String[]{MediaStore.Audio.Albums.ALBUM_ART}, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) path = cursor.getString(0);
            } catch (Exception ignored) { }
            if (path != null) {
                try {
                    BitmapFactory.Options bounds = new BitmapFactory.Options(); bounds.inJustDecodeBounds = true; BitmapFactory.decodeFile(path, bounds);
                    BitmapFactory.Options options = new BitmapFactory.Options(); options.inSampleSize = 1;
                    while (bounds.outWidth / options.inSampleSize > 600 || bounds.outHeight / options.inSampleSize > 600) options.inSampleSize *= 2;
                    bitmap = BitmapFactory.decodeFile(path, options);
                } catch (Exception ignored) { } catch (OutOfMemoryError ignored) { }
            }
            final Bitmap result = bitmap;
            handler.post(() -> {
                if (destroyed || request != artRequest || art == null) { if (result != null) result.recycle(); return; }
                if (result != null) { art.setImageBitmap(result); artNote.setVisibility(View.GONE); }
            });
        });
    }
    private boolean permitted() { return Build.VERSION.SDK_INT < 23 || checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED; }
    private void loadLibrary() {
        if (!permitted()) { loading = false; if (!now) build(); requestPermissions(new String[]{android.Manifest.permission.READ_EXTERNAL_STORAGE}, 4); return; }
        loading = true; if (!now) build();
        worker.execute(() -> {
            ArrayList<Song> found = new ArrayList<>();
            boolean failed = false;
            String[] projection = {MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE, MediaStore.Audio.Media.ARTIST, MediaStore.Audio.Media.ALBUM, MediaStore.Audio.Media.DURATION, MediaStore.Audio.Media.ALBUM_ID};
            try (Cursor c = getContentResolver().query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, projection, MediaStore.Audio.Media.IS_MUSIC + " != 0", null, MediaStore.Audio.Media.TITLE + " COLLATE NOCASE ASC")) {
                if (c != null) while (!Thread.currentThread().isInterrupted() && c.moveToNext()) found.add(new Song(ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, c.getLong(0)), c.getString(1), c.getString(2), c.getString(3), c.getLong(4), c.getLong(5)));
            } catch (Exception e) { failed = true; }
            final boolean queryFailed = failed;
            handler.post(() -> {
                if (destroyed) return;
                library.clear(); library.addAll(found); loading = false;
                if (PLAYER.queue.isEmpty()) PLAYER.queue.addAll(found);
                if (!now) build();
                if (queryFailed) Toast.makeText(this, "No se pudo leer la biblioteca. Comprueba el permiso de almacenamiento.", Toast.LENGTH_LONG).show();
            });
        });
    }
    private void openIntent(Intent intent) {
        if (!Intent.ACTION_VIEW.equals(intent.getAction()) || intent.getData() == null) return;
        Uri uri = intent.getData();
        String scheme = uri.getScheme();
        if (!"content".equals(scheme) && !"file".equals(scheme)) { Toast.makeText(this, "Este enlace de audio no es compatible.", Toast.LENGTH_LONG).show(); return; }
        Song external = new Song(uri, uri.getLastPathSegment(), "Audio abierto", "", 0, -1);
        PLAYER.queue.clear(); PLAYER.queue.add(external); PLAYER.play(this, external); now = true; build();
    }
    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent); setIntent(intent); openIntent(intent); }
    @Override public void onRequestPermissionsResult(int request, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(request, permissions, results);
        if (request == 4) { if (permitted()) loadLibrary(); else Toast.makeText(this, "Permite el acceso al almacenamiento para ver tus canciones.", Toast.LENGTH_LONG).show(); }
    }
    @Override protected void onSaveInstanceState(Bundle out) { super.onSaveInstanceState(out); out.putBoolean("now", now); out.putInt("tab", tab); out.putString("group", group); }
    @Override protected void onStart() { super.onStart(); PLAYER.owner = new WeakReference<>(this); handler.removeCallbacks(ticker); handler.post(ticker); }
    @Override protected void onStop() {
        super.onStop(); handler.removeCallbacks(ticker);
        // Playback may continue while this Activity lives; pending/paused playback stays paused.
        if (PLAYER.owner.get() == this && !isChangingConfigurations() && !PLAYER.playing()) { PLAYER.resumeOnFocus = false; PLAYER.abandon(); }
    }
    @Override protected void onDestroy() {
        destroyed = true; artRequest++; handler.removeCallbacksAndMessages(null); worker.shutdownNow();
        if (PLAYER.owner.get() == this) { PLAYER.owner.clear(); if (!isChangingConfigurations()) { PLAYER.releasePlayer(); PLAYER.abandon(); } }
        super.onDestroy();
    }
    @Override public void onConfigurationChanged(Configuration c) {
        super.onConfigurationChanged(c);
        boolean dark = (c.uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        if (dark != night) recreate(); else build();
    }
    @Override public void onBackPressed() { if (now) { now = false; build(); } else if (group != null) { group = null; build(); } else super.onBackPressed(); }
    /** Aurora exit transition, copied from CalcActivity. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
