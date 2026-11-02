package com.scratch.iosclock;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;

/** Alarm model, persistence (SharedPreferences) and scheduling (AlarmManager.setAlarmClock). */
final class Alarms {
    static final String FIRE = "com.scratch.iosclock.FIRE";
    static final String PREFS = "clock";
    static final int TIMER_ID = -1;

    static final class Alarm {
        int id;
        int hour, minute;
        int days;            // bit 0 = Monday ... bit 6 = Sunday; 0 = once
        boolean on;
        String label = "";
    }

    private Alarms() { }

    static List<Alarm> load(Context c) {
        List<Alarm> out = new ArrayList<>();
        String raw = prefs(c).getString("alarms", "");
        for (String line : raw.split("\n")) {
            if (line.isEmpty()) continue;
            String[] p = line.split("\t", -1);
            try {
                Alarm a = new Alarm();
                a.id = Integer.parseInt(p[0]); a.hour = Integer.parseInt(p[1]); a.minute = Integer.parseInt(p[2]);
                a.days = Integer.parseInt(p[3]); a.on = "1".equals(p[4]); a.label = p.length > 5 ? p[5] : "";
                out.add(a);
            } catch (Exception ignored) { }
        }
        return out;
    }

    static void save(Context c, List<Alarm> list) {
        StringBuilder sb = new StringBuilder();
        for (Alarm a : list) {
            sb.append(a.id).append('\t').append(a.hour).append('\t').append(a.minute).append('\t').append(a.days).append('\t')
              .append(a.on ? "1" : "0").append('\t').append(a.label.replace('\t', ' ').replace('\n', ' ')).append('\n');
        }
        prefs(c).edit().putString("alarms", sb.toString()).apply();
        rescheduleAll(c);
    }

    static int nextId(List<Alarm> list) {
        int m = 0;
        for (Alarm a : list) m = Math.max(m, a.id);
        return m + 1;
    }

    /** Next time this alarm should ring, or -1 when it is off. */
    static long nextTrigger(Alarm a, long from) {
        if (!a.on) return -1;
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(from);
        c.set(Calendar.HOUR_OF_DAY, a.hour);
        c.set(Calendar.MINUTE, a.minute);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        for (int i = 0; i < 8; i++) {
            if (c.getTimeInMillis() > from && (a.days == 0 || (a.days & (1 << ((c.get(Calendar.DAY_OF_WEEK) + 5) % 7))) != 0)) return c.getTimeInMillis();
            c.add(Calendar.DAY_OF_YEAR, 1);
        }
        return -1;
    }

    static void rescheduleAll(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        long now = System.currentTimeMillis();
        for (Alarm a : load(c)) {
            PendingIntent pi = pending(c, a.id, "alarm");
            long t = nextTrigger(a, now);
            if (t < 0) { am.cancel(pi); pi.cancel(); }
            else am.setAlarmClock(new AlarmManager.AlarmClockInfo(t, show(c)), pi);
        }
        long te = prefs(c).getLong("timer_end", 0);
        if (te > now) am.setExact(AlarmManager.RTC_WAKEUP, te, pending(c, 9000, "timer"));
    }

    static void scheduleSnooze(Context c, String label, int minutes) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        long t = System.currentTimeMillis() + minutes * 60000L;
        PendingIntent pi = pending(c, 9001, "snooze", label);
        am.setAlarmClock(new AlarmManager.AlarmClockInfo(t, show(c)), pi);
    }

    static void startTimer(Context c, long millis) {
        long end = System.currentTimeMillis() + millis;
        prefs(c).edit().putLong("timer_end", end).putLong("timer_total", millis).apply();
        ((AlarmManager) c.getSystemService(Context.ALARM_SERVICE)).setExact(AlarmManager.RTC_WAKEUP, end, pending(c, 9000, "timer"));
    }

    static void cancelTimer(Context c) {
        prefs(c).edit().putLong("timer_end", 0).apply();
        PendingIntent pi = pending(c, 9000, "timer");
        ((AlarmManager) c.getSystemService(Context.ALARM_SERVICE)).cancel(pi);
        pi.cancel();
    }

    static PendingIntent pending(Context c, int id, String kind) { return pending(c, id, kind, ""); }

    static PendingIntent pending(Context c, int id, String kind, String label) {
        Intent i = new Intent(FIRE).setClass(c, AlarmReceiver.class).putExtra("id", id).putExtra("kind", kind).putExtra("label", label);
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT);
    }

    private static PendingIntent show(Context c) {
        return PendingIntent.getActivity(c, 0, new Intent(c, ClockActivity.class), PendingIntent.FLAG_UPDATE_CURRENT);
    }

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE); }

    static String daysText(int days) {
        if (days == 0) return "Una vez";
        if (days == 127) return "Todos los días";
        if (days == 31) return "Entre semana";
        if (days == 96) return "Fines de semana";
        String[] n = {"L", "M", "X", "J", "V", "S", "D"};
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 7; i++) if ((days & (1 << i)) != 0) sb.append(sb.length() > 0 ? " " : "").append(n[i]);
        return sb.toString();
    }
}
