package com.example.flutter_opencv_bridge;

import android.content.Context;
import android.view.ViewGroup;

import androidx.annotation.NonNull;

import org.opencv.android.CameraBridgeViewBase;
import org.opencv.android.JavaCamera2View;

import io.flutter.plugin.platform.PlatformView;

public class CameraPreview implements PlatformView {
    private final JavaCamera2View cameraView;

    CameraPreview(Context context) {
        cameraView = new JavaCamera2View(context, -1);
        cameraView.setCameraIndex(CameraBridgeViewBase.CAMERA_ID_BACK);
        cameraView.setCvCameraViewListener(new StandaloneHelper());

        try { cameraView.setMaxFrameSize(1280, 720); } catch (Throwable ignore) {}
        try { cameraView.setCameraPermissionGranted(); } catch (Throwable ignore) {}

        cameraView.setLayoutParams(
                new ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                )
        );

        // KAMERA INDUL AZONNAL
        StandaloneHelper.startCamera(cameraView, null);
    }

    @NonNull
    @Override
    public android.view.View getView() {
        return cameraView;
    }

    @Override
    public void dispose() {
        cameraView.disableView();
    }

    public JavaCamera2View getCameraView() {
        return cameraView;
    }
}
