package com.scratch.ios7launcher;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.net.Uri;
import android.provider.AlarmClock;
import android.provider.MediaStore;

import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * What the search knows about an app, taken from Android itself instead of a hand-written list:
 * its label in several languages, the words of its package name, and what it is for, deduced from the standard
 * launcher categories and the intents it handles. Works for apps installed tomorrow.
 */
final class AppIndex {
    private AppIndex() { }

    /** One vocabulary entry per capability (not per app, and not misspellings): the words people use for that job. */
    private static final String PHONE = "telefono llamar llamada llamadas marcar marcador phone call dial dialer";
    private static final String SMS = "mensajes mensaje sms texto chat messages message text messaging";
    private static final String MAIL = "correo email mail mensajes electronico";
    private static final String CAMERA = "camara foto fotos fotografia video grabar selfie camera photo picture";
    private static final String GALLERY = "galeria fotos imagenes videos album gallery photos pictures images";
    private static final String CONTACTS = "contactos agenda personas gente contacts people address book";
    private static final String CLOCK = "reloj alarma despertador temporizador cronometro hora clock alarm timer stopwatch";
    private static final String CALENDAR = "calendario agenda eventos citas fechas calendar events schedule";
    private static final String MUSIC = "musica canciones reproductor audio music songs player";
    private static final String BROWSER = "navegador internet web explorar paginas browser internet web";
    private static final String MAPS = "mapas navegar gps direcciones rutas maps navigation directions";
    private static final String CALC = "calculadora calcular matematicas calculator math";
    private static final String MARKET = "tienda aplicaciones apps descargar store market download";
    private static final String SETTINGS = "ajustes configuracion opciones preferencias wifi bluetooth bateria pantalla sonido red settings preferences";
    private static final String FILES = "archivos documentos ficheros descargas carpetas files documents downloads folders";
    private static final String RECORDER = "grabadora voz audio notas de voz recorder voice";

