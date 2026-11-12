package com.scratch.wheelie;

/** Per-run score, rewards and milestones. No Android dependencies. */
public final class RunProgress {
    public float score;
    public int combo = 1, missions, earned;
    public String notice = "";
    public float noticeTime;
    private float furthestDistance;

    public void reset() {
        score = furthestDistance = noticeTime = 0;
        combo = 1;
        missions = earned = 0;
        notice = "";
    }

    public void update(float dt, float distance, float speed, float angle,
                       float wheelieDistance, float bestWheelie, boolean finished) {
        if (!finite(dt) || dt < 0 || !finite(distance) || !finite(speed)
                || !finite(angle) || !finite(wheelieDistance) || !finite(bestWheelie)) return;

        noticeTime = Math.max(0, noticeTime - dt);
        if (noticeTime == 0) notice = "";
        distance = Math.max(0, distance);
        combo = angle > .20f && speed > 1f
                ? 1 + (int) Math.min(4, Math.max(0, wheelieDistance) / 25f) : 1;
        float advance = Math.max(0, distance - furthestDistance);
        score += advance * combo;
        furthestDistance = Math.max(furthestDistance, distance);

        int achieved = (distance >= 250 ? 1 : 0)
                | (bestWheelie >= 25 ? 2 : 0) | (finished ? 4 : 0);
        int newlyAchieved = achieved & ~missions;
        missions |= achieved;
        if (newlyAchieved != 0) {
            if ((newlyAchieved & 4) != 0) notice = "¡Ruta completada! +5 monedas";
            else if ((newlyAchieved & 2) != 0) notice = "¡Caballito de 25 m! +5 monedas";
            else notice = "¡250 metros recorridos! +5 monedas";
            noticeTime = 2.5f;
        }
        earned = (int) (furthestDistance / 80f) + 5 * Integer.bitCount(missions);
    }

    /** Swept wheel contact with each cone's full 0.9 m footprint. */
    public static boolean hitsCone(float previousX, float x, float angle, float speed) {
        if (!finite(previousX) || !finite(x) || !finite(angle) || !finite(speed)
                || x < previousX || x > 1200 || speed <= 2 || angle >= .25f) return false;
        for (int k = 0; k <= 12; k++) {
            float cone = 65 + 90 * k;
            if (previousX <= cone + .9f && x >= cone) return true;
        }
        return false;
    }

    private static boolean finite(float value) {
        return !Float.isNaN(value) && !Float.isInfinite(value);
    }
}
