package com.scratch.ios7launcher;

import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Typeface;
import android.provider.Settings;
import android.view.HapticFeedbackConstants;
import android.view.View;

import java.util.Calendar;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Cross-cutting options and small helpers inspired by the Apple Design Awards 2026 review
 * (docs/roadmap-adas.md): accessibility switches, one haptic vocabulary, offline sky maths,
 * phrase of the day, phone health. Everything is local; nothing needs the network.
 */
final class Aura {
    private Aura() { }

    // ---- options (cached; loaded once per launcher start and after every change) ------------------------------
    static boolean hc, legible, motionOff, mono, season = true, focus, simple;
    static int haptic = 2;                 // 0 off, 1 soft (ticks only), 2 normal
    static int motion = 100;               // aurora speed, 0..100 %
    static String dtap = "lock";           // double tap on an empty spot: lock | search | none
    static String hideCards = "";          // today cards hidden: tiempo,estado,agenda,notas

    static SharedPreferences p(Context c) { return c.getSharedPreferences("home", Context.MODE_PRIVATE); }

    static void load(Context c) {
        SharedPreferences s = p(c);
        hc = s.getBoolean("opt_hc", false);
        legible = s.getBoolean("opt_legible", false);
        motionOff = s.getBoolean("opt_motion_off", false);
        mono = s.getBoolean("opt_mono", false);
        season = s.getBoolean("opt_season", true);
        focus = s.getBoolean("opt_focus", false);
        simple = s.getBoolean("opt_simple", false);
        haptic = s.getInt("opt_haptic", 2);
        motion = s.getInt("opt_motion", 100);
        dtap = s.getString("opt_dtap", "lock");
        hideCards = s.getString("opt_cards", "");
        AuroraField.mono = mono;
        AuroraField.motionK = motion / 100f;
        AuroraField.seasonOn = season;
        AuroraField.seasonTarget = seasonTarget();
    }

    static void set(Context c, String key, boolean v) { p(c).edit().putBoolean(key, v).apply(); load(c); }
    static void set(Context c, String key, int v) { p(c).edit().putInt(key, v).apply(); load(c); }
    static void set(Context c, String key, String v) { p(c).edit().putString(key, v).apply(); load(c); }

