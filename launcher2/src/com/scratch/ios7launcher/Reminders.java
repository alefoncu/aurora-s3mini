package com.scratch.ios7launcher;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;

import java.util.ArrayList;
import java.util.List;

/** Reminders set from the search ("recuérdame …"): an exact alarm per reminder, kept in preferences and re-armed after a reboot. */
public class Reminders extends BroadcastReceiver {
    static final String ACTION_FIRE = "com.scratch.ios7launcher.REMIND";

    @Override public void onReceive(Context c, Intent i) {
        String a = i.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(a) || Intent.ACTION_MY_PACKAGE_REPLACED.equals(a)) { rearm(c); return; }
        if (!ACTION_FIRE.equals(a)) return;
        long when = i.getLongExtra("when", 0);
        String text = i.getStringExtra("text");
        Notification n = new Notification.Builder(c)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle("Recordatorio")
                .setContentText(text)
                .setStyle(new Notification.BigTextStyle().bigText(text))
                .setDefaults(Notification.DEFAULT_ALL)
                .setPriority(Notification.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(PendingIntent.getActivity(c, 0, new Intent(c, HomeActivity.class), 0))
                .build();
        ((NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE)).notify((int) (when / 1000), n);
        remove(c, when);
    }

    static void add(Context c, long when, String text) {
        SharedPreferences p = c.getSharedPreferences("reminders", Context.MODE_PRIVATE);
        String old = p.getString("list", "");
        p.edit().putString("list", old + when + "|" + text.replace('\n', ' ') + "\n").apply();
        arm(c, when, text);
    }

    private static void remove(Context c, long when) {
        SharedPreferences p = c.getSharedPreferences("reminders", Context.MODE_PRIVATE);
        StringBuilder sb = new StringBuilder();
        for (String l : p.getString("list", "").split("\n")) if (!l.isEmpty() && !l.startsWith(when + "|")) sb.append(l).append('\n');
        p.edit().putString("list", sb.toString()).apply();
    }

    static List<String[]> pending(Context c) {
        List<String[]> out = new ArrayList<>();
        for (String l : c.getSharedPreferences("reminders", Context.MODE_PRIVATE).getString("list", "").split("\n")) {
            int bar = l.indexOf('|');
            if (bar > 0) out.add(new String[]{l.substring(0, bar), l.substring(bar + 1)});
        }
        return out;
    }

    private static void arm(Context c, long when, String text) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(c, Reminders.class).setAction(ACTION_FIRE).putExtra("when", when).putExtra("text", text);
        i.setData(Uri.parse("reminder://" + when));
        PendingIntent pi = PendingIntent.getBroadcast(c, 0, i, PendingIntent.FLAG_UPDATE_CURRENT);
        if (Build.VERSION.SDK_INT >= 23) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
        else am.setExact(AlarmManager.RTC_WAKEUP, when, pi);
    }

    static void rearm(Context c) {
        long now = System.currentTimeMillis();
        for (String[] r : pending(c)) {
            long w = Long.parseLong(r[0]);
            if (w > now) arm(c, w, r[1]);
            else { Intent i = new Intent(ACTION_FIRE).setClass(c, Reminders.class).putExtra("when", w).putExtra("text", r[1]); new Reminders().onReceive(c, i); }
        }
    }
}
