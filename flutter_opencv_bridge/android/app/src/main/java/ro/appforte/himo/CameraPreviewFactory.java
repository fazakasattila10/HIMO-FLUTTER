package ro.appforte.himo;

import android.content.Context;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class CameraPreviewFactory extends PlatformViewFactory {
    private final Context context;
    private static CameraPreview lastCreatedView;

    public CameraPreviewFactory(Context context) {
        super(StandardMessageCodec.INSTANCE);
        this.context = context;
    }

    @Override
    public PlatformView create(Context context, int id, Object args) {
        lastCreatedView = new CameraPreview(this.context);
        return lastCreatedView;
    }

    public static CameraPreview getLastCreatedView() {
        return lastCreatedView;
    }
}
