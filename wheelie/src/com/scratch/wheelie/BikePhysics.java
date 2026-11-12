package com.scratch.wheelie;

/** Small deterministic wheelie model. Distances are metres, angles radians above the road. */
public final class BikePhysics {
    public float x, speed, angle, angularVelocity, distance, wheelieDistance, bestWheelie;
    public boolean crashed, finished;
    public int coins;
    /** 0 = forgiving trail bike, 1 = heavier/faster street bike, 2 = light BMX. */
    public int profile;
    public static final float FINISH = 1200f;
    private static final float STEP = 1f / 120f;
    private static final float[] ACCELERATION = {5.2f, 6.3f, 3.6f};
    private static final float[] MAX_SPEED = {21f, 27f, 13f};
    private static final float[] DRAG = {.008f, .006f, .012f};
    private static final float[] REAR_TORQUE = {3.0f, 2.7f, 3.5f};
    private static final float[] DAMPING = {2.8f, 3.4f, 2.3f};

    public BikePhysics() { reset(); }

    /** Changes handling without discarding the current run; reset keeps the selected bike. */
    public void setProfile(int value) { profile = Math.max(0, Math.min(2, value)); }

    public void reset() {
        x = speed = angle = angularVelocity = distance = wheelieDistance = bestWheelie = 0;
        crashed = finished = false;
        coins = 0;
    }

    /** A stalled UI frame advances at most 250 ms; paused time is never simulated. */
    public void update(float dt, boolean throttle, boolean brake, boolean leanBack, boolean leanForward) {
        if (crashed || finished || Float.isNaN(dt) || Float.isInfinite(dt) || dt <= 0) return;
        float remaining = Math.min(dt, .25f);
        while (remaining > .000001f && !crashed && !finished) {
            float h = Math.min(STEP, remaining);
            integrate(h, throttle, brake, leanBack, leanForward);
            remaining -= h;
        }
    }

    private void integrate(float dt, boolean throttle, boolean brake, boolean back, boolean forward) {
        int kind = Math.max(0, Math.min(2, profile));
        float acceleration = (throttle ? ACCELERATION[kind] : 0f) - .3f - DRAG[kind] * speed * speed
                - 9.81f * slope(x) - (brake ? 10f : 0f);
        speed = clamp(speed + acceleration * dt, 0, MAX_SPEED[kind]);
        float oldX = x;
        x = Math.min(FINISH, x + speed * dt);
        distance = x;
        coins = (int) (x / 80f);

        float moving = Math.min(1f, speed / (kind == 2 ? 3f : 5f));
        // Gas alone stays planted. Rear lean supplies the deliberate lift; releasing it
        // restores gravity even near the balance point instead of silently tipping over.
        float torque = (throttle ? (kind == 2 ? .2f : .6f) * moving : 0f)
                + (back ? REAR_TORQUE[kind] * moving : 0f) - (forward ? 3.8f : 0f)
                - (brake ? 4.2f : 0f) - 1.3f * (float) Math.cos(angle)
                - .6f * angle - DAMPING[kind] * angularVelocity;
        angularVelocity += torque * dt;
        angle += angularVelocity * dt;
        if (angle < 0) { angle = 0; angularVelocity = 0; }
        if (angle > .20f && speed > 1f) {
            wheelieDistance += x - oldX;
            bestWheelie = Math.max(bestWheelie, wheelieDistance);
        } else {
            wheelieDistance = 0;
        }
        if (angle > 1.55f) { crashed = true; speed = 0; }
        if (x >= FINISH) { finished = true; speed = 0; }
    }

    /** Smooth fade from the introductory flat into low rolling hills. */
    public static float ground(float x) {
        float t = clamp((x - 60f) / 40f, 0, 1);
        float fade = t * t * (3 - 2 * t);
        return fade * (1.3f * (float) Math.sin((x - 60f) / 23f)
                + .45f * (float) Math.sin((x - 60f) / 8f));
    }

    public static float slope(float x) {
        return (ground(x + .05f) - ground(x - .05f)) / .1f;
    }

    private static float clamp(float v, float min, float max) {
        return Math.max(min, Math.min(max, v));
    }
}
