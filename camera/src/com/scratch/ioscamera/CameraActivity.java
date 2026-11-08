package com.scratch.ioscamera;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.hardware.Camera;
import android.media.MediaScannerConnection;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.SystemClock;
import android.provider.MediaStore;
import android.view.*;
import android.widget.*;

import java.io.*;
import java.text.SimpleDateFormat;
import java.util.*;

/** Minimal flat camera built on the legacy Camera API (the device HAL is v1). */
public class CameraActivity extends Activity implements SurfaceHolder.Callback {
    private static final int BLUE = 0xFF2E9CF3;
    /** Video goes through VideoRecorder (software codecs): the hardware H264 encoder cannot start here. */
    private static final boolean VIDEO_ENABLED = true;
    private static final int FLASH_OFF = 0, FLASH_AUTO = 1, FLASH_ON = 2;

    private Camera camera;
    private int dispOrient;
    private int timerSec;          // 0 = off, 3 or 10
    private boolean gridOn;
    private IconView timerBtn, gridBtn;
    private View gridView;
    private TextView countdown;
    private boolean counting;
    private boolean frontCam;
    private int zoomIdx;
    private TextView zoomLabel;
    private View focusRing;
    private final Handler uiH = new Handler();
    private int cameraId = 0;
    private int flashMode = FLASH_OFF;
    private boolean surfaceReady, busy;
    private SurfaceView surface;
    private IconView flashBtn, flipBtn;
    private ImageView thumb;
    private View shutterFlash;
    private File lastFile;
    private Uri outputUri;
    private boolean returnResult;
    private float d;
    private int mode;                 // 0 photo, 1 video
    private boolean recording, lastIsVideo;
    private VideoRecorder vrec;
    private File videoFile;
    private long recStart;
    private TextView tabPhoto, tabVideo, timer;
    private ShutterView shutterView;
    private final Handler handler = new Handler();
    private final Runnable tick = new Runnable() {
        @Override public void run() {
            if (!recording) return;
            long s = (SystemClock.elapsedRealtime() - recStart) / 1000;
            timer.setText(String.format(Locale.US, "%02d:%02d", s / 60, s % 60));
            handler.postDelayed(this, 500);
        }
    };

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        d = getResources().getDisplayMetrics().density;
        Intent in = getIntent();
        returnResult = in != null && MediaStore.ACTION_IMAGE_CAPTURE.equals(in.getAction());
        if (returnResult) outputUri = in.getParcelableExtra(MediaStore.EXTRA_OUTPUT);
        if (VIDEO_ENABLED && in != null && "android.media.action.VIDEO_CAMERA".equals(in.getAction())) mode = 1;

        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        int topH = (int) (48 * d);
        int prevH = w * 4 / 3;
        int botH = Math.max((int) (72 * d), h - topH - prevH);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        surface = new SurfaceView(this);
        surface.getHolder().addCallback(this);
        root.addView(surface, new FrameLayout.LayoutParams(w, prevH, Gravity.TOP) {{ topMargin = topH; }});

        shutterFlash = new View(this);
        shutterFlash.setBackgroundColor(Color.BLACK);
        shutterFlash.setAlpha(0f);
        root.addView(shutterFlash, new FrameLayout.LayoutParams(w, prevH, Gravity.TOP) {{ topMargin = topH; }});

        // top bar
        flashBtn = new IconView(this, IconView.FLASH);
        flashBtn.setOnClickListener(v -> { flashMode = (flashMode + 1) % 3; applyFlash(); });
        FrameLayout.LayoutParams fl = new FrameLayout.LayoutParams((int) (56 * d), topH, Gravity.TOP | Gravity.LEFT);
        fl.leftMargin = (int) (8 * d);
        root.addView(flashBtn, fl);

        flipBtn = new IconView(this, IconView.FLIP);
        flipBtn.setOnClickListener(v -> switchCamera());
        FrameLayout.LayoutParams fp = new FrameLayout.LayoutParams((int) (56 * d), topH, Gravity.TOP | Gravity.RIGHT);
        fp.rightMargin = (int) (8 * d);
        root.addView(flipBtn, fp);

