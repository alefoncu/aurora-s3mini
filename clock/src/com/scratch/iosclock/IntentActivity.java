package com.scratch.iosclock;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.AlarmClock;
import android.widget.Toast;

import java.util.List;

/** Invisible handler for AlarmClock.ACTION_SET_ALARM / ACTION_SET_TIMER (used by the launcher's search). */
public class IntentActivity extends Activity {
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        Intent in = getIntent();
        String act = in == null ? "" : String.valueOf(in.getAction());
        try {
            if (AlarmClock.ACTION_SET_ALARM.equals(act)) {
                int h = in.getIntExtra(AlarmClock.EXTRA_HOUR, -1), m = in.getIntExtra(AlarmClock.EXTRA_MINUTES, 0);
                if (h >= 0 && h < 24 && m >= 0 && m < 60) {
                    List<Alarms.Alarm> list = Alarms.load(this);
                    Alarms.Alarm a = new Alarms.Alarm();
                    a.id = Alarms.nextId(list); a.hour = h; a.minute = m; a.days = 0; a.on = true;
                    String msg = in.getStringExtra(AlarmClock.EXTRA_MESSAGE);
                    a.label = msg == null ? "" : msg;
                    list.add(a);
                    Alarms.save(this, list);
                    Toast.makeText(this, String.format("Alarma a las %02d:%02d", h, m), Toast.LENGTH_SHORT).show();
                }
            } else if (AlarmClock.ACTION_SET_TIMER.equals(act)) {
                int s = in.getIntExtra(AlarmClock.EXTRA_LENGTH, 0);
                if (s > 0) {
                    Alarms.startTimer(this, s * 1000L);
                    Toast.makeText(this, "Temporizador de " + (s >= 60 ? (s / 60) + " min" : s + " s"), Toast.LENGTH_SHORT).show();
                }
            }
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo crear", Toast.LENGTH_SHORT).show();
        }
        finish();
    }
}
