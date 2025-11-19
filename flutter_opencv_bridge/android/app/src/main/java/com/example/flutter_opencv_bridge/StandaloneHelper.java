package com.example.flutter_opencv_bridge;

import android.app.Activity;
import android.util.Log;
import android.view.ViewGroup;
import android.os.SystemClock;
import org.opencv.android.CameraBridgeViewBase;
import org.opencv.android.JavaCamera2View;
import org.opencv.android.OpenCVLoader;
import org.opencv.core.Core;
import org.opencv.core.Mat;
import org.opencv.core.MatOfPoint;
import org.opencv.core.Rect;
import org.opencv.core.Scalar;
import org.opencv.core.Size;
import org.opencv.imgproc.Imgproc;
import java.util.HashMap;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;

import io.flutter.plugin.common.EventChannel;

public class StandaloneHelper implements CameraBridgeViewBase.CvCameraViewListener2 {
    private static final String TAG = "OpenCVBridge";

    private static JavaCamera2View cameraView = null;
    private static EventChannel.EventSink eventSink = null;

    // Detection params
    private static volatile int targetHue = 60;
    private static volatile int hueDelta = 15;
    private static volatile int satMin = 120;
    private static volatile int valMin = 30;
    private static volatile double areaMin = 15000.0;

    // Mats / runtime
    private Mat hsv, mask, mask2, morphed, hierarchy, kernel;
    private List<MatOfPoint> contours;
    private Rect rect = new Rect();
    private boolean previewStarted = false;

    private long t0 = 0L;
    private int fpsCnt = 0, lastFps = 0;
    private long lastEventMs = 0L;

    static {
        boolean ok = OpenCVLoader.initDebug();
        if (!ok) {
            try { System.loadLibrary("opencv_java4"); Log.d(TAG, "Loaded opencv_java4"); }
            catch (Throwable t1) {
                try { System.loadLibrary("opencv_java3"); Log.d(TAG, "Loaded opencv_java3"); }
                catch (Throwable t2) { Log.e(TAG, "Failed to load any OpenCV lib", t2); }
            }
        } else {
            Log.d(TAG, "OpenCVLoader.initDebug() succeeded");
        }
    }

    // -------- Public API ----------
    public static void setEventSink(EventChannel.EventSink sink) {
        eventSink = sink;
    }

    public static void setHue(int hue360) {
        // ha 0..360 jön:
        int h = hue360;
        if (h > 180) h = h / 2;    // 360-as skáláról 180-asra
        if (h < 0) h = 0;
        if (h > 179) h = 179;
        targetHue = h;
        Log.d(TAG, "setHue=" + targetHue);
    }

    public static void setAreaMin(double area) {
        areaMin = Math.max(0.0, area);
        Log.d(TAG, "setAreaMin=" + areaMin);
    }


    public static void startCamera(JavaCamera2View view, EventChannel.EventSink sink) {
        if (view == null) return;
        cameraView = view;
        if (sink != null) eventSink = sink;

        cameraView.setCvCameraViewListener(new StandaloneHelper());
        cameraView.setCameraIndex(CameraBridgeViewBase.CAMERA_ID_BACK);
        try { cameraView.setMaxFrameSize(1280, 720); } catch (Throwable ignore) {}
        cameraView.setCameraPermissionGranted();
        cameraView.enableView();
    }

    public static void stopCamera() {
        Log.d(TAG, "stopCamera()");
        if (cameraView != null) {
            try {
                cameraView.disableView();
                ViewGroup parent = (ViewGroup) cameraView.getParent();
                if (parent != null) parent.removeView(cameraView);
            } catch (Throwable t) {
                Log.e(TAG, "stopCamera error", t);
            } finally {
                cameraView = null;
            }
        }
        eventSink = null;
    }

    // -------- CvCameraViewListener2 ----------
    @Override
    public void onCameraViewStarted(int width, int height) {
        Log.d(TAG, "rrrrrrrrronCameraViewStarted: " + width + "x" + height);
        previewStarted = true;

        hsv = new Mat();
        mask = new Mat();
        mask2 = new Mat();
        morphed = new Mat();
        hierarchy = new Mat();
        kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, new Size(5, 5));
        contours = new ArrayList<>();

