package com.scratch.ios7launcher;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ContentUris;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.media.AudioManager;
import android.net.Uri;
import android.provider.CalendarContract;
import android.provider.Settings;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

/**
 * Event-driven automation, no resident service: everything runs from alarms and system broadcasts.
 *  - Daily briefing: weather, next alarm and today's events as one notification at a chosen time.
 *  - Night quiet hours: the ringer goes to vibrate in the window and comes back after it.
 *  - Battery guardian: when the battery is low the screen dims and Bluetooth goes off; plugging in restores the brightness.
 */
public class Routines extends BroadcastReceiver {
    static final String A_BRIEF = "com.scratch.ios7launcher.ROUTINE_BRIEF", A_QUIET_ON = "com.scratch.ios7launcher.ROUTINE_QUIET_ON", A_QUIET_OFF = "com.scratch.ios7launcher.ROUTINE_QUIET_OFF", A_EVENING = "com.scratch.ios7launcher.ROUTINE_EVENING", A_MEET = "com.scratch.ios7launcher.ROUTINE_MEET";
    private static final Locale ES = new Locale("es", "ES");

    private static SharedPreferences p(Context c) { return c.getSharedPreferences("routines", Context.MODE_PRIVATE); }

    @Override public void onReceive(Context c, Intent i) {
        String a = i.getAction();
        if (a == null) return;
        switch (a) {
            case Intent.ACTION_BOOT_COMPLETED: case Intent.ACTION_MY_PACKAGE_REPLACED: rearm(c); break;
            case A_BRIEF: briefing(c); armBrief(c); break;
            case A_QUIET_ON: quiet(c, true); armQuiet(c); break;
            case A_QUIET_OFF: quiet(c, false); armQuiet(c); break;
            case A_EVENING: tomorrowCheck(c, false); armEvening(c); break;
            case A_MEET: case "android.intent.action.PROVIDER_CHANGED": meetings(c); break;
            case android.net.ConnectivityManager.CONNECTIVITY_ACTION: wifiChanged(c); break;
            case Intent.ACTION_BATTERY_LOW: batteryLow(c); break;
            case Intent.ACTION_POWER_CONNECTED: powerConnected(c); break;
            default: break;
        }
    }

    // ---- rules --------------------------------------------------------------------------------------

    static void setBrief(Context c, int h, int m) { p(c).edit().putInt("brief_h", h).putInt("brief_m", m).apply(); armBrief(c); }
    static void setQuiet(Context c, int from, int to) { p(c).edit().putInt("quiet_from", from).putInt("quiet_to", to).apply(); armQuiet(c); applyQuietNow(c); }

    static String describe(Context c) {
        SharedPreferences s = p(c);
        int bh = s.getInt("brief_h", -1), qf = s.getInt("quiet_from", -1);
        return "Resumen diario: " + (bh < 0 ? "desactivado" : String.format(Locale.US, "%02d:%02d", bh, s.getInt("brief_m", 0)))
                + "\nSilencio nocturno: " + (qf < 0 ? "desactivado" : String.format(Locale.US, "%02d:00 → %02d:00", qf, s.getInt("quiet_to", 7)));
    }

    static void rearm(Context c) {
        SharedPreferences s = p(c);
        if (!s.getBoolean("init", false)) s.edit().putBoolean("init", true).putInt("brief_h", 7).putInt("brief_m", 30).putInt("quiet_from", 23).putInt("quiet_to", 7).apply();   // sensible defaults on first run
        armBrief(c); armQuiet(c); armEvening(c); applyQuietNow(c); meetings(c);
    }

    private static PendingIntent pi(Context c, String action) {
        return PendingIntent.getBroadcast(c, action.hashCode(), new Intent(c, Routines.class).setAction(action), PendingIntent.FLAG_UPDATE_CURRENT);
    }

