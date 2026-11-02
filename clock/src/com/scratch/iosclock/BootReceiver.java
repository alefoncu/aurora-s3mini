package com.scratch.iosclock;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Alarms do not survive a reboot or a clock/timezone change: schedule them again. */
public class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c, Intent i) { Alarms.rescheduleAll(c); }
}
