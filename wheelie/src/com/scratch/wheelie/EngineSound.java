package com.scratch.wheelie;

import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

/**
 * Small procedural motor, with no assets or permissions.
 * Enable once from the sound preference; call set() while riding, pause() on menus
 * or Activity.onPause(), and close() from Activity.onDestroy(). A later set()
 * resumes after pause. None of these calls waits for audio shutdown on the UI.
 */
public final class EngineSound {
    private static final int RATE = 22050;
    private static final int BLOCK = 441; // 20 ms; bounds stop latency and allocation.
    private static final int TABLE_SIZE = 1024;
    private final Object lock = new Object();
    private boolean enabled, playing, closed;
    private Thread worker;
    private volatile float speed;
    private volatile boolean throttle;
    private volatile int profile;

    public EngineSound() { }

    public void set(float metresPerSecond, boolean accelerating, int bikeProfile) {
        speed = Float.isNaN(metresPerSecond) || Float.isInfinite(metresPerSecond)
                ? 0 : Math.max(0, Math.min(40, metresPerSecond));
        throttle = accelerating;
        profile = Math.max(0, Math.min(2, bikeProfile));
        synchronized (lock) {
            if (closed) return;
            playing = true;
            startIfNeeded();
            lock.notifyAll();
        }
    }

    public void setEnabled(boolean value) {
        synchronized (lock) {
            if (closed) return;
            enabled = value;
            startIfNeeded();
            lock.notifyAll();
        }
    }

    public void pause() {
        synchronized (lock) {
            playing = false;
            lock.notifyAll();
        }
    }

    public void close() {
        synchronized (lock) {
            closed = true;
            playing = false;
            lock.notifyAll();
        }
    }

    /** Called only with lock held. Exactly one worker survives pause/resume. */
    private void startIfNeeded() {
        if (worker != null || !enabled || !playing) return;
        worker = new Thread(new Runnable() {
            @Override public void run() { render(); }
        }, "WheelieEngine");
        worker.setDaemon(true);
        worker.start();
    }

    private void render() {
        AudioTrack audio = null;
        try {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_DEFAULT);
            short[] pcm = new short[BLOCK];
            float[] sine = new float[TABLE_SIZE];
            for (int i = 0; i < TABLE_SIZE; i++) {
                sine[i] = (float) Math.sin(i * Math.PI * 2 / TABLE_SIZE);
            }
            float phase = 0, frequency = 45, volume = 0, filteredNoise = 0;
            int random = 0x7135f;
            while (true) {
                boolean audible;
                synchronized (lock) {
                    if (closed) return;
                    audible = enabled && playing;
                }
                if (!audible) {
                    // Only the worker ever touches AudioTrack, including release.
                    release(audio);
                    audio = null;
                    volume = 0;
                    synchronized (lock) {
                        while (!closed && (!enabled || !playing)) lock.wait();
                        if (closed) return;
                    }
                    continue;
                }
                if (audio == null) {
                    int minimum = AudioTrack.getMinBufferSize(RATE,
                            AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
                    if (minimum <= 0) throw new IllegalStateException("PCM output unavailable");
                    audio = new AudioTrack(AudioManager.STREAM_MUSIC, RATE,
                            AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                            Math.max(minimum, BLOCK * 10), AudioTrack.MODE_STREAM);
                    if (audio.getState() != AudioTrack.STATE_INITIALIZED) {
                        throw new IllegalStateException("Audio output not initialized");
                    }
                    audio.setVolume(.10f);
                    audio.play();
                }

                float currentSpeed = speed;
                boolean gas = throttle;
                int kind = profile;
                float targetFrequency = (kind == 1 ? 34 : 45)
                        + currentSpeed * (kind == 1 ? 4 : 5) + (gas ? 17 : 0);
                float targetVolume = kind == 2
                        ? Math.min(.045f, currentSpeed * .004f)
                        : (gas ? .65f : currentSpeed > .2f ? .32f : .13f);
                for (int i = 0; i < BLOCK; i++) {
                    frequency += (targetFrequency - frequency) * .001f;
                    volume += (targetVolume - volume) * .0015f;
                    phase += frequency * TABLE_SIZE / RATE;
                    if (phase >= TABLE_SIZE) phase -= TABLE_SIZE;
                    int index = (int) phase;
                    random = random * 1664525 + 1013904223;
                    float noise = ((random >>> 8) / 8388608f) - 1;
                    filteredNoise += (noise - filteredNoise) * .15f;
                    float sample = kind == 2 ? filteredNoise
                            : sine[index] * .55f
                            + sine[(index * 2) & (TABLE_SIZE - 1)] * .23f
                            + sine[(index * 3) & (TABLE_SIZE - 1)] * .10f
                            + filteredNoise * .12f;
                    pcm[i] = (short) (sample * volume * 30000);
                }
                int offset = 0;
                while (offset < BLOCK) {
                    int count = audio.write(pcm, offset, BLOCK - offset);
                    if (count <= 0) throw new IllegalStateException("PCM write failed");
                    offset += count;
                }
            }
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        } catch (RuntimeException ignored) {
            // Failure is silent and disables sound, avoiding retry loops every frame.
            synchronized (lock) { enabled = false; playing = false; }
        } finally {
            release(audio);
            synchronized (lock) { worker = null; }
        }
    }

    private static void release(AudioTrack audio) {
        if (audio == null) return;
        try { audio.pause(); } catch (RuntimeException ignored) { }
        try { audio.flush(); } catch (RuntimeException ignored) { }
        try { audio.release(); } catch (RuntimeException ignored) { }
    }
}
