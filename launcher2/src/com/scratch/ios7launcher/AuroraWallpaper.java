package com.scratch.ios7launcher;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.hardware.Sensor;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import android.opengl.GLUtils;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.SurfaceHolder;

/**
 * Live wallpaper "Aurora": rendered on its own thread at ~15 fps while visible, paused when the screen is off.
 * Follows the home pages (offsets) and the tilt of the phone (accelerometer), and colours itself from the clock and
 * the cached weather. Publishes each frame to {@link AuroraField#front} so the launcher glass can sample it.
 */
public class AuroraWallpaper extends WallpaperService {
    private static final boolean PERF = new java.io.File("/sdcard/aurora_perf").exists();   // `touch /sdcard/aurora_perf` to log frame times (tag AuroraPerf)
    @Override public Engine onCreateEngine() { return new AuroraEngine(); }

    private final class AuroraEngine extends Engine implements SensorEventListener {
        private HandlerThread thread;
        private Handler bg;
        private final Handler ui = new Handler(Looper.getMainLooper());
        private volatile boolean visible;
        private SurfaceHolder holder;
        private int sw = 480, sh = 800;
        private volatile float pan = 0.5f;
        private float tiltX, tiltY;
        private final Paint paint = new Paint(Paint.FILTER_BITMAP_FLAG);
        private final Rect src = new Rect(0, 0, AuroraField.W, AuroraField.H), dst = new Rect();
        private final int[] px = new int[AuroraField.W * AuroraField.H], pal = new int[5];
        private Bitmap a, b;
        private boolean flip;
        private long t0 = SystemClock.uptimeMillis(), weatherAt;
        private String weatherKind;
        private SensorManager sm;
        private long batAt; private int interval = 66;
        private int statN; private long statSum, tRender, tSet, tLock, tDraw;

        @Override public void onCreate(SurfaceHolder h) {
            super.onCreate(h);
            holder = h;
            a = Bitmap.createBitmap(AuroraField.W, AuroraField.H, Bitmap.Config.ARGB_8888);
            b = Bitmap.createBitmap(AuroraField.W, AuroraField.H, Bitmap.Config.ARGB_8888);
            sm = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
            thread = new HandlerThread("aurora");
            thread.start();
            bg = new Handler(thread.getLooper());
        }

        @Override public void onSurfaceChanged(SurfaceHolder h, int f, int w, int hh) { super.onSurfaceChanged(h, f, w, hh); sw = w; sh = hh; dst.set(0, 0, w, hh); }

        @Override public void onOffsetsChanged(float x, float y, float xs, float ys, int xp, int yp) { pan = x; }

        @Override public void onVisibilityChanged(boolean v) {
            visible = v;
            bg.removeCallbacks(frame);
            if (sm != null) sm.unregisterListener(this);
            if (v) {
                Sensor acc = sm == null ? null : sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
                if (acc != null) sm.registerListener(this, acc, SensorManager.SENSOR_DELAY_UI);
                bg.post(frame);
            }
        }

        @Override public void onDestroy() {
            visible = false;
            if (sm != null) sm.unregisterListener(this);
            if (thread != null) thread.quit();
            super.onDestroy();
        }

        @Override public void onSensorChanged(SensorEvent e) {
            tiltX += (Math.max(-1f, Math.min(1f, e.values[0] / 9.81f)) - tiltX) * 0.08f;
            tiltY += (Math.max(-1f, Math.min(1f, e.values[1] / 9.81f)) - tiltY) * 0.08f;
        }
        @Override public void onAccuracyChanged(Sensor s, int acc) { }


        // ---- GPU presentation: the 80x134 field is a texture, GL_LINEAR does the stretching for free ----
        private EGLDisplay dpy; private EGLSurface esurf; private EGLContext ectx;
        private int prog, tex, aPos, aTex, uTex;
        private boolean gl, texReady;
        private volatile boolean glTried;
        private FloatBuffer quad;

        private void initGL() {
            try {
                dpy = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
                int[] v = new int[2];
                EGL14.eglInitialize(dpy, v, 0, v, 1);
                int[] cfgAttr = {EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_NONE};
                EGLConfig[] cfgs = new EGLConfig[1]; int[] n = new int[1];
                EGL14.eglChooseConfig(dpy, cfgAttr, 0, cfgs, 0, 1, n, 0);
                if (n[0] < 1) throw new RuntimeException("no EGL config");
                ectx = EGL14.eglCreateContext(dpy, cfgs[0], EGL14.EGL_NO_CONTEXT, new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE}, 0);
                esurf = EGL14.eglCreateWindowSurface(dpy, cfgs[0], holder.getSurface(), new int[]{EGL14.EGL_NONE}, 0);
                if (!EGL14.eglMakeCurrent(dpy, esurf, esurf, ectx)) throw new RuntimeException("eglMakeCurrent");
                int vs = shader(GLES20.GL_VERTEX_SHADER, "attribute vec2 p; attribute vec2 t; varying vec2 v; void main(){ gl_Position=vec4(p,0.,1.); v=t; }");
                int fs = shader(GLES20.GL_FRAGMENT_SHADER, "precision mediump float; varying vec2 v; uniform sampler2D s; void main(){ gl_FragColor=texture2D(s,v); }");
                prog = GLES20.glCreateProgram();
                GLES20.glAttachShader(prog, vs); GLES20.glAttachShader(prog, fs); GLES20.glLinkProgram(prog);
                aPos = GLES20.glGetAttribLocation(prog, "p"); aTex = GLES20.glGetAttribLocation(prog, "t"); uTex = GLES20.glGetUniformLocation(prog, "s");
                int[] t = new int[1]; GLES20.glGenTextures(1, t, 0); tex = t[0];
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
                float[] q = {-1, -1, 0, 1,   1, -1, 1, 1,   -1, 1, 0, 0,   1, 1, 1, 0};
                quad = ByteBuffer.allocateDirect(q.length * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();
                quad.put(q).position(0);
                texReady = false;
                gl = true;
                glTried = true;
            } catch (Throwable e) {
                android.util.Log.w("AuroraGL", "GL unavailable, using the canvas path", e);
                releaseGL();
                gl = false;
                glTried = true;
            }
        }

