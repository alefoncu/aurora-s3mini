package com.scratch.ios7launcher;

import android.content.Intent;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

import java.util.HashMap;
import java.util.Map;

/** Counts active notifications per package so the launcher can draw badges on icons. */
public class BadgeService extends NotificationListenerService {
    static final String ACTION = "com.scratch.ios7launcher.BADGES";
    static volatile Map<String, Integer> counts = new HashMap<>();

    @Override public void onListenerConnected() { recount(); }
    @Override public void onNotificationPosted(StatusBarNotification sbn) { recount(); }
    @Override public void onNotificationRemoved(StatusBarNotification sbn) { recount(); }

    private void recount() {
        Map<String, Integer> m = new HashMap<>();
        try {
            StatusBarNotification[] all = getActiveNotifications();
            if (all != null) for (StatusBarNotification n : all) {
                if (!n.isClearable() && n.isOngoing()) continue;       // media / sync: not a badge
                if (n.isOngoing()) continue;
                String p = n.getPackageName();
                String tgt = n.getNotification().extras == null ? null : n.getNotification().extras.getString("badge_for");   // test helper: NotifyReceiver --es badge_for <pkg>
                if (tgt != null) p = tgt;
                if (p.equals("android")) continue;
                Integer c = m.get(p);
                m.put(p, c == null ? 1 : c + 1);
            }
        } catch (Exception e) { }
        counts = m;
        sendBroadcast(new Intent(ACTION).setPackage(getPackageName()));
    }
}
