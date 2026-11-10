package com.scratch.ios7launcher;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Test helper: `am broadcast -a com.scratch.ios7launcher.NOTIFY --es title T --es text X -n com.scratch.ios7launcher/.NotifyReceiver`. */
public class NotifyReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        Notification n = new Notification.Builder(c)
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setContentTitle(i.getStringExtra("title"))
                .setContentText(i.getStringExtra("text"))
                .setWhen(System.currentTimeMillis())
                .addExtras(extras(i))
                .build();
        ((NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE)).notify(i.getIntExtra("id", 1), n);
    }

    private static android.os.Bundle extras(Intent i) {
        android.os.Bundle b = new android.os.Bundle();
        if (i.getStringExtra("badge_for") != null) b.putString("badge_for", i.getStringExtra("badge_for"));
        return b;
    }
}