        t0 = System.currentTimeMillis();
        fpsCnt = 0;
        lastFps = 0;
        sendStatus("started", 0, 0, 0, 0, 0.0);
    }

    @Override
    public void onCameraViewStopped() {
        Log.d(TAG, "rrrrrrrrrrronCameraViewStopped");
        previewStarted = false;

        release(hsv, mask, mask2, morphed, hierarchy, kernel);
        if (contours != null) {
            for (MatOfPoint m : contours) {
                try { if (m != null) m.release(); } catch (Throwable ignore) {}
            }
            contours = null;
        }
    }

    private void release(Mat... mats) {
        if (mats == null) return;
        for (Mat m : mats) {
            if (m != null) try { m.release(); } catch (Throwable ignore) {}
        }
    }

    private static void rgbaToHsv(Mat rgba, Mat hsv) {
        Mat rgb = new Mat();
        Imgproc.cvtColor(rgba, rgb, Imgproc.COLOR_RGBA2RGB);
        Imgproc.cvtColor(rgb, hsv, Imgproc.COLOR_RGB2HSV);
        rgb.release();
    }
    @Override
    public Mat onCameraFrame(CameraBridgeViewBase.CvCameraViewFrame inputFrame) {
        Log.d(TAG, "rrrrrrrrrrronCameraFrame1");

        try {
            Mat rgba = inputFrame.rgba();
            if (rgba == null || rgba.empty()) {
                Log.w(TAG, "rgba empty or null");
                return rgba;
            }

            Log.d(TAG, "onCameraFrame got rgba=" + rgba.width() + "x" + rgba.height());

            // 1) HSV konverzió közvetlenül az rgba-ból
//            Mat rgb = new Mat();
//            Imgproc.cvtColor(rgba, rgb, Imgproc.COLOR_RGBA2RGB);
//            Imgproc.cvtColor(rgb, hsv, Imgproc.COLOR_RGB2HSV);
//            rgb.release();
            Imgproc.cvtColor(rgba, hsv, Imgproc.COLOR_RGB2HSV);
            Imgproc.GaussianBlur(hsv, hsv, new Size(5, 5), 0);
            Log.d(TAG, "rrrrrrrrrrHSV computed");

            // 2) Maszk számítás
            int loH = targetHue - hueDelta;
            int hiH = targetHue + hueDelta;
            if (loH < 0 || hiH > 179) {
                int lo1 = (loH + 180) % 180;
                int hi1 = 179;
                int lo2 = 0;
                int hi2 = hiH % 180;
                Core.inRange(hsv, new Scalar(lo1, satMin, valMin), new Scalar(hi1, 255, 255), mask);
                Core.inRange(hsv, new Scalar(lo2, satMin, valMin), new Scalar(hi2, 255, 255), mask2);
                Core.bitwise_or(mask, mask2, mask);
                Log.d(TAG, "mask wrap-around");
            } else {
                Core.inRange(hsv, new Scalar(loH, satMin, valMin), new Scalar(hiH, 255, 255), mask);
                Log.d(TAG, "mask simple");
            }

            // 3) Morfológia
            Imgproc.dilate(mask, morphed, kernel);
            Imgproc.erode(morphed, morphed, kernel);

            // 4) Kontúrok keresése
            contours.clear();
            Imgproc.findContours(morphed, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE);
            Log.d(TAG, "rrrrrrrrrrrcontours found=" + contours.size());

            double bestArea = 0.0;
            Rect bestRect = null;
            for (int i = 0; i < contours.size(); i++) {
                double a = Imgproc.contourArea(contours.get(i));
                if (a > areaMin && a > bestArea) {
                    Rect r = Imgproc.boundingRect(contours.get(i));
                    bestArea = a;
                    bestRect = r;
                }
            }
            Log.d(TAG, "rrrrrrrrrrronCameraFrame2");
            if (bestRect != null) {
                Log.d(TAG, "rrrrrrrrrrronCameraFrame3");
                rect = bestRect;
                // Rajzolás KÖZVETLENÜL az rgba képre → látható lesz
                Imgproc.rectangle(rgba, rect.tl(), rect.br(), new Scalar(0, 255, 0, 255), 4);
                sendStatusThrottled("rect", rect.x, rect.y, rect.width, rect.height, bestArea, 100);
                Log.d(TAG, "rrrrrrrrrrronCameraFrame4");
                Log.d(TAG, "rect found area=" + bestArea);
            } else {
                Log.d(TAG, "rrrrrrrrrrronCameraFrame5");
                sendStatusThrottled("none", 0, 0, 0, 0, 0.0, 250);
                Log.d(TAG, "rrrrrrrrrrrrno rect found");
            }

            // FPS tick
            fpsCnt++;
            long now = SystemClock.uptimeMillis();
            if (now - t0 >= 1000L) {
                lastFps = fpsCnt;
                fpsCnt = 0;
                t0 = now;
                Log.d(TAG, "rrrrrrrrrrronCameraFrame6");
                sendStatus("tick", rect.x, rect.y, rect.width, rect.height, bestArea);
                Log.d(TAG, "fps=" + lastFps);
            }

            // Flutteren forgatsz → itt csak az eredeti rgba megy vissza
            return rgba;

        } catch (Throwable t) {
            Log.e(TAG, "onCameraFrame exception", t);
            try {
                Mat fallback = inputFrame.rgba();
                return (fallback != null) ? fallback : new Mat();
            } catch (Throwable t2) {
                Log.e(TAG, "onCameraFrame fallback failed", t2);
                return new Mat();
            }
        }
    }

   /* ez mintha fogatott volna csak zold nelkul @Override
    public Mat onCameraFrame(CameraBridgeViewBase.CvCameraViewFrame inputFrame) {
        try {
            Mat rgba = inputFrame.rgba();
            if (rgba == null || rgba.empty()) {
                Log.w(TAG, "rgba empty or null");
                return rgba;
            }

            Log.d(TAG, "onCameraFrame got rgba=" + rgba.width() + "x" + rgba.height());

            // 1) Forgatás feldolgozáshoz
            Mat rotated = new Mat();
            Core.rotate(rgba, rotated, Core.ROTATE_90_CLOCKWISE);
            Log.d(TAG, "rotated size = " + rotated.width() + "x" + rotated.height());

            // 2) HSV konverzió
            Mat rgb = new Mat();
            Imgproc.cvtColor(rotated, rgb, Imgproc.COLOR_RGBA2RGB);
            Imgproc.cvtColor(rgb, hsv, Imgproc.COLOR_RGB2HSV);
            rgb.release();
            Log.d(TAG, "HSV computed");
            Log.d(TAG, "HSV computed");

            // 3) Maszk számítás
            int loH = targetHue - hueDelta;
            int hiH = targetHue + hueDelta;
            if (loH < 0 || hiH > 179) {
                int lo1 = (loH + 180) % 180;
                int hi1 = 179;
                int lo2 = 0;
                int hi2 = hiH % 180;
                Core.inRange(hsv, new Scalar(lo1, satMin, valMin), new Scalar(hi1, 255, 255), mask);
                Core.inRange(hsv, new Scalar(lo2, satMin, valMin), new Scalar(hi2, 255, 255), mask2);
                Core.bitwise_or(mask, mask2, mask);
                Log.d(TAG, "mask wrap-around");
            } else {
                Core.inRange(hsv, new Scalar(loH, satMin, valMin), new Scalar(hiH, 255, 255), mask);
                Log.d(TAG, "mask simple");
            }

            // 4) Morfológia
            Imgproc.dilate(mask, morphed, kernel);
            Imgproc.erode(morphed, morphed, kernel);

            // 5) Kontúrok keresése
            contours.clear();
            Imgproc.findContours(morphed, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE);
            Log.d(TAG, "contours found=" + contours.size());

            double bestArea = 0.0;
            Rect bestRect = null;
            for (int i = 0; i < contours.size(); i++) {
                double a = Imgproc.contourArea(contours.get(i));
                if (a > areaMin && a > bestArea) {
                    Rect r = Imgproc.boundingRect(contours.get(i));
                    bestArea = a;
                    bestRect = r;
                }
            }

            if (bestRect != null) {
                rect = bestRect;
                Imgproc.rectangle(rotated, rect.tl(), rect.br(), new Scalar(0, 255, 0, 255), 4);
                sendStatusThrottled("rect", rect.x, rect.y, rect.width, rect.height, bestArea, 100);
                Log.d(TAG, "rect found area=" + bestArea);
            } else {
                sendStatusThrottled("none", 0, 0, 0, 0, 0.0, 250);
                Log.d(TAG, "no rect found");
            }

            // FPS tick
            fpsCnt++;
            long now = SystemClock.uptimeMillis();
            if (now - t0 >= 1000L) {
                lastFps = fpsCnt;
                fpsCnt = 0;
                t0 = now;
                sendStatus("tick", rect.x, rect.y, rect.width, rect.height, bestArea);
                Log.d(TAG, "fps=" + lastFps);
            }

            // --- FONTOS ---
            // Nem a rotated-et adjuk vissza, mert eltér a buffer méretétől → crash.
            // Csak feldolgozáshoz használjuk, de return az eredeti rgba.
            return rgba;

        } catch (Throwable t) {
            Log.e(TAG, "onCameraFrame exception", t);
            try {
                Mat fallback = inputFrame.rgba();
                return (fallback != null) ? fallback : new Mat();
            } catch (Throwable t2) {
                Log.e(TAG, "onCameraFrame fallback failed", t2);
                return new Mat();
            }
        }
    }*/


    // -------- Event helpers ----------
