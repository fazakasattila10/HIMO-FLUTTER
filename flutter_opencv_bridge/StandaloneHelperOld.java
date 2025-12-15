package ro.appforte.himo;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.Toast;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

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

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import io.flutter.plugin.common.EventChannel;

public class StandaloneHelperOld implements CameraBridgeViewBase.CvCameraViewListener2 {
    private static final String TAG = "OpenCVBridge";
    private static final int REQ_CAMERA = 1234;

    private static CameraBridgeViewBase cameraView;
    private static EventChannel.EventSink eventSink;
    private static Activity activity;

    // ---- Detection params (állítható MethodChannelel) ----
    private static volatile int targetHue = 60;     // zöld ~60 (OpenCV HSV: 0..179)
    private static volatile int hueDelta  = 15;     // ± tartomány
    private static volatile int satMin    = 120;    // S min (0..255)
    private static volatile int valMin    = 30;     // V min (0..255)
    private static volatile double areaMin = 15000; // minimális kontúr-terület

    // ---- Mats / state ----
    private Mat hsv, mask, mask2, morphed;
    private List<MatOfPoint> contours;
    private Mat hierarchy, kernel;
    private Rect rect = new Rect();
    private boolean previewStarted = false;

    // fps + event throttle
    private long t0 = 0L;
    private int fpsCnt = 0, lastFps = 0;
    private long lastEventMs = 0L;
    private static final int EVENT_MAX_PER_SEC = 8;

    static {
        boolean ok = OpenCVLoader.initDebug();
        if (!ok) {
            try { System.loadLibrary("opencv_java4"); Log.d(TAG, "Loaded opencv_java4"); }
            catch (Throwable t1) {
                try { System.loadLibrary("opencv_java3"); Log.d(TAG, "Loaded opencv_java3"); }
                catch (Throwable t2) { Log.e(TAG, "Failed to load any OpenCV lib", t2); }
            }
        } else {
            Log.d(TAG, "OpenCVLoader.initDebug() succeeded in static block");
        }
    }

    // --------- Public API a MethodChannelhez ---------
    public static void setHue(int hue) { // 0..179
        if (hue < 0) hue = 0; if (hue > 179) hue = 179;
        targetHue = hue;
        Log.d(TAG, "setHue=" + targetHue);
    }
    public static void setAreaMin(double area) {
        areaMin = Math.max(0, area);
        Log.d(TAG, "setAreaMin=" + areaMin);
    }