    /** package -> concept words, computed once per reload. */
    static Map<String, String> capabilities(PackageManager pm) {
        Map<String, String> out = new HashMap<>();
        for (String cat : new String[]{Intent.CATEGORY_APP_BROWSER, Intent.CATEGORY_APP_CALCULATOR, Intent.CATEGORY_APP_CALENDAR,
                Intent.CATEGORY_APP_CONTACTS, Intent.CATEGORY_APP_EMAIL, Intent.CATEGORY_APP_GALLERY, Intent.CATEGORY_APP_MAPS,
                Intent.CATEGORY_APP_MARKET, Intent.CATEGORY_APP_MESSAGING, Intent.CATEGORY_APP_MUSIC}) {
            put(out, pm, new Intent(Intent.ACTION_MAIN).addCategory(cat), cat.equals(Intent.CATEGORY_APP_BROWSER) ? BROWSER
                    : cat.equals(Intent.CATEGORY_APP_CALCULATOR) ? CALC : cat.equals(Intent.CATEGORY_APP_CALENDAR) ? CALENDAR
                    : cat.equals(Intent.CATEGORY_APP_CONTACTS) ? CONTACTS : cat.equals(Intent.CATEGORY_APP_EMAIL) ? MAIL
                    : cat.equals(Intent.CATEGORY_APP_GALLERY) ? GALLERY : cat.equals(Intent.CATEGORY_APP_MAPS) ? MAPS
                    : cat.equals(Intent.CATEGORY_APP_MARKET) ? MARKET : cat.equals(Intent.CATEGORY_APP_MESSAGING) ? SMS : MUSIC);
        }
        put(out, pm, new Intent(Intent.ACTION_DIAL, Uri.parse("tel:123")), PHONE);
        put(out, pm, new Intent(MediaStore.ACTION_IMAGE_CAPTURE), CAMERA);
        put(out, pm, new Intent(MediaStore.ACTION_VIDEO_CAPTURE), CAMERA);
        put(out, pm, new Intent(AlarmClock.ACTION_SHOW_ALARMS), CLOCK);
        put(out, pm, new Intent(AlarmClock.ACTION_SET_ALARM), CLOCK);
        put(out, pm, new Intent(android.provider.Settings.ACTION_SETTINGS), SETTINGS);
        put(out, pm, new Intent(MediaStore.Audio.Media.RECORD_SOUND_ACTION), RECORDER);
        put(out, pm, new Intent(Intent.ACTION_GET_CONTENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE), FILES);
        put(out, pm, new Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:a@b.c")), MAIL);
        return out;
    }

    private static void put(Map<String, String> out, PackageManager pm, Intent i, String words) {
        try {
            List<ResolveInfo> l = pm.queryIntentActivities(i, 0);
            for (ResolveInfo ri : l) {
                String p = ri.activityInfo.packageName;
                String cur = out.get(p);
                if (cur == null) out.put(p, words); else if (!cur.contains(words)) out.put(p, cur + " " + words);
            }
        } catch (Exception ignored) { }
    }

    /** Normalised searchable text of an app: every label it has in es / en / system language, package words, capabilities. */
    static String doc(Context ctx, PackageManager pm, ResolveInfo ri, Map<String, String> caps) {
        StringBuilder sb = new StringBuilder();
        String pkg = ri.activityInfo.packageName;
        sb.append(ri.loadLabel(pm)).append(' ');
        int res = ri.activityInfo.labelRes != 0 ? ri.activityInfo.labelRes : ri.activityInfo.applicationInfo.labelRes;
        if (res != 0) {
            try {
                Resources base = pm.getResourcesForApplication(pkg);
                for (String lang : new String[]{"en", "es"}) {
                    Configuration cfg = new Configuration(base.getConfiguration());
                    cfg.setLocale(new Locale(lang));
                    Resources r = new Resources(base.getAssets(), base.getDisplayMetrics(), cfg);
                    sb.append(r.getString(res)).append(' ');
                }
            } catch (Exception ignored) { }
        }
        for (String part : pkg.split("\\.")) if (part.length() > 3 && !part.equals("android") && !part.equals("google") && !part.equals("scratch")) sb.append(part).append(' ');
        String c = caps.get(pkg);
        return c == null ? Fuzzy.norm(sb.toString()) : Fuzzy.norm(sb.toString()) + " | " + c;
    }

    /** Score of an app for a query: the label counts fully, the deduced description a bit less. */
    static int score(String nq, String label, String doc) {
        int s = Fuzzy.score(nq, label);
        int bar = doc.indexOf(" | ");
        String names = bar < 0 ? doc : doc.substring(0, bar);
        s = Math.max(s, Fuzzy.score(nq, names));
        if (bar >= 0) s = Math.max(s, Fuzzy.score(nq, doc.substring(bar + 3)) * 7 / 10);
        return s;
    }

    /** Remembers what you pick, so frequent apps rank first and "ca" learns that you mean the camera. */
    static final class Usage {
        private final SharedPreferences sp;
        Usage(Context c) { sp = c.getSharedPreferences("usage", Context.MODE_PRIVATE); }

        void record(String pkg, String normQuery) {
            SharedPreferences.Editor e = sp.edit();
            e.putInt("n:" + pkg, sp.getInt("n:" + pkg, 0) + 1);
            String hk = "h:" + bucket() + "|" + pkg;
            e.putInt(hk, sp.getInt(hk, 0) + 1);
            for (int len = 2; len <= Math.min(normQuery.length(), 12); len++) {
                String k = "q:" + normQuery.substring(0, len) + "|" + pkg;
                e.putInt(k, sp.getInt(k, 0) + 1);
            }
            e.apply();
        }

        int count(String pkg) { return sp.getInt("n:" + pkg, 0); }

        /** Six 4-hour slots of the day. */
        static int bucket() { return java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY) / 4; }

        /** How likely you are to want this app now: overall use plus a strong weight for use in this part of the day. */
        float suggest(String pkg) { return count(pkg) + 4f * sp.getInt("h:" + bucket() + "|" + pkg, 0); }

        /** Bonus for an app that matched: how often you use it, and how often you chose it for this very query. */
        int bonus(String pkg, String normQuery) {
            int n = count(pkg), q = sp.getInt("q:" + normQuery + "|" + pkg, 0);
            return Math.min(24, (int) (Math.log(1 + n) / Math.log(2) * 6)) + Math.min(40, q * 12);
        }
    }
}
