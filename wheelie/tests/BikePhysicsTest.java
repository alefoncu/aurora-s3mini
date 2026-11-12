package com.scratch.wheelie;

public final class BikePhysicsTest {
    private static void check(boolean pass, String message) {
        if (!pass) throw new AssertionError(message);
    }

    private static BikePhysics ride(int profile, float seconds) {
        BikePhysics bike = new BikePhysics();
        bike.setProfile(profile);
        for (int i = 0; i < seconds * 120 && !bike.finished && !bike.crashed; i++) {
            bike.update(1f / 120, true, false, false, false);
        }
        return bike;
    }

    public static void main(String[] args) {
        BikePhysics bike = new BikePhysics();
        for (int i = 0; i < 600; i++) bike.update(1f / 60, false, false, false, false);
        check(bike.x == 0 && !bike.crashed, "Stationary bike remains grounded");
        for (int i = 0; i < 300; i++) bike.update(1f / 60, true, false, false, true);
        check(bike.x > 30 && bike.speed > 10 && !bike.crashed, "Forward lean permits normal riding");
        float before = bike.speed;
        for (int i = 0; i < 120; i++) bike.update(1f / 60, false, true, false, false);
        check(bike.speed < before && bike.angle == 0, "Brake slows down and lowers front");
        bike.reset();
        for (int i = 0; i < 1200 && !bike.crashed; i++) bike.update(1f / 60, true, false, true, false);
        check(bike.crashed && bike.bestWheelie > 1, "Holding rear lean produces wheelie then crash");
        float crashX = bike.x;
        bike.update(.2f, true, false, false, true);
        check(bike.x == crashX, "Crash freezes simulation");
        bike.reset();
        check(bike.x == 0 && bike.bestWheelie == 0 && bike.coins == 0 && !bike.crashed, "Restart clears run");
        BikePhysics coarse = new BikePhysics();
        for (int i = 0; i < 600; i++) bike.update(1f / 60, true, false, false, true);
        for (int i = 0; i < 50; i++) coarse.update(.2f, true, false, false, true);
        check(Math.abs(coarse.x - bike.x) < .1f, "Substeps keep frame-rate independent travel");
        float validX = bike.x;
        bike.update(Float.NaN, true, false, false, false);
        bike.update(Float.POSITIVE_INFINITY, true, false, false, false);
        bike.update(-1, true, false, false, false);
        check(bike.x == validX, "Invalid elapsed times ignored");
        for (int i = 0; i < 10000 && !bike.finished; i++) bike.update(1f / 60, true, false, false, true);
        check(bike.finished && bike.distance == 1200 && bike.coins == 15, "Course can be completed and coins awarded");
        for (int i = 0; i < 20000; i++) {
            float x = i * .1f;
            check(Math.abs(BikePhysics.slope(x)) < .25f, "Road remains smoothly rideable");
        }
        bike.reset();
        for (int i = 0; i < 6000 && !bike.finished && !bike.crashed; i++) {
            bike.update(1f / 60, true, false, bike.angle < .5f, bike.angle > .8f);
        }
        check(bike.finished && bike.bestWheelie > 100, "Alternating lean controls can sustain a long wheelie");
        for (int profile = 0; profile < 3; profile++) {
            BikePhysics easy = ride(profile, 180);
            check(easy.finished && !easy.crashed && easy.angle == 0,
                    "Gas alone completes route without involuntary wheelie, profile " + profile);
            check(easy.bestWheelie == 0, "Ordinary riding does not earn wheelie distance");
            BikePhysics tipped = new BikePhysics();
            tipped.setProfile(profile);
            for (int i = 0; i < 2400 && !tipped.crashed; i++) {
                tipped.update(1f / 120, true, false, true, false);
            }
            check(tipped.crashed && tipped.bestWheelie > 1,
                    "Holding rear lean too long still tips each bike");

            BikePhysics balanced = new BikePhysics();
            balanced.setProfile(profile);
            boolean lifting = true;
            int corrections = 0;
            for (int i = 0; i < 22000 && !balanced.finished && !balanced.crashed; i++) {
                if (balanced.angle > .85f && lifting) { lifting = false; corrections++; }
                else if (balanced.angle < .50f) lifting = true;
                balanced.update(1f / 120, true, false, lifting, !lifting);
            }
            check(balanced.finished && balanced.bestWheelie > 100 && corrections > 10,
                    "Rear and forward corrections sustain wheelie, profile " + profile);

            BikePhysics released = new BikePhysics();
            released.setProfile(profile);
            for (int i = 0; i < 1200 && released.angle < .65f; i++) {
                released.update(1f / 120, true, false, true, false);
            }
            float liftedAngle = released.angle;
            check(liftedAngle >= .65f, "Rear lean lifts selected bike");
            for (int i = 0; i < 480; i++) released.update(1f / 120, true, false, false, false);
            check(!released.crashed && released.angle == 0, "Releasing rear lean returns to ground");

            BikePhysics forward = new BikePhysics();
            forward.setProfile(profile);
            forward.speed = 10; forward.angle = .8f;
            BikePhysics passive = new BikePhysics();
            passive.setProfile(profile);
            passive.speed = 10; passive.angle = .8f;
            for (int i = 0; i < 36; i++) {
                forward.update(1f / 120, true, false, false, true);
                passive.update(1f / 120, true, false, false, false);
            }
            check(forward.angle < passive.angle - .05f, "Forward correction is faster than releasing");
            balanced.reset();
            check(balanced.profile == profile && balanced.x == 0 && balanced.bestWheelie == 0,
                    "Reset retains selected bike but clears the run");
        }
        BikePhysics trail = ride(0, 15), street = ride(1, 15), bmx = ride(2, 15);
        check(street.x > trail.x + 15 && trail.x > bmx.x + 35, "Profiles have distinct acceleration and speed");
        check(street.speed <= 27 && trail.speed <= 21 && bmx.speed <= 13, "Profile speed limits enforced");
        bike.setProfile(99); check(bike.profile == 2, "High invalid profile is bounded");
        bike.setProfile(-2); check(bike.profile == 0, "Low invalid profile is bounded");
        System.out.println("BikePhysics: 10 base scenarios and all 3 profile suites passed");
    }
}