    public static void startCamera(Activity act, EventChannel.EventSink sink) {
        activity = act;
        eventSink = sink;

        Log.d(TAG, "startCamera()");
        Log.d(TAG, "ABIs: " + Arrays.toString(Build.SUPPORTED_ABIS));
        Toast.makeText(act, "Starting camera…", Toast.LENGTH_SHORT).show();

        boolean ok = OpenCVLoader.initDebug();
        Log.d(TAG, "OpenCV init = " + ok);
        if (!ok) {
            if (eventSink != null) eventSink.error("OpenCV_INIT", "OpenCV init failed", null);
            return;
        }

        if (ContextCompat.checkSelfPermission(act, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(act, new String[]{Manifest.permission.CAMERA}, REQ_CAMERA);
            return;
        }

        act.runOnUiThread(() -> {
            try {
                // Stabilitás miatt Camera1 backend (JavaCameraView) + 1280x720
//                JavaCameraView view = new JavaCameraView(act, -1);
                // Új:

                FrameLayout wrapper = new FrameLayout(act);
                wrapper.setBackgroundColor(Color.BLACK); // itt állíthatod a háttérszínt
                wrapper.setClipToOutline(true); // hogy a rounded corner működjön
                wrapper.setPadding(0,0,0,0);

//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
//                    wrapper.setOutlineProvider(new ViewOutlineProvider() {
//                        @Override
//                        public void getOutline(View view, Outline outline) {
//                            int radius = 40; // px, lekerekítés sugara
//                            outline.setRoundRect(0, 0, view.getWidth(), view.getHeight(), radius);
//                        }
//                    });
//                }

                cameraView = new JavaCamera2View(act, -1);
                cameraView.setCvCameraViewListener(new StandaloneHelperOld());
                cameraView.setCameraIndex(CameraBridgeViewBase.CAMERA_ID_BACK);

// wrap paraméterek: akkora terület, amennyit Flutter UI szabadon hagy
                DisplayMetrics dm = new DisplayMetrics();
                act.getWindowManager().getDefaultDisplay().getMetrics(dm);
                int sidebarWidth = (int)(250 * dm.density); // Flutter oldali sáv szélessége px-ben
                int availW = dm.widthPixels - sidebarWidth;
                int availH = dm.heightPixels;

// --- aspect ratio számolás (pl. 16:9 kamera) ---
                float cameraRatio = 16f / 9f;
                float availRatio = (float) availW / availH;

                int finalW, finalH;
                if (availRatio > cameraRatio) {
                    finalH = availH;
                    finalW = (int) (availH * cameraRatio);
                } else {
                    finalW = availW;
                    finalH = (int) (availW / cameraRatio);
                }

// középre rendezve a wrapperben
                FrameLayout.LayoutParams cameraLp = new FrameLayout.LayoutParams(
                        finalW,
                        finalH,
                        Gravity.START
                );
                cameraView.setLayoutParams(cameraLp);
                wrapper.addView(cameraView);

// végül a wrapper-t tesszük a képernyőre, nem közvetlenül a cameraView-t
                FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                        availW,
                        availH
                );
                lp.leftMargin = sidebarWidth; // ne lógjon be a Flutter sáv alá
                ((FrameLayout) act.findViewById(android.R.id.content)).addView(wrapper, lp);


                try { cameraView.setCameraPermissionGranted(); } catch (Throwable ignore) {}
                try { /*cameraView.setZOrderMediaOverlay(true);*/ } catch (Throwable ignore) {}
                try { /*cameraView.setZOrderOnTop(true);*/ } catch (Throwable ignore) {}
//                cameraView.bringToFront();

                new Handler(Looper.getMainLooper()).postDelayed(() -> {
                    Log.d(TAG, "enableView (delayed) …");
                    cameraView.enableView();
                }, 200);
            } catch (Throwable t) {
                Log.e(TAG, "Error creating/enabling camera view", t);
                if (eventSink != null) eventSink.error("CAMERA_VIEW", t.getMessage(), null);
            }
        });
    }
    public static void updateCameraLayout(int availW, int availH) {
        if (cameraView == null || activity == null) return;

        activity.runOnUiThread(() -> {
            try {
                FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                        availW-120,   // Flutter által számolt szélesség
                        availH-40,   // Flutter által számolt magasság
                        Gravity.END | Gravity.BOTTOM
                );
                cameraView.setCvCameraViewListener(new StandaloneHelperOld());
                cameraView.setCameraIndex(CameraBridgeViewBase.CAMERA_ID_BACK);

// Itt állítsd be a scaleType-ot
//                cameraView.setScaleType(CameraBridgeViewBase.ScaleType.SCALE_FIT_XY);
                lp.setMargins(0, 0, 0, 0); // fontos, ne maradjon padding/margin

                cameraView.setLayoutParams(lp);
                cameraView.requestLayout();

                Log.d(TAG, "updateCameraLayout FINAL=" + availW + "x" + availH);
            } catch (Throwable t) {
                Log.e(TAG, "updateCameraLayout error", t);
            }
        });
    }
    public static void stopCamera() {
        Log.d(TAG, "stopCamera()");
        if (activity != null) {
            activity.runOnUiThread(() -> {
                try {
                    if (cameraView != null) {
                        cameraView.disableView();
                        ViewGroup p = (ViewGroup) cameraView.getParent();
                        if (p != null) p.removeView(cameraView);
                        cameraView = null;
                    }
                } catch (Throwable t) { Log.e(TAG, "stopCamera error", t); }
            });
        }
        eventSink = null;
    }

    public static void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQ_CAMERA) {
            boolean granted = grantResults != null && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            Log.d(TAG, "CAMERA granted=" + granted);
            if (granted && activity != null) startCamera(activity, eventSink);
            else if (eventSink != null) eventSink.error("NO_PERMISSION", "Camera permission denied", null);
        }
    }

    // --------- CvCameraViewListener2 ---------
    @Override
    public void onCameraViewStarted(int width, int height) {
        Log.d(TAG, "onCameraViewStarted: " + width + "x" + height);
        previewStarted = true;

        hsv = new Mat();
        mask = new Mat();
        mask2 = new Mat();           // wrap-aroundhoz, ha hue tartomány átlóg
        morphed = new Mat();
        contours = new ArrayList<>();
        hierarchy = new Mat();
        kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, new Size(5,5));

        t0 = SystemClock.uptimeMillis();
        fpsCnt = 0; lastFps = 0;
        sendStatus("started", 0,0,0,0, 0.0);
    }

    @Override
    public void onCameraViewStopped() {
        Log.d(TAG, "onCameraViewStopped");
        previewStarted = false;
        release(hsv, mask, mask2, morphed, hierarchy, kernel);
        if (contours != null) { for (MatOfPoint m : contours) try { m.release(); } catch (Throwable ignore) {} }
        contours = null;
        sendStatus("stopped", 0,0,0,0, 0.0);
    }
    private static void rgbaToHsv(Mat rgba, Mat hsv) {
        Mat rgb = new Mat();
        Imgproc.cvtColor(rgba, rgb, Imgproc.COLOR_RGBA2RGB);
        Imgproc.cvtColor(rgb, hsv, Imgproc.COLOR_RGB2HSV);
        rgb.release();
    }
    @Override
    public Mat onCameraFrame(CameraBridgeViewBase.CvCameraViewFrame inputFrame) {
        Mat rgba = inputFrame.rgba();

        // --- HSV szegmentálás (RGBA -> HSV) ---
        rgbaToHsv(rgba, hsv);

        int loH = targetHue - hueDelta;
        int hiH = targetHue + hueDelta;
        Scalar low, high;

        if (loH < 0 || hiH > 179) {
            // Átlóg a tartomány → két maszk és OR
            int lo1 = (loH + 180) % 180;
            int hi1 = 179;
            int lo2 = 0;
            int hi2 = hiH % 180;

            low  = new Scalar(lo1, satMin, valMin);
            high = new Scalar(hi1, 255, 255);
            Core.inRange(hsv, low, high, mask);

            low  = new Scalar(lo2, satMin, valMin);
            high = new Scalar(hi2, 255, 255);
            Core.inRange(hsv, low, high, mask2);

            Core.bitwise_or(mask, mask2, mask);
        } else {
            low  = new Scalar(loH, satMin, valMin);
            high = new Scalar(hiH, 255, 255);
            Core.inRange(hsv, low, high, mask);
        }

        // Morfológia (zajszűrés)
        Imgproc.dilate(mask, morphed, kernel);
        Imgproc.erode(morphed, morphed, kernel);

        // Kontúrok
        contours.clear();
        Imgproc.findContours(morphed, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE);

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
            // ZÖLD keret (Scalar: BGRA sorrend!)
            Imgproc.rectangle(rgba, rect.tl(), rect.br(), new Scalar(0, 255, 0, 255), 4);
            // státusz 100ms-enként
            sendStatusThrottled("rect", rect.x, rect.y, rect.width, rect.height, bestArea, 100);
        } else {
            // néha küldjünk „no rect” státuszt is
            sendStatusThrottled("none", 0,0,0,0, 0.0, 250);
        }

        // FPS számolás és másodpercenként riport
        fpsCnt++;
        long now = SystemClock.uptimeMillis();
        if (now - t0 >= 1000L) {
            lastFps = fpsCnt; fpsCnt = 0; t0 = now;
            sendStatus("tick", rect.x, rect.y, rect.width, rect.height, bestArea);
        }

        return rgba; // ezt rendereli a JavaCameraView
    }

    // --------- helpers ---------
    private void release(Mat... mats) { if (mats == null) return; for (Mat m : mats) if (m != null) try { m.release(); } catch (Throwable ignore) {} }

    private void sendStatus(String type, int x, int y, int w, int h, double area) {
        if (eventSink == null) return;
        String json = "{\"type\":\""+type+"\",\"hue\":"+targetHue+",\"w\":"+w+",\"h\":"+h+",\"x\":"+x+",\"y\":"+y+",\"area\":"+area+",\"fps\":"+lastFps+"}";
        try {
            // Post to UI thread:
            if (activity != null) {
                activity.runOnUiThread(() -> {
                    try {
                        eventSink.success(json);
                    } catch (Throwable t) {
                        Log.w(TAG, "event error", t);
                    }
                });
            }
        } catch (Throwable t) {
            Log.w(TAG, "event error outer", t);
        }
    }

    private void sendStatusThrottled(String type, int x, int y, int w, int h, double area, long minIntervalMs) {
        if (eventSink == null) return;
        long now = SystemClock.uptimeMillis();
        if (now - lastEventMs < minIntervalMs) return;
        lastEventMs = now;
        sendStatus(type, x, y, w, h, area);
    }
}
