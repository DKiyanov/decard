package com.dkiyanov.decard;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.content.Context;
import android.provider.Settings.Secure;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity.java";
    private static final String CHANNEL = "com.dkiyanov.decard";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            // This method is invoked on the main thread.
                            if (call.method.equals("getDeviceID")) {
                                result.success(getDeviceID());
                            }
                            else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private String getDeviceID() {
        String android_id = Secure.getString(getContext().getContentResolver(), Secure.ANDROID_ID);
        return android_id;
    }
}
