package com.scratch.iosfiles;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.system.Os;
import android.system.OsConstants;
import android.system.ErrnoException;
import android.text.TextUtils;
import android.view.*;
import android.webkit.MimeTypeMap;
import android.widget.*;
import java.io.File;
import java.io.IOException;
import java.text.DateFormat;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Aurora: a small wallpaper-backed file browser, without generated resources. */
public class FilesActivity extends Activity {
    private float d;
    private boolean night;
    private int text, accent, glass, stroke;
    private File rootDir, current;
    private TextView path, status, back;
    private ListView list;
    private FileAdapter adapter;
    private final ArrayList<Entry> entries = new ArrayList<>();
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile int generation;
    private View pressedRow;
    private boolean destroyed;
    private static final Locale ES = new Locale("es", "ES");

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        text = night ? Color.WHITE : 0xFF14123A;
        accent = night ? 0xFF7BA7FF : 0xFF3B6BEA;
        glass = night ? 0x24FFFFFF : 0x99FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xE6FFFFFF;
        rootDir = Environment.getExternalStorageDirectory();
        current = rootDir;
        if (b != null) {
            File saved = new File(b.getString("path", rootDir.getAbsolutePath()));
            if (inside(saved)) current = saved;
        }
        Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this);
        scrim.setBackgroundColor(night ? 0x9914123A : 0x66F6F5FF);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding(dp(12), dp(24), dp(12), dp(12));
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout heading = new LinearLayout(this);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        back = button("‹", 34); back.setContentDescription("Subir de carpeta");
        heading.addView(back, new LinearLayout.LayoutParams(dp(40), dp(48)));
        back.setOnClickListener(v -> up());
        path = label("", 25, text, "sans-serif-thin");
        path.setMaxLines(2); path.setEllipsize(TextUtils.TruncateAt.START);
        path.setPadding(dp(10), dp(8), dp(6), dp(8));
        heading.addView(path, new LinearLayout.LayoutParams(0, -2, 1));
        TextView add = button("+", 30); add.setContentDescription("Crear carpeta");
        heading.addView(add, new LinearLayout.LayoutParams(dp(42), dp(48)));
        add.setOnClickListener(v -> nameDialog(null));
        col.addView(heading, new LinearLayout.LayoutParams(-1, -2));
        TextView subtitle = label("ARCHIVOS", 11, accent, "sans-serif-light");
        subtitle.setPadding(dp(4), dp(8), 0, dp(8)); col.addView(subtitle);
        HorizontalScrollView chips = new HorizontalScrollView(this);
        chips.setHorizontalScrollBarEnabled(false);
        LinearLayout quick = new LinearLayout(this);
        String[] names = {"Descargas", "DCIM", "Música", "Documentos"};
        String[] dirs = {Environment.DIRECTORY_DOWNLOADS, Environment.DIRECTORY_DCIM, Environment.DIRECTORY_MUSIC, Environment.DIRECTORY_DOCUMENTS};
        for (int i = 0; i < names.length; i++) {
            final File dir = new File(rootDir, dirs[i]);
            TextView chip = button(names[i], 13);
            chip.setPadding(dp(12), 0, dp(12), 0);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, dp(36)); lp.setMargins(0, 0, dp(6), 0);
            quick.addView(chip, lp); chip.setOnClickListener(v -> navigate(dir));
        }
        chips.addView(quick); col.addView(chips, new LinearLayout.LayoutParams(-1, dp(44)));
        status = label("", 12, text, "sans-serif-light");
        status.setPadding(dp(4), dp(5), 0, dp(9)); col.addView(status);
        FrameLayout panel = new FrameLayout(this); panel.setBackground(shape(18));
        list = new ListView(this); list.setDivider(null); list.setCacheColorHint(Color.TRANSPARENT);
        adapter = new FileAdapter(); list.setAdapter(adapter);
        panel.addView(list, new FrameLayout.LayoutParams(-1, -1));
        col.addView(panel, new LinearLayout.LayoutParams(-1, 0, 1));
        list.setOnTouchListener((v, event) -> {
            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                int pos = list.pointToPosition((int) event.getX(), (int) event.getY());
                if (pos != ListView.INVALID_POSITION) {
                    pressedRow = list.getChildAt(pos - list.getFirstVisiblePosition());
                    if (pressedRow != null) animatePress(pressedRow, true);
                }
            } else if (event.getActionMasked() == MotionEvent.ACTION_UP || event.getActionMasked() == MotionEvent.ACTION_CANCEL || event.getActionMasked() == MotionEvent.ACTION_MOVE) {
                if (pressedRow != null) { animatePress(pressedRow, false); pressedRow = null; }
            }
            return false;
        });
        list.setOnItemClickListener((p, v, pos, id) -> {
            Entry e = entries.get(pos); if (e.directory) navigate(e.file); else open(e.file, false);
        });
        list.setOnItemLongClickListener((p, v, pos, id) -> { menu(entries.get(pos)); return true; });
        setContentView(root); load();
    }

    private int dp(float n) { return Math.round(n * d); }
    private TextView label(String s, int sp, int color, String face) {
        TextView v = new TextView(this); v.setText(s); v.setTextSize(sp); v.setTextColor(color);
        v.setTypeface(Typeface.create(face, Typeface.NORMAL)); return v;
    }
    private GradientDrawable shape(int radius) {
        GradientDrawable g = new GradientDrawable(); g.setColor(glass); g.setCornerRadius(dp(radius));
        g.setStroke(Math.max(1, dp(1)), stroke); return g;
    }
    private TextView button(String s, int sp) {
        TextView v = label(s, sp, accent, "sans-serif-light"); v.setGravity(Gravity.CENTER);
        v.setBackground(shape(16)); spring(v); return v;
    }
    private void animatePress(View v, boolean down) {
        v.animate().cancel();
        if (down) v.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
        else v.animate().scaleX(1f).scaleY(1f).setDuration(320).setInterpolator(new android.view.animation.OvershootInterpolator(3.2f)).start();
    }
    private void spring(View view) {
        view.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) animatePress(v, true);
            else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) animatePress(v, false);
            return false;
        });
    }
    private boolean inside(File f) {
        try { String base = rootDir.getCanonicalPath(), p = f.getCanonicalPath(); return p.equals(base) || p.startsWith(base + File.separator); }
        catch (IOException | SecurityException e) { return false; }
    }
    private void navigate(File f) { if (!inside(f)) { toast("Acceso fuera del almacenamiento no permitido"); return; } current = f; load(); }
    private void up() {
        if (current.equals(rootDir)) { finish(); return; }
        File parent = current.getParentFile(); navigate(parent != null && inside(parent) ? parent : rootDir);
    }
    @Override public void onBackPressed() { up(); }
    private void load() {
        final File dir = current; final int request = ++generation;
        path.setText(dir.equals(rootDir) ? "/sdcard" : dir.getAbsolutePath());
        back.setAlpha(dir.equals(rootDir) ? 0.45f : 1f);
        entries.clear(); adapter.notifyDataSetChanged(); status.setText("Cargando…");
        worker.execute(() -> {
            ArrayList<Entry> result = new ArrayList<>(); String error = null;
            try {
                File[] children = dir.listFiles();
                if (children == null) error = "No se puede leer esta carpeta";
                else {
                    for (File f : children) { if (Thread.currentThread().isInterrupted() || request != generation) return; result.add(new Entry(f)); }
                    Collections.sort(result, (a, b) -> {
                        if (a.directory != b.directory) return a.directory ? -1 : 1;
                        int c = a.file.getName().compareToIgnoreCase(b.file.getName());
                        return c != 0 ? c : a.file.getName().compareTo(b.file.getName());
                    });
                }
            } catch (SecurityException e) { error = "No tienes permiso para leer esta carpeta"; }
            final String problem = error;
            runOnUiThread(() -> {
                if (destroyed || request != generation) return;
                entries.addAll(result); adapter.notifyDataSetChanged();
                status.setText(problem != null ? problem : result.isEmpty() ? "Carpeta vacía" : result.size() + (result.size() == 1 ? " elemento" : " elementos"));
            });
        });
    }
    private static String size(long bytes) {
        if (bytes < 1024) return bytes + " B";
        double n = bytes; String[] units = {"B", "KB", "MB", "GB", "TB"}; int i = 0;
        while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
        return String.format(ES, "%.1f %s", n, units[i]);
    }
    private static String date(long value) { return DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT, ES).format(new Date(value)); }
    private static String mime(File f) {
        String name = f.getName(); int dot = name.lastIndexOf('.');
        String ext = dot >= 0 ? name.substring(dot + 1).toLowerCase(Locale.ROOT) : "";
        String type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
        return type == null ? "application/octet-stream" : type;
    }
    private void open(File f, boolean share) {
        if (!inside(f)) { toast("No se puede acceder a este archivo"); return; }
        Intent intent = new Intent(share ? Intent.ACTION_SEND : Intent.ACTION_VIEW);
        if (share) { intent.setType(mime(f)); intent.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(f)); }
        else intent.setDataAndType(Uri.fromFile(f), mime(f));
        try { startActivity(share ? Intent.createChooser(intent, "Compartir archivo") : intent); }
        catch (ActivityNotFoundException e) { toast("No hay una aplicación para " + (share ? "compartir" : "abrir") + " este archivo"); }
        catch (SecurityException e) { toast("No se ha podido acceder al archivo"); }
    }
    private AlertDialog.Builder dialog(String title) { return new AlertDialog.Builder(this, AlertDialog.THEME_HOLO_LIGHT).setTitle(title); }
    private void menu(Entry entry) {
        File f = entry.file;
        dialog(f.getName()).setItems(new String[]{"Compartir", "Renombrar", "Borrar", "Detalles"}, (a, which) -> {
            if (which == 0) { if (entry.directory) toast("Selecciona un fichero para compartir"); else open(f, true); }
            else if (which == 1) nameDialog(f);
            else if (which == 2) dialog("Borrar «" + f.getName() + "»").setMessage(entry.directory ? "Se borrarán la carpeta y todo su contenido. Esta acción no se puede deshacer." : "Esta acción no se puede deshacer.")
                .setNegativeButton("Cancelar", null).setPositiveButton("Borrar", (x, y) -> mutate("Archivo borrado", () -> { deleteTree(f, new HashSet<String>()); })).show();
            else details(entry);
        }).show();
    }
    private void nameDialog(File source) {
        final File parent = source == null ? current : source.getParentFile();
        EditText input = new EditText(this); input.setSingleLine(true); input.setTextColor(0xFF14123A);
        input.setHintTextColor(0xFF666666); input.setBackgroundColor(0xFFF4F3FA); input.setPadding(dp(12), dp(12), dp(12), dp(12));
        input.setHint("Nombre de carpeta"); if (source != null) { input.setText(source.getName()); input.selectAll(); }
        AlertDialog a = dialog(source == null ? "Nueva carpeta" : "Renombrar").setView(input)
            .setNegativeButton("Cancelar", null).setPositiveButton("Guardar", null).create();
        a.setOnShowListener(ignored -> a.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
            String name = input.getText().toString().trim();
            if (name.isEmpty() || name.equals(".") || name.equals("..") || name.contains("/") || name.indexOf('\0') >= 0) { input.setError("Introduce un nombre válido, sin /"); return; }
            File target = new File(parent, name);
            a.dismiss();
            mutate(source == null ? "Carpeta creada" : "Nombre cambiado", () -> {
                if (!inside(target) || !inside(parent) || (source != null && !inside(source))) throw new IOException("Ruta no permitida");
                if (source != null && target.equals(source)) return;
                if (target.exists()) throw new IOException("Ya existe un elemento con ese nombre");
                boolean ok = source == null ? target.mkdir() : source.renameTo(target);
                if (!ok) throw new IOException("No se pudo guardar. Comprueba los permisos y el nombre");
            });
        })); a.show();
    }
    private interface Operation { void run() throws IOException; }
    private void mutate(String success, Operation op) {
        final File displayed = current;
        worker.execute(() -> {
            String result = success;
            try { op.run(); } catch (IOException | SecurityException e) { result = e.getMessage() == null ? "No se pudo completar la operación" : e.getMessage(); }
            final String message = result;
            runOnUiThread(() -> { if (!destroyed) { toast(message); if (current.equals(displayed)) load(); } });
        });
    }
    private void deleteTree(File f, Set<String> visited) throws IOException {
        if (Thread.currentThread().isInterrupted()) throw new IOException("Operación interrumpida");
        if (f.equals(rootDir) || f.getParentFile() == null || !inside(f.getParentFile())) throw new IOException("No se puede borrar esta ruta");
        if (isLink(f)) {
            if (!f.delete()) throw new IOException("No se pudo borrar el enlace «" + f.getName() + "»");
            return;
        }
        if (!inside(f) || f.getCanonicalFile().equals(rootDir.getCanonicalFile())) throw new IOException("No se puede borrar esta ruta");
        if (!visited.add(f.getCanonicalPath())) throw new IOException("Enlace circular: no se ha borrado todo el contenido");
        if (f.isDirectory()) {
            File[] children = f.listFiles(); if (children == null) throw new IOException("No se puede leer la carpeta; puede haberse borrado parte del contenido");
            for (File child : children) deleteTree(child, visited);
        }
        if (!f.delete()) throw new IOException("No se pudo borrar «" + f.getName() + "»; puede haberse borrado parte del contenido");
    }
    private boolean isLink(File f) throws IOException {
        try { return OsConstants.S_ISLNK(Os.lstat(f.getAbsolutePath()).st_mode); }
        catch (ErrnoException e) { throw new IOException("No se pudo consultar «" + f.getName() + "»"); }
    }
    private long totalSize(File f, Set<String> visited) throws IOException {
        if (Thread.currentThread().isInterrupted()) throw new IOException("Cálculo interrumpido");
        if (isLink(f)) return 0; // Do not count a link's target twice or follow it outside storage.
        if (!inside(f)) throw new IOException("No se puede leer esta ruta");
        if (!f.isDirectory()) return f.length();
        if (!visited.add(f.getCanonicalPath())) return 0;
        File[] children = f.listFiles();
        if (children == null) throw new IOException("Tamaño no disponible: hay carpetas sin permiso de lectura");
        long total = 0;
        for (File child : children) total += totalSize(child, visited);
        return total;
    }
    private void details(Entry e) {
        final String prefix = "Nombre: " + e.file.getName() + "\n\nRuta: " + e.file.getAbsolutePath() + "\n\nTipo: " + (e.directory ? "Carpeta" : mime(e.file));
        final String suffix = "\n\nFecha: " + date(e.modified);
        AlertDialog a = dialog("Detalles").setMessage(prefix + "\n\nTamaño: " + (e.directory ? "Calculando…" : size(e.bytes) + " (" + e.bytes + " bytes)") + suffix).setPositiveButton("Cerrar", null).show();
        if (e.directory) worker.execute(() -> {
            String result;
            try { long bytes = totalSize(e.file, new HashSet<String>()); result = size(bytes) + " (" + bytes + " bytes, sin seguir enlaces)"; }
            catch (IOException | SecurityException error) { result = "No disponible: no se pudo leer todo el contenido"; }
            final String value = result;
            runOnUiThread(() -> { if (!destroyed && a.isShowing()) a.setMessage(prefix + "\n\nTamaño: " + value + suffix); });
        });
    }
    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_LONG).show(); }
    @Override protected void onSaveInstanceState(Bundle b) { b.putString("path", current.getAbsolutePath()); super.onSaveInstanceState(b); }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); recreate(); }
    @Override protected void onDestroy() { destroyed = true; generation++; worker.shutdownNow(); super.onDestroy(); }
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
    private static class Entry {
        final File file; final boolean directory; final long bytes, modified;
        Entry(File f) { file = f; directory = f.isDirectory(); bytes = f.length(); modified = f.lastModified(); }
    }
    private class FileAdapter extends BaseAdapter {
        public int getCount() { return entries.size(); }
        public Object getItem(int p) { return entries.get(p); }
        public long getItemId(int p) { return p; }
        public View getView(int p, View old, android.view.ViewGroup parent) {
            LinearLayout row;
            if (old == null) {
                row = new LinearLayout(FilesActivity.this); row.setGravity(Gravity.CENTER_VERTICAL); row.setPadding(dp(10), dp(9), dp(10), dp(9));
                row.setMinimumHeight(dp(70)); row.addView(new FileIcon(), new LinearLayout.LayoutParams(dp(38), dp(40)));
                LinearLayout labels = new LinearLayout(FilesActivity.this); labels.setOrientation(LinearLayout.VERTICAL); labels.setPadding(dp(10), 0, 0, 0);
                TextView title = label("", 17, text, "sans-serif-light"); title.setSingleLine(true); title.setEllipsize(TextUtils.TruncateAt.MIDDLE); labels.addView(title);
                TextView sub = label("", 11, text, "sans-serif-light"); sub.setAlpha(0.72f); sub.setPadding(0, dp(4), 0, 0); sub.setMaxLines(2); labels.addView(sub);
                row.addView(labels, new LinearLayout.LayoutParams(0, -2, 1));
            } else row = (LinearLayout) old;
            Entry e = entries.get(p); ((FileIcon) row.getChildAt(0)).set(e);
            LinearLayout labels = (LinearLayout) row.getChildAt(1);
            ((TextView) labels.getChildAt(0)).setText(e.file.getName());
            ((TextView) labels.getChildAt(1)).setText((e.directory ? "Carpeta · " + size(e.bytes) + " de entrada" : size(e.bytes)) + " · " + date(e.modified));
            return row;
        }
    }
    private class FileIcon extends View {
        private Entry entry; private final Paint paint = new Paint(3);
        FileIcon() { super(FilesActivity.this); setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO); }
        void set(Entry e) { entry = e; invalidate(); }
        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas); if (entry == null) return;
            canvas.save(); canvas.scale(getWidth() / 38f, getHeight() / 40f);
            if (entry.directory) {
                paint.setColor(0xFFEFAF23); canvas.drawRoundRect(2, 7, 19, 19, 3, 3, paint);
                paint.setColor(0xFFFFCF50); canvas.drawRoundRect(2, 12, 36, 34, 4, 4, paint);
                paint.setColor(0xFFFFE79C); canvas.drawRoundRect(5, 14, 33, 16, 1, 1, paint);
            } else {
                String type = mime(entry.file); String badge; int color;
                if (type.startsWith("image/")) { color = 0xFF3BAA91; badge = "IMG"; }
                else if (type.startsWith("video/")) { color = 0xFF9873D5; badge = "VID"; }
                else if (type.startsWith("audio/")) { color = 0xFFE6738A; badge = "AUD"; }
                else if (type.startsWith("text/") || type.contains("pdf") || type.contains("document") || type.contains("sheet") || type.contains("presentation") || type.contains("msword") || type.contains("ms-excel") || type.contains("ms-powerpoint")) { color = 0xFF5184D8; badge = "DOC"; }
                else { color = 0xFF9097A9; badge = "FILE"; }
                paint.setColor(night ? 0xFFD7DDEF : 0xFFF6F7FF); canvas.drawRoundRect(7, 3, 31, 37, 3, 3, paint);
                paint.setColor(0xFFBFC9E0); canvas.drawRect(23, 3, 31, 11, paint);
                paint.setColor(color); canvas.drawRoundRect(2, 19, 36, 33, 3, 3, paint);
                paint.setColor(Color.WHITE); paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD)); paint.setTextSize(9); paint.setTextAlign(Paint.Align.CENTER); canvas.drawText(badge, 19, 29, paint);
            }
            canvas.restore();
        }
    }
}
