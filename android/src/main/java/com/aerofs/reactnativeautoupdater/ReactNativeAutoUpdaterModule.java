package com.aerofs.reactnativeautoupdater;

import android.content.Context;
import android.content.SharedPreferences;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;

import java.util.HashMap;
import java.util.Map;

import javax.annotation.Nullable;

/**
 * @author rahul
 */
public class ReactNativeAutoUpdaterModule extends ReactContextBaseJavaModule {

    private ReactApplicationContext context;

    public ReactNativeAutoUpdaterModule(ReactApplicationContext context) {
        super(context);
        this.context = context;
    }

    @Override
    public String getName() {
        return "ReactNativeAutoUpdater";
    }

    @Nullable
    @Override
    public Map<String, Object> getConstants() {
        Map<String, Object> constants = new HashMap<String, Object>();
        SharedPreferences prefs = this.context.getSharedPreferences(
                ReactNativeAutoUpdater.RNAU_SHARED_PREFERENCES, Context.MODE_PRIVATE
        );
        String version =  prefs.getString(ReactNativeAutoUpdater.RNAU_STORED_VERSION, null);
        constants.put("jsCodeVersion", version);
        return constants;
    }
}
