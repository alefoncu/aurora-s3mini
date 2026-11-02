package com.scratch.iosclock;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.PowerManager;

import java.util.List;

/** Fires alarms and timers: reschedules repeating alarms and opens the ring screen. */
public class AlarmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
        PowerManager.WakeLock wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "iosclock");
        wl.acquire(30000);

        String kind = i.getStringExtra("kind");
        String label = i.getStringExtra("label");
        int id = i.getIntExtra("id", 0);
        if ("com.scratch.iosclock.TEST".equals(i.getAction())) {          // am broadcast -a ...TEST --ei seconds 20
            int sec = i.getIntExtra("seconds", 20);
            Alarms.startTimer(c, sec * 1000L);
            return;
        }
        if ("alarm".equals(kind)) {
            List<Alarms.Alarm> list = Alarms.load(c);
            for (Alarms.Alarm a : list) {
                if (a.id == id) {
                    label = a.label;
                    if (a.days == 0) a.on = false;          // one-shot alarms switch themselves off
                }
            }
            Alarms.save(c, list);                          // also schedules the next occurrence of repeating ones
        } else if ("snooze".equals(kind)) {
            Alarms.prefs(c).edit().putLong("snooze_end", 0).apply();
        } else if ("timer".equals(kind)) {
            Alarms.prefs(c).edit().putLong("timer_end", 0).apply();
            label = "Temporizador";
        }
        Intent ring = new Intent(c, RingActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                .putExtra("label", label == null || label.isEmpty() ? ("timer".equals(kind) ? "Temporizador" : "Alarma") : label)
                .putExtra("kind", kind);
        c.startActivity(ring);
    }
}
