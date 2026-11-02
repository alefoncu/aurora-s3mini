package com.scratch.ioscamera;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.media.MediaRecorder;

import android.util.Log;

import java.io.IOException;
import java.nio.ByteBuffer;

/**
 * Records camera preview frames (NV21) and microphone audio with the software
 * encoders, because the device's hardware H264 encoder cannot be started.
 */
class VideoRecorder {
    private static final String AVC = "OMX.google.h264.encoder";
    private static final String AAC = "OMX.google.aac.encoder";
    private static final int SAMPLE_RATE = 44100;

    private final int w, h;
    private final MediaMuxer muxer;
    private MediaCodec venc, aenc;
    private AudioRecord audio;
    private Thread vThread, aThread;
    private volatile boolean running;
    private final Object lock = new Object();
    private int vTrack = -1, aTrack = -1;
    private boolean muxing;
    private long baseNs;
    private final byte[] i420;
    private final boolean withAudio;
    private long audioStartUs = -1, audioSamples;
    private final java.util.ArrayList<Object[]> pending = new java.util.ArrayList<>();

    VideoRecorder(String path, int w, int h, int rotation, boolean withAudio) throws IOException {
        this.w = w;
        this.h = h;
        this.withAudio = withAudio;
        i420 = new byte[w * h * 3 / 2];
        muxer = new MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        muxer.setOrientationHint(rotation);

        MediaFormat vf = MediaFormat.createVideoFormat("video/avc", w, h);
        vf.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar);
        vf.setInteger(MediaFormat.KEY_BIT_RATE, 800000);
        vf.setInteger(MediaFormat.KEY_FRAME_RATE, 15);
        vf.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2);
        venc = MediaCodec.createByCodecName(AVC);
        venc.configure(vf, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);

        if (withAudio) {
            MediaFormat af = MediaFormat.createAudioFormat("audio/mp4a-latm", SAMPLE_RATE, 1);
            af.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC);
            af.setInteger(MediaFormat.KEY_BIT_RATE, 64000);
            af.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384);
            aenc = MediaCodec.createByCodecName(AAC);
            aenc.configure(af, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            int min = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            audio = new AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, Math.max(min, 16384));
        }
    }

    void start() {
        baseNs = System.nanoTime();
        running = true;
        venc.start();
        vThread = new Thread(() -> drain(venc, true), "venc-drain");
        vThread.start();
        if (withAudio) {
            aenc.start();
            audio.startRecording();
            aThread = new Thread(this::audioLoop, "audio");
            aThread.start();
        }
    }

    /** Called with each preview frame; frames are dropped when the encoder is busy. */
    void onFrame(byte[] nv21) {
        if (!running) return;
        int ys = w * h;
        System.arraycopy(nv21, 0, i420, 0, ys);
        int u = ys, v = ys + ys / 4;
        for (int i = ys; i < ys + ys / 2; i += 2) {
            i420[v++] = nv21[i];
            i420[u++] = nv21[i + 1];
        }
        try {
            int idx = venc.dequeueInputBuffer(0);
            if (idx < 0) return;
            ByteBuffer in = venc.getInputBuffer(idx);
            in.clear();
            in.put(i420);
            venc.queueInputBuffer(idx, 0, i420.length, (System.nanoTime() - baseNs) / 1000, 0);
        } catch (IllegalStateException ignored) { }
    }

    private void audioLoop() {
        byte[] pcm = new byte[4096];
        while (running) {
            int n = audio.read(pcm, 0, pcm.length);
            if (n <= 0) continue;
            // Derive timestamps from the sample count so they stay strictly monotonic.
            if (audioStartUs < 0) audioStartUs = (System.nanoTime() - baseNs) / 1000 - (n / 2) * 1000000L / SAMPLE_RATE;
            long pts = audioStartUs + audioSamples * 1000000L / SAMPLE_RATE;
            audioSamples += n / 2;
            feedAudio(pcm, n, pts, 0);
            drainOnce(aenc, false, 0);
        }
        feedAudio(pcm, 0, audioStartUs + audioSamples * 1000000L / SAMPLE_RATE, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
        drain(aenc, false);
    }

    private void feedAudio(byte[] pcm, int n, long pts, int flags) {
        int idx = aenc.dequeueInputBuffer(20000);
        if (idx < 0) return;
        ByteBuffer in = aenc.getInputBuffer(idx);
        in.clear();
        in.put(pcm, 0, n);
        aenc.queueInputBuffer(idx, 0, n, pts, flags);
    }

    /** Drains until end-of-stream. */
    private void drain(MediaCodec c, boolean video) {
        while (drainOnce(c, video, 10000)) { }
    }

    /** @return false once end-of-stream was seen. */
    private boolean drainOnce(MediaCodec c, boolean video, long timeoutUs) {
        MediaCodec.BufferInfo bi = new MediaCodec.BufferInfo();
        while (true) {
            int idx;
            try { idx = c.dequeueOutputBuffer(bi, timeoutUs); } catch (IllegalStateException e) { return false; }
            if (idx == MediaCodec.INFO_TRY_AGAIN_LATER) return true;
            if (idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                synchronized (lock) {
                    int t = muxer.addTrack(c.getOutputFormat());
                    if (video) vTrack = t; else aTrack = t;
                    if (vTrack >= 0 && (aTrack >= 0 || !withAudio) && !muxing) { muxer.start(); muxing = true; flushPending(); }
                }
                continue;
            }
            if (idx < 0) continue;
            ByteBuffer out = c.getOutputBuffer(idx);
            if ((bi.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) bi.size = 0;
            if (bi.size > 0 && video && (bi.flags & MediaCodec.BUFFER_FLAG_KEY_FRAME) == 0 && isIdr(out, bi)) {
                bi.flags |= MediaCodec.BUFFER_FLAG_KEY_FRAME;
            }
            if (bi.size > 0) {
                synchronized (lock) {
                    if (muxing) {
                        out.position(bi.offset);
                        out.limit(bi.offset + bi.size);
                        muxer.writeSampleData(video ? vTrack : aTrack, out, bi);
                    } else {
                        // the other track's format is not known yet: keep the sample for later
                        byte[] copy = new byte[bi.size];
                        out.position(bi.offset);
                        out.limit(bi.offset + bi.size);
                        out.get(copy);
                        MediaCodec.BufferInfo ci = new MediaCodec.BufferInfo();
                        ci.set(0, bi.size, bi.presentationTimeUs, bi.flags);
                        pending.add(new Object[]{video, copy, ci});
                    }
                }
            }
            c.releaseOutputBuffer(idx, false);
            if ((bi.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) return false;
        }
    }

    private void flushPending() {
        for (Object[] p : pending) {
            muxer.writeSampleData((Boolean) p[0] ? vTrack : aTrack, ByteBuffer.wrap((byte[]) p[1]), (MediaCodec.BufferInfo) p[2]);
        }
        pending.clear();
    }

    /** The software AVC encoder does not flag key frames, so detect IDR / SPS / PPS NAL units. */
    private static boolean isIdr(ByteBuffer b, MediaCodec.BufferInfo bi) {
        int o = bi.offset, end = bi.offset + bi.size - 4;
        for (int i = o; i < end; i++) {
            if (b.get(i) == 0 && b.get(i + 1) == 0 && b.get(i + 2) == 1) {
                int nal = b.get(i + 3) & 0x1F;
                if (nal == 5) return true;
                i += 3;
            }
        }
        return false;
    }

    /** Stops both encoders and finalises the file. @return true if a playable file was produced. */
    boolean stop() {
        boolean ok = muxing;
        running = false;
        try {
            int idx = venc.dequeueInputBuffer(200000);
            if (idx >= 0) venc.queueInputBuffer(idx, 0, 0, (System.nanoTime() - baseNs) / 1000, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
        } catch (Exception ignored) { }
        try { if (aThread != null) aThread.join(3000); } catch (InterruptedException ignored) { }
        try { vThread.join(3000); } catch (InterruptedException ignored) { }
        ok = ok && muxing;
        try { if (audio != null) { audio.stop(); audio.release(); } } catch (Exception ignored) { }
        try { venc.stop(); venc.release(); } catch (Exception ignored) { }
        try { if (aenc != null) { aenc.stop(); aenc.release(); } } catch (Exception ignored) { }
        try { synchronized (lock) { if (muxing) muxer.stop(); muxer.release(); } } catch (Exception e) { Log.e("VideoRecorder", "muxer stop failed", e); ok = false; }
        Log.d("VideoRecorder", "stop ok=" + ok + " muxing=" + muxing);
        return ok;
    }
}