        timerBtn = new IconView(this, IconView.TIMER);
        timerBtn.setOnClickListener(v -> { timerSec = timerSec == 0 ? 3 : timerSec == 3 ? 10 : 0; timerBtn.setState(timerSec); });
        FrameLayout.LayoutParams tl = new FrameLayout.LayoutParams((int) (44 * d), topH, Gravity.TOP | Gravity.LEFT);
        tl.leftMargin = (int) (52 * d);
        root.addView(timerBtn, tl);

        gridOn = getSharedPreferences("cam", MODE_PRIVATE).getBoolean("grid", false);
        gridBtn = new IconView(this, IconView.GRID);
        gridBtn.setState(gridOn ? 1 : 0);
        FrameLayout.LayoutParams gl = new FrameLayout.LayoutParams((int) (44 * d), topH, Gravity.TOP | Gravity.RIGHT);
        gl.rightMargin = (int) (64 * d);
        root.addView(gridBtn, gl);
        gridView = new View(this) {
            private final Paint gp = new Paint();
            @Override protected void onDraw(Canvas c) {
                gp.setColor(0x66FFFFFF);
                gp.setStrokeWidth(Math.max(1f, d));
                int gw = getWidth(), gh = getHeight();
                for (int i = 1; i <= 2; i++) { c.drawLine(gw * i / 3f, 0, gw * i / 3f, gh, gp); c.drawLine(0, gh * i / 3f, gw, gh * i / 3f, gp); }
            }
        };
        gridView.setVisibility(gridOn ? View.VISIBLE : View.GONE);
        root.addView(gridView, new FrameLayout.LayoutParams(w, prevH, Gravity.TOP) {{ topMargin = topH; }});
        gridBtn.setOnClickListener(v -> {
            gridOn = !gridOn;
            gridBtn.setState(gridOn ? 1 : 0);
            gridView.setVisibility(gridOn ? View.VISIBLE : View.GONE);
            getSharedPreferences("cam", MODE_PRIVATE).edit().putBoolean("grid", gridOn).apply();
        });

        countdown = new TextView(this);
        countdown.setTextColor(Color.WHITE);
        countdown.setTextSize(96);
        countdown.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        countdown.setShadowLayer(8f, 0, 2, 0x80000000);
        countdown.setGravity(Gravity.CENTER);
        countdown.setVisibility(View.GONE);
        root.addView(countdown, new FrameLayout.LayoutParams(w, prevH, Gravity.TOP) {{ topMargin = topH; }});

