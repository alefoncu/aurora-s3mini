package com.scratch.ios7launcher;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** The calendar changed (an event was added, moved or deleted): re-plan the meeting silence. */
public class CalendarWatch extends BroadcastReceiver {
    @Override public void onReceive(Context c, Intent i) { Routines.meetings(c); }
}
