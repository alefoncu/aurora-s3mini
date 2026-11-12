package com.scratch.wheelie;

public final class RunProgressTest {
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
    private static void close(float actual, float expected, String message) {
        check(Math.abs(actual - expected) < .001f, message + ": " + actual);
    }
    public static void main(String[] args) {
        RunProgress run = new RunProgress();
        run.update(.1f, 10, 5, 0, 0, 0, false);
        close(run.score, 10, "Normal riding scores distance");
        run.update(.1f, 10, 5, .6f, 60, 60, false);
        close(run.score, 10, "Stationary position cannot rescore distance");
        check(run.combo == 3 && run.missions == 2 && run.earned == 5, "Wheelie milestone and combo");
        run.update(.1f, 15, 5, .6f, 100, 100, false);
        close(run.score, 35, "Only new distance receives capped x5 combo");
        check(run.combo == 5, "Combo caps at five");
        run.update(.1f, 20, 5, .2f, 100, 100, false);
        check(run.combo == 1, "Touching down resets combo");
        close(run.score, 40, "Grounded distance scores normally");
        run.update(.1f, 21, 1, .6f, 100, 100, false);
        check(run.combo == 1, "Slow wheelie gets no multiplier");

        run.update(.1f, 250, 10, 0, 0, 100, false);
        check(run.missions == 3 && run.earned == 13, "250 metres and wheelie award five each plus road coins");
        check(run.notice.contains("250") && run.noticeTime == 2.5f, "New milestone announces reward");
        run.update(1, 250, 0, 0, 0, 100, false);
        close(run.noticeTime, 1.5f, "Repeated update does not restart notice");
        run.update(2, 250, 0, 0, 0, 100, false);
        check(run.noticeTime == 0 && run.notice.length() == 0, "Notice expires");
        run.update(.1f, 1200, 0, 0, 0, 100, true);
        check(run.missions == 7 && run.earned == 30, "Finish awards all milestone rewards once");
        float score = run.score;
        run.update(.1f, 1190, 5, 0, 0, 100, false);
        run.update(.1f, 1200, 5, 0, 0, 100, true);
        close(run.score, score, "Revisited distance cannot farm score");
        check(run.earned == 30, "Revisited distance keeps rewards stable");
        run.update(Float.NaN, 1400, 5, 0, 0, 100, false);
        run.update(.1f, Float.POSITIVE_INFINITY, 5, 0, 0, 100, false);
        close(run.score, score, "Invalid input cannot poison progress");
        run.reset();
        check(run.score == 0 && run.combo == 1 && run.missions == 0 && run.earned == 0
                && run.noticeTime == 0 && run.notice.length() == 0, "Restart clears all state");
        run.update(.1f, 5, 5, 0, 0, 0, false);
        close(run.score, 5, "Restart clears distance watermark");

        check(RunProgress.hitsCone(64.8f, 66.2f, 0, 24), "Swept collision survives skipped footprint");
        check(RunProgress.hitsCone(65.2f, 65.7f, 0, 8), "Collision still applies inside footprint");
        check(!RunProgress.hitsCone(66, 67, 0, 8), "Leaving footprint is clear");
        check(!RunProgress.hitsCone(64, 66, .25f, 8), "Lifted wheel clears cone");
        check(!RunProgress.hitsCone(64, 66, 0, 2), "Crawling does not crash");
        check(RunProgress.hitsCone(154, 157, 0, 24), "Later cones collide");
        check(RunProgress.hitsCone(1144, 1147, 0, 24), "Thirteenth cone collides");
        check(!RunProgress.hitsCone(1234, 1237, 0, 24), "No cone beyond course");
        check(!RunProgress.hitsCone(0, 64.9f, 0, 24), "No obstacle before first cone");
        check(!RunProgress.hitsCone(66, 64, 0, 24), "Backward movement ignored");
        check(!RunProgress.hitsCone(Float.NaN, 66, 0, 24), "Invalid collision input ignored");
        System.out.println("RunProgress: scoring, rewards, reset and swept collisions passed");
    }
}