//    private void sendStatus(String type, int x, int y, int w, int h, double area) {
//        if (eventSink == null) return;
//        String json = String.format("{\"type\":\"%s\",\"hue\":%d,\"w\":%d,\"h\":%d,\"x\":%d,\"y\":%d,\"area\":%.1f,\"fps\":%d}",
//                type, targetHue, w, h, x, y, area, lastFps);
//        try { eventSink.success(json); }
//        catch (Throwable t) { Log.w(TAG, "event error", t); }
//    }
//    private void sendStatus(String type, int x, int y, int w, int h, double area) {
//        if (eventSink == null) return;
//        try {
//            java.util.HashMap<String, Object> map = new java.util.HashMap<>();
//            map.put("type", type);
//            map.put("hue", targetHue);
//            map.put("w", w);
//            map.put("h", h);
//            map.put("x", x);
//            map.put("y", y);
//            map.put("area", area);
//            map.put("fps", lastFps);
//            eventSink.success(map);
//        } catch (Throwable t) {
//            Log.w(TAG, "event error", t);
//        }
//    }
    private void sendStatus(String type, int x, int y, int w, int h, double area) {
        if (eventSink == null) return;

        String json = String.format(
                "{\"type\":\"%s\",\"hue\":%d,\"w\":%d,\"h\":%d,\"x\":%d,\"y\":%d,\"area\":%.1f,\"fps\":%d}",
                type, targetHue, w, h, x, y, area, lastFps
        );

        // Fő szálra postolás
        android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
        mainHandler.post(() -> {
            try {
                eventSink.success(json);
                Log.d(TAG, "rrrrr sendStatus → " + json);
            } catch (Throwable t) {
                Log.e(TAG, "rrrrr event error", t);
            }
        });
    }
    private void sendStatusThrottled(String type, int x, int y, int w, int h, double area, long minIntervalMs) {
        long now = System.currentTimeMillis();
        if (now - lastEventMs < minIntervalMs) return;
        lastEventMs = now;
        sendStatus(type, x, y, w, h, area);
    }
}