    /** Reduced motion: the launcher's own switch OR the system's "animator duration scale" set to off. */
    static boolean calm(Context c) {
        if (motionOff) return true;
        try { return Settings.Global.getFloat(c.getContentResolver(), Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f; }
        catch (Exception e) { return false; }
    }

    static boolean cardHidden(String id) { return ("," + hideCards + ",").contains("," + id + ","); }

    static String toggleCard(Context c, String id) {
        StringBuilder sb = new StringBuilder();
        boolean was = cardHidden(id);
        for (String t : hideCards.split(",")) if (!t.isEmpty() && !t.equals(id)) sb.append(sb.length() > 0 ? "," : "").append(t);
        if (!was) sb.append(sb.length() > 0 ? "," : "").append(id);
        set(c, "opt_cards", sb.toString());
        return sb.toString();
    }

    // ---- type and haptics ----------------------------------------------------------------------------------
    static Typeface thin() { return Typeface.create(hc || legible ? "sans-serif-light" : "sans-serif-thin", Typeface.NORMAL); }
    static Typeface light() { return Typeface.create(hc || legible ? "sans-serif" : "sans-serif-light", Typeface.NORMAL); }
    static Typeface hand() { return Typeface.create("cursive", Typeface.NORMAL); }

    static final int TICK = 0, CONFIRM = 1, WARN = 2;
    /** One vocabulary: tick (selection), confirm (done), warn (long press / destructive). Respects the strength option. */
    static void hap(View v, int kind) {
        if (v == null || haptic == 0 || (haptic == 1 && kind != TICK)) return;
        v.performHapticFeedback(kind == TICK ? HapticFeedbackConstants.CLOCK_TICK : kind == CONFIRM ? HapticFeedbackConstants.VIRTUAL_KEY : HapticFeedbackConstants.LONG_PRESS);
    }

    /** Duration helper: zero when motion is reduced. */
    static long dur(Context c, long ms) { return calm(c) ? 0 : ms; }

    // ---- sky: moon phase and sun times, offline -----------------------------------------------------------------
    static double moonPhase(long when) {
        double days = (when - 947182440000L) / 86400000.0;           // since the new moon of 2000-01-06 18:14 UTC
        double ph = (days / 29.530588853) % 1.0;
        return ph < 0 ? ph + 1 : ph;
    }

    static String moonName(double ph) {
        if (ph < 0.03 || ph >= 0.97) return "Luna nueva";
        if (ph < 0.22) return "Luna creciente";
        if (ph < 0.28) return "Cuarto creciente";
        if (ph < 0.47) return "Gibosa creciente";
        if (ph < 0.53) return "Luna llena";
        if (ph < 0.72) return "Gibosa menguante";
        if (ph < 0.78) return "Cuarto menguante";
        return "Luna menguante";
    }

    static int moonPercent(double ph) { return (int) Math.round((1 - Math.cos(2 * Math.PI * ph)) / 2 * 100); }

    /** Local sunrise and sunset in fractional hours for a latitude/longitude (NOAA almanac method), or null in polar day/night. */
    static double[] sun(double lat, double lon, Calendar day) {
        double[] out = new double[2];
        int n = day.get(Calendar.DAY_OF_YEAR);
        double tz = day.getTimeZone().getOffset(day.getTimeInMillis()) / 3600000.0, lngHour = lon / 15.0;
        for (int k = 0; k < 2; k++) {
            boolean rise = k == 0;
            double t = n + ((rise ? 6 : 18) - lngHour) / 24.0;
            double m = 0.9856 * t - 3.289;
            double l = m + 1.916 * Math.sin(Math.toRadians(m)) + 0.020 * Math.sin(Math.toRadians(2 * m)) + 282.634;
            l = ((l % 360) + 360) % 360;
            double ra = Math.toDegrees(Math.atan(0.91764 * Math.tan(Math.toRadians(l))));
            ra = ((ra % 360) + 360) % 360;
            ra += Math.floor(l / 90) * 90 - Math.floor(ra / 90) * 90;
            ra /= 15.0;
            double sinDec = 0.39782 * Math.sin(Math.toRadians(l)), cosDec = Math.cos(Math.asin(sinDec));
            double cosH = (Math.cos(Math.toRadians(90.833)) - sinDec * Math.sin(Math.toRadians(lat))) / (cosDec * Math.cos(Math.toRadians(lat)));
            if (cosH > 1 || cosH < -1) return null;
            double hh = (rise ? 360 - Math.toDegrees(Math.acos(cosH)) : Math.toDegrees(Math.acos(cosH))) / 15.0;
            double tt = hh + ra - 0.06571 * t - 6.622;
            double ut = (((tt - lngHour) % 24) + 24) % 24;
            out[k] = (ut + tz + 24) % 24;
        }
        return out;
    }

    static String hm(double h) { int m = (int) Math.round(h * 60); return String.format("%02d:%02d", (m / 60) % 24, m % 60); }

    /** Aligns the aurora's dawn and dusk keyframes with the real sunrise and sunset of the saved city. */
    static void syncSky(Context c) {
        Weather w = Weather.cached(p(c));
        double[] s = sun(w.lat, w.lon, Calendar.getInstance());
        if (s == null) { AuroraField.dawnShift = 0; AuroraField.duskShift = 0; return; }
        AuroraField.dawnShift = (float) Math.max(-1.5, Math.min(1.5, s[0] - 7.0));
        AuroraField.duskShift = (float) Math.max(-1.5, Math.min(1.5, s[1] - 18.5));
    }

    // ---- seasons ------------------------------------------------------------------------------------------------
    static String seasonName() {
        int m = Calendar.getInstance().get(Calendar.MONTH);
        return m <= 1 || m == 11 ? "invierno" : m <= 4 ? "primavera" : m <= 7 ? "verano" : "otoño";
    }

    static int seasonTarget() {
        switch (seasonName()) {
            case "invierno": return 0x7DB3FF;
            case "primavera": return 0x86EFAC;
            case "verano": return 0xFFC857;
            default: return 0xFB923C;
        }
    }

    // ---- subtle stereo sounds (opt-in) ------------------------------------------------------------------------
    /** 70 ms sine blip panned left/right (-1..1). Off by default; silent unless the ringer is in normal mode. */
    static void blip(final Context c, final float pan, final int hz) {
        if (!p(c).getBoolean("opt_sounds", false) || calm(c)) return;
        try { if (((android.media.AudioManager) c.getSystemService(Context.AUDIO_SERVICE)).getRingerMode() != android.media.AudioManager.RINGER_MODE_NORMAL) return; } catch (Exception e) { return; }
        new Thread(new Runnable() { public void run() {
            try {
                int sr = 22050, n = sr * 70 / 1000;
                short[] buf = new short[n * 2];
                for (int i = 0; i < n; i++) {
                    double env = Math.sin(Math.PI * i / n); env *= env;
                    double v = Math.sin(2 * Math.PI * hz * i / sr) * env * 0.16 * 32767;
                    buf[2 * i] = (short) (v * (pan > 0 ? 1 - pan : 1));
                    buf[2 * i + 1] = (short) (v * (pan < 0 ? 1 + pan : 1));
                }
                android.media.AudioTrack t = new android.media.AudioTrack(android.media.AudioManager.STREAM_MUSIC, sr, android.media.AudioFormat.CHANNEL_OUT_STEREO,
                        android.media.AudioFormat.ENCODING_PCM_16BIT, buf.length * 2, android.media.AudioTrack.MODE_STATIC);
                t.write(buf, 0, buf.length);
                t.play();
                Thread.sleep(160);
                t.release();
            } catch (Throwable ignored) { }
        } }).start();
    }

    // ---- lock-screen privacy -------------------------------------------------------------------------------------------
    static final String PRIVATE_KEY = "lock_screen_allow_private_notifications";
    static boolean lockPrivate(Context c) {
        try { return Settings.Secure.getInt(c.getContentResolver(), PRIVATE_KEY, 1) == 1; } catch (Exception e) { return true; }
    }
    /** Returns false when the permission is missing (grant it once over adb: pm grant <pkg> android.permission.WRITE_SECURE_SETTINGS). */
    static boolean setLockPrivate(Context c, boolean allow) {
        try { return Settings.Secure.putInt(c.getContentResolver(), PRIVATE_KEY, allow ? 1 : 0); } catch (Exception e) { return false; }
    }

    // ---- words ----------------------------------------------------------------------------------------------------
    private static final String[] PHRASES = {
        "Hoy: poco, pero bien hecho.", "Respira. El resto puede esperar.", "Lo pequeño también cuenta.",
        "Un paso corto sigue siendo un paso.", "Descansar también es avanzar.", "Hoy basta con empezar.",
        "No hace falta tenerlo todo claro.", "Escucha más de lo que miras la pantalla.", "Hoy toca ser amable contigo.",
        "Lo importante no suena.", "Mejor despacio y entero.", "Una cosa a la vez.",
        "Mira por la ventana un momento.", "Termina una cosa, no diez.", "Beber agua también es un plan.",
        "El silencio es una función más.", "Hoy no hay prisa.", "Lo simple suele ser lo correcto.",
        "Hazlo ahora, hazlo pequeño.", "Hay luz aunque no la veas.", "Cuida lo que te cuida.",
        "Alguien se alegraría de oírte.", "Salir a andar cuenta como un plan.", "Menos pantallas, más cielo.",
        "Lo que hoy cuesta, mañana se nota.", "Está bien no estar al día.", "Hoy ya es suficiente.",
        "Ordena un cajón, ordena una idea.", "Sé paciente con el proceso.", "Pregunta sin miedo.", "Sonríe a la primera persona que veas."
    };

    static String phrase() {
        Calendar c = Calendar.getInstance();
        return PHRASES[(c.get(Calendar.YEAR) * 366 + c.get(Calendar.DAY_OF_YEAR)) % PHRASES.length];
    }

    static String greeting(int hr) {
        if (hr < 6) return "BUENAS NOCHES";
        if (hr < 13) return "BUENOS DÍAS";
        if (hr < 21) return "BUENAS TARDES";
        return "BUENAS NOCHES";
    }

    // ---- phone health and screen time ---------------------------------------------------------------------------------
    /** 0..100 from battery, free storage and free memory, plus a one-line explanation. */
    static Object[] health(Context c) {
        android.content.Intent b = c.registerReceiver(null, new android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED));
        int lvl = b == null ? 50 : b.getIntExtra("level", 50) * 100 / Math.max(1, b.getIntExtra("scale", 100));
        android.os.StatFs fs = new android.os.StatFs(android.os.Environment.getDataDirectory().getPath());
        int sto = (int) (fs.getAvailableBytes() * 100 / Math.max(1, fs.getTotalBytes()));
        android.app.ActivityManager.MemoryInfo mi = new android.app.ActivityManager.MemoryInfo();
        ((android.app.ActivityManager) c.getSystemService(Context.ACTIVITY_SERVICE)).getMemoryInfo(mi);
        int ram = (int) (mi.availMem * 100 / Math.max(1, mi.totalMem));
        int score = Math.round(lvl * 0.40f + Math.min(100, sto * 2) * 0.30f + Math.min(100, ram * 2.5f) * 0.30f);
        String why = "Batería " + lvl + " % · " + String.format("%.1f GB libres", fs.getAvailableBytes() / 1e9) + " · RAM " + (mi.availMem >> 20) + " MB libres";
        return new Object[]{score, why};
    }

    /** Today's foreground time per app (top 3) and the total, in minutes; needs the usage-stats permission. */
    static Object[] screenTime(Context c) {
        try {
            UsageStatsManager usm = (UsageStatsManager) c.getSystemService(Context.USAGE_STATS_SERVICE);
            Calendar start = Calendar.getInstance();
            start.set(Calendar.HOUR_OF_DAY, 0); start.set(Calendar.MINUTE, 0); start.set(Calendar.SECOND, 0); start.set(Calendar.MILLISECOND, 0);
            List<UsageStats> st = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start.getTimeInMillis(), System.currentTimeMillis());
            if (st == null) return null;
            Map<String, Long> by = new TreeMap<>();
            long total = 0;
            for (UsageStats u : st) {
                long t = u.getTotalTimeInForeground();
                if (t <= 0 || u.getPackageName().equals(c.getPackageName()) || u.getPackageName().equals("com.android.systemui")) continue;
                Long o = by.get(u.getPackageName());
                by.put(u.getPackageName(), (o == null ? 0 : o) + t);
                total += t;
            }
            return new Object[]{total / 60000, by};
        } catch (Exception e) { return null; }
    }
}
