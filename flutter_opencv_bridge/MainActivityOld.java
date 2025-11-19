package com.example.flutter_opencv_bridge;

import android.content.pm.ActivityInfo;
import android.util.Log;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivityOld extends FlutterActivity {
    private static final String METHOD_CHANNEL = "opencv_channel";
    private static final String EVENT_CHANNEL = "opencv_event_channel";
    private static final String TAG = "OpenCVBridge";
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        Log.d("OpenCVBridge", "MainActivity onRequestPermissionsResult()");
        StandaloneHelper.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }
    @Override
    protected void onResume() {
        super.onResume();
        Log.d("MainActivity", "onResume, requestedOrientation=" + getRequestedOrientation());
    }
    @Override
    public void configureFlutterEngine(io.flutter.embedding.engine.FlutterEngine flutterEngine) {
        Log.d(TAG, "configureFlutterEngine() start");
        super.configureFlutterEngine(flutterEngine);

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object args, EventChannel.EventSink events) {
                        Log.d(TAG, "EventChannel onListen() called with args=" + args);
                        StandaloneHelper.startCamera(MainActivityOld.this, events);
                    }

                    @Override
                    public void onCancel(Object args) {
                        Log.d(TAG, "EventChannel onCancel() called");
                        StandaloneHelper.stopCamera();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "orientation_channel")
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("setLandscape")) {
                        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
                        Log.d("MainActivity", "onResume, requestedOrientation=" + getRequestedOrientation());
                        result.success(null);
                    } else if (call.method.equals("setPortrait")) {
                        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), METHOD_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "stopCamera":
                            StandaloneHelper.stopCamera();
                            result.success("Camera stopped");
                            break;
                        case "setHue": {
                            int hue = ((Number)((java.util.Map)call.arguments).get("hue")).intValue(); // 0..179
                            StandaloneHelper.setHue(hue);
                            result.success("hue=" + hue);
                            break;
                        }
                        case "setAreaMin": {
                            double area = ((Number)((java.util.Map)call.arguments).get("area")).doubleValue();
                            StandaloneHelper.setAreaMin(area);
                            result.success("areaMin=" + area);
                            break;
                        }
                        case "setCameraSize": {
                            double width = ((Number)((java.util.Map)call.arguments).get("width")).doubleValue();
                            double height = ((Number)((java.util.Map)call.arguments).get("height")).doubleValue();
//                            StandaloneHelper.updateCameraLayout((int) width, (int) height);
//                            result.success("setCameraSize " + width + "x" + height);
                            break;
                        }
                        default:
                            result.notImplemented();
                    }
                });
        Log.d(TAG, "configureFlutterEngine() end");
    }
}