        // mode tabs (top centre) and recording timer
        LinearLayout tabs = new LinearLayout(this);
        tabs.setGravity(Gravity.CENTER);
        tabPhoto = tab("FOTO", 0);
        tabVideo = tab("VÍDEO", 1);
        tabs.addView(tabPhoto);
        if (VIDEO_ENABLED) tabs.addView(tabVideo);
        root.addView(tabs, new FrameLayout.LayoutParams(w, topH, Gravity.TOP));
        timer = new TextView(this);
        timer.setTextColor(Color.WHITE);
        timer.setTextSize(16);
        timer.setGravity(Gravity.CENTER);
        timer.setBackgroundColor(0xFFFF3B30);
        timer.setVisibility(View.GONE);
        timer.setPadding((int) (10 * d), (int) (3 * d), (int) (10 * d), (int) (3 * d));
        root.addView(timer, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.CENTER_HORIZONTAL) {{ topMargin = topH + (int) (8 * d); }});
        updateTabs();

        // bottom bar
        FrameLayout bar = new FrameLayout(this);
        bar.setBackgroundColor(Color.BLACK);
        root.addView(bar, new FrameLayout.LayoutParams(w, botH, Gravity.BOTTOM));

        ShutterView shutter = shutterView = new ShutterView(this);
        int sd = (int) (64 * d);
        bar.addView(shutter, new FrameLayout.LayoutParams(sd, sd, Gravity.CENTER));
        shutter.setOnClickListener(v -> { if (mode == 1) toggleRecord(); else shootWithTimer(); });

        thumb = new ImageView(this);
        thumb.setScaleType(ImageView.ScaleType.CENTER_CROP);
        thumb.setBackgroundColor(0xFF222222);
        int td = (int) (44 * d);
        FrameLayout.LayoutParams tp = new FrameLayout.LayoutParams(td, td, Gravity.CENTER_VERTICAL | Gravity.LEFT);
        tp.leftMargin = (int) (24 * d);
        bar.addView(thumb, tp);
        thumb.setOnClickListener(v -> openLast());

        zoomLabel = new TextView(this);
        zoomLabel.setTextColor(Color.WHITE);
        zoomLabel.setTextSize(15);
        zoomLabel.setGravity(Gravity.CENTER);
        zoomLabel.setPadding((int) (12 * d), (int) (4 * d), (int) (12 * d), (int) (4 * d));
        GradientDrawable zb = new GradientDrawable();
        zb.setColor(0x80000000);
        zb.setCornerRadius(16 * d);
        zoomLabel.setBackground(zb);
        zoomLabel.setVisibility(View.GONE);
        root.addView(zoomLabel, new FrameLayout.LayoutParams(-2, -2, Gravity.TOP | Gravity.CENTER_HORIZONTAL) {{ topMargin = topH + prevH - (int) (44 * d); }});

        focusRing = new View(this);
        GradientDrawable fr = new GradientDrawable();
        fr.setShape(GradientDrawable.OVAL);
        fr.setColor(0x00000000);
        fr.setStroke((int) Math.max(2, 2 * d), 0xFFFFD60A);
        focusRing.setBackground(fr);
        focusRing.setVisibility(View.GONE);
        root.addView(focusRing, new FrameLayout.LayoutParams((int) (64 * d), (int) (64 * d), Gravity.TOP | Gravity.LEFT));

        final ScaleGestureDetector sgd = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            private float ratio;
            @Override public boolean onScaleBegin(ScaleGestureDetector det) { ratio = currentRatio(); return camera != null; }
            @Override public boolean onScale(ScaleGestureDetector det) { ratio *= det.getScaleFactor(); setZoomRatio(ratio); return true; }
        });
        final GestureDetector gd = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override public boolean onSingleTapUp(MotionEvent e) {
                if (e.getY() > topH && e.getY() < topH + prevH) focusAt(e.getX(), e.getY() - topH, w, prevH, (int) e.getX(), (int) e.getY());
                return true;
            }
        });
        root.setOnTouchListener((v, e) -> { sgd.onTouchEvent(e); if (!sgd.isInProgress()) gd.onTouchEvent(e); return true; });

        setContentView(root);
    }

    private float currentRatio() {
        try {
            List<Integer> r = camera.getParameters().getZoomRatios();
            return r == null ? 100f : r.get(zoomIdx);
        } catch (Exception e) { return 100f; }
    }

    /** Pinch zoom: pick the closest hardware zoom step to the requested ratio (percent). */
    private void setZoomRatio(float ratio) {
        if (camera == null || busy) return;
        try {
            Camera.Parameters p = camera.getParameters();
            if (!p.isZoomSupported()) return;
            List<Integer> r = p.getZoomRatios();
            int best = 0;
            for (int i = 0; i < r.size(); i++) if (Math.abs(r.get(i) - ratio) < Math.abs(r.get(best) - ratio)) best = i;
            if (best == zoomIdx) return;
            zoomIdx = best;
            p.setZoom(best);
            camera.setParameters(p);
            zoomLabel.setText(String.format(Locale.US, "%.1f×", r.get(best) / 100f));
            zoomLabel.setVisibility(View.VISIBLE);
            uiH.removeCallbacks(hideZoom);
            uiH.postDelayed(hideZoom, 1200);
        } catch (Exception ignored) { }
    }

    private final Runnable hideZoom = () -> { if (zoomLabel != null) zoomLabel.setVisibility(View.GONE); };

    /** Tap to focus: map the tap into the camera's -1000..1000 space (see Camera.Parameters#setFocusAreas). */
    private void focusAt(float x, float y, int vw, int vh, int rootX, int rootY) {
        if (camera == null || busy) return;
        try {
            Camera.Parameters p = camera.getParameters();
            if (p.getMaxNumFocusAreas() <= 0) return;
            Matrix m = new Matrix();
            m.setScale(frontCam ? -1 : 1, 1);
            m.postRotate(dispOrient);
            m.postScale(vw / 2000f, vh / 2000f);
            m.postTranslate(vw / 2f, vh / 2f);
            Matrix inv = new Matrix();
            m.invert(inv);
            float[] pt = {x, y};
            inv.mapPoints(pt);
            int cx = (int) pt[0], cy = (int) pt[1], r = 120;
            Rect rect = new Rect(Math.max(-1000, cx - r), Math.max(-1000, cy - r), Math.min(1000, cx + r), Math.min(1000, cy + r));
            List<String> fm = p.getSupportedFocusModes();
            if (fm == null || !fm.contains(Camera.Parameters.FOCUS_MODE_AUTO)) return;
            p.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
            p.setFocusAreas(Collections.singletonList(new Camera.Area(rect, 1000)));
            camera.cancelAutoFocus();
            camera.setParameters(p);
            camera.autoFocus((ok, c) -> {
                try {
                    Camera.Parameters q = c.getParameters();
                    List<String> f2 = q.getSupportedFocusModes();
                    if (f2 != null && f2.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) q.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
                    q.setFocusAreas(null);
                    c.setParameters(q);
                } catch (Exception ignored) { }
            });
            FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) focusRing.getLayoutParams();
            lp.leftMargin = rootX - lp.width / 2; lp.topMargin = rootY - lp.height / 2;
            focusRing.setLayoutParams(lp);
            focusRing.setVisibility(View.VISIBLE);
            focusRing.setAlpha(1f);
            focusRing.setScaleX(1.4f); focusRing.setScaleY(1.4f);
            focusRing.animate().scaleX(1f).scaleY(1f).setDuration(180).withEndAction(() ->
                focusRing.animate().alpha(0f).setStartDelay(700).setDuration(300).withEndAction(() -> focusRing.setVisibility(View.GONE)).start()).start();
        } catch (Exception ignored) { }
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshThumb();
        if (surfaceReady) openCamera();
    }

    private TextView tab(String t, int m) {
        TextView v = new TextView(this);
        v.setText(t);
        v.setTextSize(13);
        v.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        v.setPadding((int) (14 * d), (int) (8 * d), (int) (14 * d), (int) (8 * d));
        v.setOnClickListener(x -> { if (!recording) { mode = m; updateTabs(); } });
        return v;
    }

    private void updateTabs() {
        tabPhoto.setTextColor(mode == 0 ? 0xFFFFD60A : Color.WHITE);
        tabVideo.setTextColor(mode == 1 ? 0xFFFFD60A : Color.WHITE);
        if (shutterView != null) { shutterView.video = mode == 1; shutterView.invalidate(); }
    }

    private static final int VW = 320, VH = 240;

    private void toggleRecord() {
        if (recording) { stopRecording(); return; }
        if (camera == null || busy) return;
        try {
            Camera.CameraInfo info = new Camera.CameraInfo();
            Camera.getCameraInfo(cameraId, info);
            camera.stopPreview();
            Camera.Parameters vp = camera.getParameters();
            vp.setPreviewSize(VW, VH);
            camera.setParameters(vp);
            File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), "Camera");
            dir.mkdirs();
            videoFile = new File(dir, "VID_" + new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date()) + ".mp4");
            vrec = new VideoRecorder(videoFile.getAbsolutePath(), VW, VH, info.orientation, true);
            int size = VW * VH * 3 / 2;
            camera.addCallbackBuffer(new byte[size]);
            camera.addCallbackBuffer(new byte[size]);
            camera.setPreviewCallbackWithBuffer((data, c) -> {
                if (vrec != null) vrec.onFrame(data);
                c.addCallbackBuffer(data);
            });
            camera.startPreview();
            vrec.start();
            recording = true;
            recStart = SystemClock.elapsedRealtime();
            timer.setText("00:00");
            timer.setVisibility(View.VISIBLE);
            shutterView.recording = true;
            shutterView.invalidate();
            handler.post(tick);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo grabar", Toast.LENGTH_SHORT).show();
            if (vrec != null) { vrec.stop(); vrec = null; }
            if (videoFile != null) videoFile.delete();
            releaseCamera();
            if (surfaceReady) openCamera();
        }
    }

    private void stopRecording() {
        recording = false;
        if (camera != null) camera.setPreviewCallbackWithBuffer(null);
        boolean ok = vrec != null && vrec.stop();
        vrec = null;
        timer.setVisibility(View.GONE);
        shutterView.recording = false;
        shutterView.invalidate();
        releaseCamera();
        if (surfaceReady) openCamera();
        if (ok && videoFile != null) {
            lastFile = videoFile;
            lastIsVideo = true;
            MediaScannerConnection.scanFile(this, new String[]{videoFile.getAbsolutePath()}, new String[]{"video/mp4"}, null);
            setThumb(videoFile);
        } else if (videoFile != null) {
            videoFile.delete();
            Toast.makeText(this, "La grabación falló", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    protected void onPause() {
        cancelCountdown();
        if (recording) stopRecording();
        releaseCamera();
        super.onPause();
    }

    @Override public void surfaceCreated(SurfaceHolder h) { surfaceReady = true; openCamera(); }
    @Override public void surfaceChanged(SurfaceHolder h, int f, int w, int hh) {}
    @Override public void surfaceDestroyed(SurfaceHolder h) { surfaceReady = false; releaseCamera(); }

    private void openCamera() {
        if (camera != null) return;
        try {
            camera = Camera.open(cameraId);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo abrir la cámara", Toast.LENGTH_SHORT).show();
            camera = null;
            return;
        }
        try {
            Camera.CameraInfo info = new Camera.CameraInfo();
            Camera.getCameraInfo(cameraId, info);
            int disp = info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT
                    ? (360 - info.orientation) % 360 : info.orientation;
            camera.setDisplayOrientation(disp);
            dispOrient = disp;
            frontCam = info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT;
            zoomIdx = 0;
            Camera.Parameters p = camera.getParameters();
            Camera.Size ps = pickSize(p.getSupportedPreviewSizes(), 1000, 0);
            if (ps != null) p.setPreviewSize(ps.width, ps.height);
            Camera.Size pic = pickSize(p.getSupportedPictureSizes(), 100000, 3200000);
            if (pic != null) p.setPictureSize(pic.width, pic.height);
            p.setJpegQuality(90);
            p.setRotation(info.orientation);
            List<String> fm = p.getSupportedFocusModes();
            if (fm != null && fm.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE))
                p.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
            camera.setParameters(p);
            camera.setPreviewDisplay(surface.getHolder());
            camera.startPreview();
            applyFlash();
        } catch (Exception e) {
            releaseCamera();
            Toast.makeText(this, "Error de cámara", Toast.LENGTH_SHORT).show();
        }
    }

    /** Largest 4:3 size within maxW (width) and maxPixels (0 = unlimited). */
    private Camera.Size pickSize(List<Camera.Size> sizes, int maxW, int maxPixels) {
        Camera.Size best = null;
        for (Camera.Size s : sizes) {
            if (s.width * 3 != s.height * 4) continue;
            if (s.width > maxW) continue;
            if (maxPixels > 0 && s.width * s.height > maxPixels) continue;
            if (best == null || s.width > best.width) best = s;
        }
        return best != null ? best : sizes.get(0);
    }

    private void releaseCamera() {
        if (camera != null) {
            try { camera.stopPreview(); } catch (Exception ignored) {}
            camera.release();
            camera = null;
        }
        busy = false;
    }

    private void switchCamera() {
        if (Camera.getNumberOfCameras() < 2) return;
        releaseCamera();
        cameraId = 1 - cameraId;
        openCamera();
    }

    private void applyFlash() {
        flashBtn.setState(flashMode);
        if (camera == null) return;
        try {
            Camera.Parameters p = camera.getParameters();
            List<String> modes = p.getSupportedFlashModes();
            if (modes == null) { flashBtn.setVisibility(View.INVISIBLE); return; }
            flashBtn.setVisibility(View.VISIBLE);
            String m = flashMode == FLASH_ON ? Camera.Parameters.FLASH_MODE_ON
                    : flashMode == FLASH_AUTO ? Camera.Parameters.FLASH_MODE_AUTO
                    : Camera.Parameters.FLASH_MODE_OFF;
            if (modes.contains(m)) { p.setFlashMode(m); camera.setParameters(p); }
        } catch (Exception ignored) {}
    }

    private int tickLeft;
    private final Runnable tickRun = new Runnable() {
        @Override public void run() {
            if (!counting) return;
            if (tickLeft > 0) {
                countdown.setText(String.valueOf(tickLeft));
                countdown.setVisibility(View.VISIBLE);
                tickLeft--;
                uiH.postDelayed(this, 1000);
            } else {
                counting = false;
                countdown.setVisibility(View.GONE);
                capture();
            }
        }
    };

    /** Photo with the self-timer: tapping the shutter again during the countdown cancels it. */
    private void shootWithTimer() {
        if (counting) { cancelCountdown(); return; }
        if (timerSec == 0) { capture(); return; }
        counting = true;
        tickLeft = timerSec;
        countdown.setVisibility(View.GONE);
        uiH.post(tickRun);
    }

    private void cancelCountdown() {
        counting = false;
        uiH.removeCallbacks(tickRun);
        if (countdown != null) countdown.setVisibility(View.GONE);
    }

    private void capture() {
        if (camera == null || busy) return;
        busy = true;
        Camera.AutoFocusCallback shoot = (ok, c) -> {
            if (camera == null) return;
            try {
                camera.takePicture(() -> {
                    shutterFlash.setAlpha(1f);
                    shutterFlash.animate().alpha(0f).setDuration(150).start();
                }, null, this::onJpeg);
            } catch (Exception e) { busy = false; }
        };
        try {
            String fm = camera.getParameters().getFocusMode();
            if (Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE.equals(fm) || Camera.Parameters.FOCUS_MODE_AUTO.equals(fm)) {
                camera.autoFocus(shoot);
            } else {
                shoot.onAutoFocus(true, camera);
            }
        } catch (Exception e) { busy = false; }
    }

    private void onJpeg(byte[] data, Camera c) {
        try {
            if (returnResult) {
                OutputStream os = outputUri != null ? getContentResolver().openOutputStream(outputUri) : null;
                if (os == null) {
                    File f = new File(getExternalCacheDir(), "capture.jpg");
                    os = new FileOutputStream(f);
                }
                os.write(data);
                os.close();
                setResult(RESULT_OK);
                finish();
                return;
            }
            File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), "Camera");
            dir.mkdirs();
            File f = new File(dir, "IMG_" + new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date()) + ".jpg");
            FileOutputStream fos = new FileOutputStream(f);
            fos.write(data);
            fos.close();
            lastFile = f;
            lastIsVideo = false;
            MediaScannerConnection.scanFile(this, new String[]{f.getAbsolutePath()}, new String[]{"image/jpeg"}, null);
            setThumb(f);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo guardar la foto", Toast.LENGTH_SHORT).show();
        }
        try { c.startPreview(); } catch (Exception ignored) {}
        busy = false;
    }

    private void refreshThumb() {
        File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), "Camera");
        File[] files = dir.listFiles((x, n) -> { String l = n.toLowerCase(Locale.US); return l.endsWith(".jpg") || l.endsWith(".mp4"); });
        if (files == null || files.length == 0) return;
        File newest = files[0];
        for (File f : files) if (f.lastModified() > newest.lastModified()) newest = f;
        lastFile = newest;
        lastIsVideo = newest.getName().endsWith(".mp4");
        setThumb(newest);
    }

    private void setThumb(File f) {
        Bitmap bm;
        if (f.getName().endsWith(".mp4")) {
            bm = ThumbnailUtils.createVideoThumbnail(f.getAbsolutePath(), MediaStore.Video.Thumbnails.MICRO_KIND);
        } else {
            BitmapFactory.Options o = new BitmapFactory.Options();
            o.inSampleSize = 16;
            bm = BitmapFactory.decodeFile(f.getAbsolutePath(), o);
        }
        if (bm != null) thumb.setImageBitmap(bm);
    }

    private void openLast() {
        if (lastFile == null) return;
        Intent i = new Intent(Intent.ACTION_VIEW);
        i.setDataAndType(Uri.fromFile(lastFile), lastIsVideo ? "video/mp4" : "image/jpeg");
        try { startActivity(i); } catch (Exception ignored) {}
    }

    /** Round shutter: white ring with an inner white disc that shrinks on press. */
    private static class ShutterView extends View {
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        boolean video, recording;
        ShutterView(Context c) { super(c); setClickable(true); }
        @Override protected void onDraw(Canvas cv) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f, r = getWidth() / 2f;
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(r * 0.10f);
            p.setColor(Color.WHITE);
            cv.drawCircle(cx, cy, r * 0.93f, p);
            p.setStyle(Paint.Style.FILL);
            if (recording) {
                p.setColor(0xFFFF3B30);
                cv.drawRoundRect(new RectF(cx - r * 0.38f, cy - r * 0.38f, cx + r * 0.38f, cy + r * 0.38f), r * 0.1f, r * 0.1f, p);
                return;
            }
            if (video) p.setColor(0xFFFF3B30);
            cv.drawCircle(cx, cy, isPressed() ? r * 0.66f : r * 0.76f, p);
        }
        @Override public void setPressed(boolean pr) { super.setPressed(pr); invalidate(); }
    }

    /** Thin line icons drawn in code. */
    private static class IconView extends View {
        static final int FLASH = 0, FLIP = 1, TIMER = 2, GRID = 3;
        private final int kind;
        private int state;
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        IconView(Context c, int kind) { super(c); this.kind = kind; setClickable(true); }
        void setState(int s) { state = s; invalidate(); }
        @Override protected void onDraw(Canvas cv) {
            float w = getWidth(), h = getHeight(), u = Math.min(w, h) / 48f;
            float cx = w / 2f, cy = h / 2f;
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(2f * u);
            p.setStrokeCap(Paint.Cap.ROUND);
            p.setStrokeJoin(Paint.Join.ROUND);
            if (kind == FLASH) {
                p.setColor(state == FLASH_ON ? 0xFFFFD60A : Color.WHITE);
                Path b = new Path();
                b.moveTo(cx + 3 * u, cy - 11 * u);
                b.lineTo(cx - 5 * u, cy + 2 * u);
                b.lineTo(cx, cy + 2 * u);
                b.lineTo(cx - 3 * u, cy + 11 * u);
                b.lineTo(cx + 5 * u, cy - 2 * u);
                b.lineTo(cx, cy - 2 * u);
                b.close();
                cv.drawPath(b, p);
                if (state == FLASH_OFF) cv.drawLine(cx - 9 * u, cy - 11 * u, cx + 9 * u, cy + 11 * u, p);
                if (state == FLASH_AUTO) {
                    p.setStyle(Paint.Style.FILL);
                    p.setTextSize(9 * u);
                    cv.drawText("A", cx + 6 * u, cy - 6 * u, p);
                }
            } else if (kind == TIMER) {
                p.setColor(state != 0 ? 0xFFFFD60A : Color.WHITE);
                cv.drawCircle(cx, cy + 2 * u, 10 * u, p);
                cv.drawLine(cx - 3 * u, cy - 11 * u, cx + 3 * u, cy - 11 * u, p);
                cv.drawLine(cx, cy - 11 * u, cx, cy - 8 * u, p);
                if (state == 0) cv.drawLine(cx, cy + 2 * u, cx + 5 * u, cy - 2 * u, p);
                else {
                    p.setStyle(Paint.Style.FILL);
                    p.setTextSize(state >= 10 ? 9 * u : 11 * u);
                    p.setTextAlign(Paint.Align.CENTER);
                    cv.drawText(String.valueOf(state), cx, cy + 6 * u, p);
                    p.setTextAlign(Paint.Align.LEFT);
                }
            } else if (kind == GRID) {
                p.setColor(state != 0 ? 0xFFFFD60A : Color.WHITE);
                p.setStrokeWidth(1.6f * u);
                RectF r = new RectF(cx - 11 * u, cy - 11 * u, cx + 11 * u, cy + 11 * u);
                cv.drawRoundRect(r, 3 * u, 3 * u, p);
                cv.drawLine(cx - 3.7f * u, cy - 11 * u, cx - 3.7f * u, cy + 11 * u, p);
                cv.drawLine(cx + 3.7f * u, cy - 11 * u, cx + 3.7f * u, cy + 11 * u, p);
                cv.drawLine(cx - 11 * u, cy - 3.7f * u, cx + 11 * u, cy - 3.7f * u, p);
                cv.drawLine(cx - 11 * u, cy + 3.7f * u, cx + 11 * u, cy + 3.7f * u, p);
            } else {
                p.setColor(Color.WHITE);
                RectF body = new RectF(cx - 13 * u, cy - 8 * u, cx + 13 * u, cy + 10 * u);
                cv.drawRoundRect(body, 4 * u, 4 * u, p);
                cv.drawLine(cx - 5 * u, cy - 8 * u, cx - 3 * u, cy - 12 * u, p);
                cv.drawLine(cx - 3 * u, cy - 12 * u, cx + 3 * u, cy - 12 * u, p);
                cv.drawLine(cx + 3 * u, cy - 12 * u, cx + 5 * u, cy - 8 * u, p);
                cv.drawArc(new RectF(cx - 6 * u, cy - 5 * u, cx + 6 * u, cy + 7 * u), 200, 250, false, p);
            }
        }
    }

    /** Aurora exit transition (res/anim/app_exit): soft zoom-out and fade instead of the ROM default. */
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
