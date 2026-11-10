package com.scratch.ios7launcher;

import android.accessibilityservice.AccessibilityService;
import android.view.accessibility.AccessibilityEvent;

/** Does nothing but expose the system's global actions (split screen, recents) to the launcher without root. */
public class SplitService extends AccessibilityService {
    static volatile SplitService inst;

    @Override protected void onServiceConnected() { super.onServiceConnected(); inst = this; }
    @Override public boolean onUnbind(android.content.Intent i) { inst = null; return super.onUnbind(i); }
    @Override public void onAccessibilityEvent(AccessibilityEvent e) { }
    @Override public void onInterrupt() { }

    static boolean splitScreen() { SplitService s = inst; return s != null && s.performGlobalAction(GLOBAL_ACTION_TOGGLE_SPLIT_SCREEN); }
    static boolean recents() { SplitService s = inst; return s != null && s.performGlobalAction(GLOBAL_ACTION_RECENTS); }
}