    private static void at(Context c, String action, int h, int m) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        Calendar t = Calendar.getInstance();
        t.set(Calendar.HOUR_OF_DAY, h); t.set(Calendar.MINUTE, m); t.set(Calendar.SECOND, 0); t.set(Calendar.MILLISECOND, 0);
        if (t.getTimeInMillis() <= System.currentTimeMillis() + 1000) t.add(Calendar.DAY_OF_YEAR, 1);
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t.getTimeInMillis(), pi(c, action));
    }

    private static void armBrief(Context c) {
        int h = p(c).getInt("brief_h", -1);
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (h < 0) am.cancel(pi(c, A_BRIEF)); else at(c, A_BRIEF, h, p(c).getInt("brief_m", 0));
    }

    private static void armEvening(Context c) { at(c, A_EVENING, 21, 30); }

    private static void armQuiet(Context c) {
        int f = p(c).getInt("quiet_from", -1);
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (f < 0) { am.cancel(pi(c, A_QUIET_ON)); am.cancel(pi(c, A_QUIET_OFF)); return; }
        at(c, A_QUIET_ON, f, 0);
        at(c, A_QUIET_OFF, p(c).getInt("quiet_to", 7), 0);
    }

    private static boolean inWindow(int h, int from, int to) { return from < to ? (h >= from && h < to) : (h >= from || h < to); }

    private static void applyQuietNow(Context c) {
        int f = p(c).getInt("quiet_from", -1);
        if (f < 0) { if (p(c).getBoolean("quiet_active", false)) quiet(c, false); return; }
        int h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY);
        quiet(c, inWindow(h, f, p(c).getInt("quiet_to", 7)));
    }

    private static void quiet(Context c, boolean on) {
        AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
        SharedPreferences s = p(c);
        try {
            if (on && !s.getBoolean("quiet_active", false)) {
                s.edit().putInt("quiet_prev", am.getRingerMode()).putBoolean("quiet_active", true).apply();
                if (am.getRingerMode() == AudioManager.RINGER_MODE_NORMAL) am.setRingerMode(AudioManager.RINGER_MODE_VIBRATE);
            } else if (!on && s.getBoolean("quiet_active", false)) {
                am.setRingerMode(s.getInt("quiet_prev", AudioManager.RINGER_MODE_NORMAL));
                s.edit().putBoolean("quiet_active", false).apply();
            }
        } catch (Exception ignored) { }
    }

    // ---- battery guardian ------------------------------------------------------------------------------

    private static void batteryLow(Context c) {
        SharedPreferences s = p(c);
        try {
            int cur = Settings.System.getInt(c.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, 128);
            if (cur > 80) {
                int mode = Settings.System.getInt(c.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                s.edit().putInt("bright_prev", cur).putInt("bright_mode_prev", mode).apply();
                Settings.System.putInt(c.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                Settings.System.putInt(c.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, 70);
            }
        } catch (Exception ignored) { }
        try { android.bluetooth.BluetoothAdapter b = android.bluetooth.BluetoothAdapter.getDefaultAdapter(); if (b != null && b.isEnabled()) { b.disable(); s.edit().putBoolean("bt_was_on", true).apply(); } } catch (Exception ignored) { }
        post(c, 7002, "Ahorro de batería", "Batería baja: he bajado el brillo y apagado Bluetooth. Se restaura al enchufar.");
    }

    private static void powerConnected(Context c) {
        SharedPreferences s = p(c);
        int prev = s.getInt("bright_prev", -1);
        if (prev > 0) {
            try {
                Settings.System.putInt(c.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, prev);
                Settings.System.putInt(c.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE, s.getInt("bright_mode_prev", Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL));
            } catch (Exception ignored) { }
            s.edit().remove("bright_prev").remove("bright_mode_prev").apply();
            ((NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE)).cancel(7002);
        }
        if (s.getBoolean("bt_was_on", false)) {
            try { android.bluetooth.BluetoothAdapter b = android.bluetooth.BluetoothAdapter.getDefaultAdapter(); if (b != null) b.enable(); } catch (Exception ignored) { }
            s.edit().remove("bt_was_on").apply();
        }
    }

    // ---- daily briefing ----------------------------------------------------------------------------------

    static void briefing(Context c) {
        StringBuilder sb = new StringBuilder();
        Weather w = Weather.cached(c.getSharedPreferences("home", Context.MODE_PRIVATE));
        if (w.ok) sb.append(w.temp).append("° ").append(w.desc).append(" en ").append(w.city).append(" (máx ").append(w.hi).append("°, mín ").append(w.lo).append("°)");
        String line = alarmLine(c);
        if (line != null) sb.append(sb.length() > 0 ? "\n" : "").append(line);
        String ev = todayEvents(c);
        sb.append(sb.length() > 0 ? "\n" : "").append(ev);
        String title = greeting() + " · " + new SimpleDateFormat("EEEE d 'de' MMMM", ES).format(new Date());
        post(c, 7001, title, sb.toString());
    }

    private static String greeting() { int h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY); return h < 13 ? "Buenos días" : h < 21 ? "Buenas tardes" : "Buenas noches"; }

    private static String alarmLine(Context c) {
        AlarmManager.AlarmClockInfo ci = ((AlarmManager) c.getSystemService(Context.ALARM_SERVICE)).getNextAlarmClock();
        if (ci == null) return null;
        return "Próxima alarma: " + new SimpleDateFormat("EEE HH:mm", ES).format(new Date(ci.getTriggerTime()));
    }

    private static String todayEvents(Context c) {
        StringBuilder sb = new StringBuilder();
        Cursor cur = null;
        try {
            Calendar from = Calendar.getInstance();
            Calendar to = Calendar.getInstance(); to.set(Calendar.HOUR_OF_DAY, 23); to.set(Calendar.MINUTE, 59);
            Uri.Builder b = CalendarContract.Instances.CONTENT_URI.buildUpon();
            ContentUris.appendId(b, from.getTimeInMillis()); ContentUris.appendId(b, to.getTimeInMillis());
            cur = c.getContentResolver().query(b.build(), new String[]{CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN, CalendarContract.Instances.ALL_DAY},
                    null, null, CalendarContract.Instances.BEGIN + " ASC");
            int n = 0;
            while (cur != null && cur.moveToNext() && n < 4) {
                String t = cur.getString(0);
                if (t == null) continue;
                sb.append(n++ > 0 ? " · " : "").append(cur.getInt(2) == 1 ? "" : new SimpleDateFormat("HH:mm ", ES).format(new Date(cur.getLong(1)))).append(t);
            }
            if (n == 0) return "Hoy: sin eventos";
        } catch (Exception e) { return "Hoy: sin acceso al calendario"; } finally { if (cur != null) cur.close(); }
        return "Hoy: " + sb;
    }

    private static void post(Context c, int id, String title, String text) {
        Notification n = new Notification.Builder(c)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(text.split("\n")[0])
                .setStyle(new Notification.BigTextStyle().bigText(text))
                .setDefaults(Notification.DEFAULT_LIGHTS)
                .setAutoCancel(true)
                .setContentIntent(PendingIntent.getActivity(c, 0, new Intent(c, HomeActivity.class), 0))
                .build();
        ((NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE)).notify(id, n);
    }

    // ---- leaving home: advice from the day's weather ---------------------------------------------------

    private static void wifiChanged(Context c) {
        android.net.ConnectivityManager cm = (android.net.ConnectivityManager) c.getSystemService(Context.CONNECTIVITY_SERVICE);
        android.net.NetworkInfo ni = cm.getNetworkInfo(android.net.ConnectivityManager.TYPE_WIFI);
        boolean up = ni != null && ni.isConnected();
        SharedPreferences s = p(c);
        long now = System.currentTimeMillis();
        if (up) { if (!s.getBoolean("wifi_up", false)) s.edit().putBoolean("wifi_up", true).putLong("wifi_since", now).apply(); return; }
        if (!s.getBoolean("wifi_up", false)) return;
        long since = s.getLong("wifi_since", now);
        s.edit().putBoolean("wifi_up", false).apply();
        int h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY);
        String today = new SimpleDateFormat("yyyyMMdd", Locale.US).format(new Date());
        if (h < 5 || h > 11 || now - since < 30 * 60 * 1000L || today.equals(s.getString("leave_day", ""))) return;
        if (leaveAdvice(c)) s.edit().putString("leave_day", today).apply();
    }

    /** Posts a short weather-based tip for going out. Returns false when there is nothing worth saying. */
    static boolean leaveAdvice(Context c) {
        Weather w = Weather.cached(c.getSharedPreferences("home", Context.MODE_PRIVATE));
        if (!w.ok) return false;
        StringBuilder sb = new StringBuilder();
        if (w.rain >= 50) sb.append("Hoy hay un ").append(w.rain).append(" % de probabilidad de lluvia: coge paraguas.");
        else if (w.rain >= 30) sb.append("Posible lluvia hoy (").append(w.rain).append(" %): un paraguas no sobra.");
        if (w.hi >= 30) sb.append(sb.length() > 0 ? " " : "").append("M\u00e1xima de ").append(w.hi).append("\u00b0: lleva agua y protecci\u00f3n.");
        if (w.lo <= 5) sb.append(sb.length() > 0 ? " " : "").append("M\u00ednima de ").append(w.lo).append("\u00b0: abr\u00edgate.");
        if (sb.length() == 0) return false;
        post(c, 7003, "Antes de salir \u00b7 " + w.city, sb.toString());
        return true;
    }

    // ---- tomorrow check: early event and no alarm --------------------------------------------------------

    /** Looks at tomorrow's first timed event before noon; if no alarm will wake you in time, suggests one with a one-tap button. */
    static void tomorrowCheck(Context c, boolean force) {
        Calendar d0 = Calendar.getInstance(); d0.add(Calendar.DAY_OF_YEAR, 1); d0.set(Calendar.HOUR_OF_DAY, 0); d0.set(Calendar.MINUTE, 0); d0.set(Calendar.SECOND, 0); d0.set(Calendar.MILLISECOND, 0);
        Calendar d1 = (Calendar) d0.clone(); d1.set(Calendar.HOUR_OF_DAY, 12);
        String title = null; long begin = 0;
        Cursor cur = null;
        try {
            Uri.Builder b = CalendarContract.Instances.CONTENT_URI.buildUpon();
            ContentUris.appendId(b, d0.getTimeInMillis()); ContentUris.appendId(b, d1.getTimeInMillis());
            cur = c.getContentResolver().query(b.build(), new String[]{CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN, CalendarContract.Instances.ALL_DAY},
                    null, null, CalendarContract.Instances.BEGIN + " ASC");
            while (cur != null && cur.moveToNext()) { if (cur.getInt(2) == 0 && cur.getLong(1) >= d0.getTimeInMillis()) { title = cur.getString(0); begin = cur.getLong(1); break; } }
        } catch (Exception ignored) { } finally { if (cur != null) cur.close(); }
        if (title == null) { if (force) post(c, 7004, "Ma\u00f1ana", "No tienes citas por la ma\u00f1ana."); return; }
        AlarmManager.AlarmClockInfo ci = ((AlarmManager) c.getSystemService(Context.ALARM_SERVICE)).getNextAlarmClock();
        // an alarm that rings at least 40 minutes before the event already covers it
        if (ci != null && ci.getTriggerTime() <= begin - 40 * 60 * 1000L && ci.getTriggerTime() >= d0.getTimeInMillis() - 8 * 3600 * 1000L) { if (force) post(c, 7004, "Ma\u00f1ana", "\u00ab" + title + "\u00bb a las " + new SimpleDateFormat("HH:mm", ES).format(new Date(begin)) + ": ya tienes alarma a las " + new SimpleDateFormat("HH:mm", ES).format(new Date(ci.getTriggerTime())) + "."); return; }
        Calendar al = Calendar.getInstance(); al.setTimeInMillis(begin - 60 * 60 * 1000L);
        int mi = (al.get(Calendar.MINUTE) / 5) * 5;
        al.set(Calendar.MINUTE, mi);
        String hm = new SimpleDateFormat("HH:mm", ES).format(al.getTime());
        Intent set = new Intent(android.provider.AlarmClock.ACTION_SET_ALARM)
                .putExtra(android.provider.AlarmClock.EXTRA_HOUR, al.get(Calendar.HOUR_OF_DAY)).putExtra(android.provider.AlarmClock.EXTRA_MINUTES, mi)
                .putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, title)
                .setClassName("com.scratch.iosclock", "com.scratch.iosclock.IntentActivity");
        PendingIntent act = PendingIntent.getActivity(c, 7005, set, PendingIntent.FLAG_UPDATE_CURRENT);
        Notification n = new Notification.Builder(c)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Ma\u00f1ana madrugas")
                .setContentText("\u00ab" + title + "\u00bb a las " + new SimpleDateFormat("HH:mm", ES).format(new Date(begin)) + " y no tienes alarma")
                .setStyle(new Notification.BigTextStyle().bigText("\u00ab" + title + "\u00bb a las " + new SimpleDateFormat("HH:mm", ES).format(new Date(begin)) + " y no tienes ninguna alarma que te despierte a tiempo."))
                .addAction(android.R.drawable.ic_lock_idle_alarm, "Poner alarma a las " + hm, act)
                .setAutoCancel(true)
                .setContentIntent(act)
                .build();
        ((NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE)).notify(7005, n);
    }

    // ---- silence during meetings ---------------------------------------------------------------------------

    /** Stateless planner: if a timed calendar event is on now, hold the ringer on vibrate until it ends; always schedules the next boundary. */
    static void meetings(Context c) {
        SharedPreferences s = p(c);
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        am.cancel(pi(c, A_MEET));
        boolean enabled = s.getBoolean("meet_on", true);
        long now = System.currentTimeMillis();
        long inEnd = 0, nextBegin = Long.MAX_VALUE;
        if (enabled) {
            Cursor cur = null;
            try {
                Uri.Builder b = CalendarContract.Instances.CONTENT_URI.buildUpon();
                ContentUris.appendId(b, now - 12 * 3600 * 1000L); ContentUris.appendId(b, now + 24 * 3600 * 1000L);
                cur = c.getContentResolver().query(b.build(), new String[]{CalendarContract.Instances.BEGIN, CalendarContract.Instances.END, CalendarContract.Instances.ALL_DAY, CalendarContract.Instances.AVAILABILITY}, null, null, CalendarContract.Instances.BEGIN + " ASC");
                while (cur != null && cur.moveToNext()) {
                    long bg = cur.getLong(0), en = cur.getLong(1);
                    if (cur.getInt(2) == 1 || cur.getInt(3) == CalendarContract.Events.AVAILABILITY_FREE || en - bg < 10 * 60 * 1000L) continue;
                    if (bg <= now && en > now) inEnd = Math.max(inEnd, en);
                    else if (bg > now && bg < nextBegin) nextBegin = bg;
                }
            } catch (Exception ignored) { } finally { if (cur != null) cur.close(); }
        }
        boolean inMeeting = inEnd > now;
        AudioManager au = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
        try {
            if (inMeeting && !s.getBoolean("meet_active", false)) {
                s.edit().putInt("meet_prev", au.getRingerMode()).putBoolean("meet_active", true).apply();
                if (au.getRingerMode() == AudioManager.RINGER_MODE_NORMAL) au.setRingerMode(AudioManager.RINGER_MODE_VIBRATE);
            } else if (!inMeeting && s.getBoolean("meet_active", false)) {
                s.edit().putBoolean("meet_active", false).apply();
                if (!s.getBoolean("quiet_active", false)) au.setRingerMode(s.getInt("meet_prev", AudioManager.RINGER_MODE_NORMAL));   // night quiet hours keep their own hold
            }
        } catch (Exception ignored) { }
        long next = inMeeting ? inEnd : nextBegin;
        if (enabled && next != Long.MAX_VALUE && next > now) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next + 500, pi(c, A_MEET));
    }

    static void setMeet(Context c, boolean on) { p(c).edit().putBoolean("meet_on", on).apply(); meetings(c); }
}