        private int shader(int type, String src) {
            int s = GLES20.glCreateShader(type);
            GLES20.glShaderSource(s, src); GLES20.glCompileShader(s);
            int[] ok = new int[1]; GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, ok, 0);
            if (ok[0] == 0) throw new RuntimeException("shader: " + GLES20.glGetShaderInfoLog(s));
            return s;
        }

        private void releaseGL() {
            gl = false;
            try {
                if (dpy != null) {
                    EGL14.eglMakeCurrent(dpy, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
                    if (esurf != null) EGL14.eglDestroySurface(dpy, esurf);
                    if (ectx != null) EGL14.eglDestroyContext(dpy, ectx);
                    EGL14.eglTerminate(dpy);
                }
            } catch (Throwable ignored) { }
            dpy = null; esurf = null; ectx = null;
        }

        private void drawGL(Bitmap bmp) {
            GLES20.glViewport(0, 0, sw, sh);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex);
            if (!texReady) { GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0); texReady = true; }
            else GLUtils.texSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, bmp);
            GLES20.glUseProgram(prog);
            quad.position(0); GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 16, quad); GLES20.glEnableVertexAttribArray(aPos);
            quad.position(2); GLES20.glVertexAttribPointer(aTex, 2, GLES20.GL_FLOAT, false, 16, quad); GLES20.glEnableVertexAttribArray(aTex);
            GLES20.glUniform1i(uTex, 0);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);
            EGL14.eglSwapBuffers(dpy, esurf);
        }

        @Override public void onSurfaceCreated(SurfaceHolder h) { super.onSurfaceCreated(h); holder = h; if (bg != null) bg.post(() -> initGL()); }
        @Override public void onSurfaceDestroyed(SurfaceHolder h) { super.onSurfaceDestroyed(h); glTried = false; if (bg != null) bg.post(() -> releaseGL()); }

        private final Runnable frame = new Runnable() {
            @Override public void run() {
                if (!visible) return;
                if (!glTried) { bg.postDelayed(this, 30); return; }
                long start = SystemClock.uptimeMillis();
                if (start - weatherAt > 300000) {
                    weatherAt = start;
                    try {
                        Weather w = Weather.cached(getSharedPreferences("home", Context.MODE_PRIVATE));
                        weatherKind = w.ok && System.currentTimeMillis() - w.ts < 6 * 3600 * 1000L ? w.kind() : null;
                    } catch (Exception e) { weatherKind = null; }
                }
                AuroraField.palette(AuroraField.hourNow(), pal);
                float speed = AuroraField.applyWeather(weatherKind, pal);
                long t1 = SystemClock.uptimeMillis();
                AuroraField.render(px, (start - t0) / 1000f, pan - 0.5f, tiltX, tiltY, pal, speed);
                long t2 = SystemClock.uptimeMillis(); tRender += t2 - t1;
                final Bitmap out = flip ? a : b;
                flip = !flip;
                out.setPixels(px, 0, AuroraField.W, 0, 0, AuroraField.W, AuroraField.H);
                long t3 = SystemClock.uptimeMillis(); tSet += t3 - t2;
                AuroraField.front = out;
                AuroraField.lastFrame = start;
                long t4 = SystemClock.uptimeMillis(), t5;
                if (gl) {
                    try { drawGL(out); } catch (Throwable e) { android.util.Log.w("AuroraGL", "draw failed, falling back", e); releaseGL(); }
                    t5 = SystemClock.uptimeMillis();
                } else {
                    Canvas c = null;
                    try {
                        c = holder.lockCanvas();
                        t4 = SystemClock.uptimeMillis();
                        if (c != null) c.drawBitmap(out, src, dst, paint);
                    } catch (Exception ignored) {
                    } finally {
                        if (c != null) try { holder.unlockCanvasAndPost(c); } catch (Exception ignored) { }
                    }
                    t5 = SystemClock.uptimeMillis();
                }
                tLock += t4 - t3; tDraw += t5 - t4;
                if (AuroraField.launcherVisible) ui.post(Glass::invalidateAll);
                if (start - batAt > 60000) {   // low battery and unplugged: fall to ~6 fps
                    batAt = start;
                    android.content.Intent bi = registerReceiver(null, new android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED));
                    int lvl = bi == null ? 100 : bi.getIntExtra("level", 100) * 100 / Math.max(1, bi.getIntExtra("scale", 100));
                    boolean plugged = bi != null && bi.getIntExtra("plugged", 0) != 0;
                    interval = (lvl < 15 && !plugged) ? 160 : 66;
                    AuroraField.reduced = getSharedPreferences("home", Context.MODE_PRIVATE).getBoolean("aurora_reduced", false);
                }
                long spent = SystemClock.uptimeMillis() - start;
                statN++; statSum += spent;
                if (PERF && statN >= 75) { android.util.Log.d("AuroraPerf", "avg frame " + (statSum / (float) statN) + " ms (render " + (tRender / (float) statN) + ", setPixels " + (tSet / (float) statN) + ", lock " + (tLock / (float) statN) + ", draw " + (tDraw / (float) statN) + ") over " + statN); tRender = 0; tSet = 0; tLock = 0; tDraw = 0; statN = 0; statSum = 0; }
                bg.postDelayed(this, AuroraField.reduced ? 1000 : Math.max(10, interval - spent));
            }
        };
    }
}
