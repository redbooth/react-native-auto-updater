package com.aerofs.reactnativeautoupdater;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.os.AsyncTask;
import android.os.PowerManager;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Date;

/**
 * @author rahul
 */

public class ReactNativeAutoUpdater {

    public static final String RNAU_SHARED_PREFERENCES = "React_Native_Auto_Updater_Shared_Preferences";
    public static final String RNAU_STORED_VERSION = "React_Native_Auto_Updater_Stored_Version";
    private final String RNAU_LAST_UPDATE_TIMESTAMP = "React_Native_Auto_Updater_Last_Update_Timestamp";
    private final String RNAU_STORED_JS_FILENAME = "main.android.jsbundle";
    private final String RNAU_STORED_JS_FOLDER = "JSCode";

    public enum ReactNativeAutoUpdaterFrequency {
        EACH_TIME, DAILY, WEEKLY
    }

    public enum ReactNativeAutoUpdaterUpdateType {
        MAJOR, MINOR, PATCH
    }

    private static ReactNativeAutoUpdater ourInstance = new ReactNativeAutoUpdater();
    private String updateMetadataUrl;
    private String metadataAssetName;
    private ReactNativeAutoUpdaterFrequency updateFrequency = ReactNativeAutoUpdaterFrequency.EACH_TIME;
    private ReactNativeAutoUpdaterUpdateType updateType = ReactNativeAutoUpdaterUpdateType.MINOR;
    private Context context;
    private boolean showProgress = true;
    private String hostname;
    private Interface activity;

    public static ReactNativeAutoUpdater getInstance(Context context) {
        ourInstance.context = context;
        return ourInstance;
    }

    private ReactNativeAutoUpdater() {
    }

    public ReactNativeAutoUpdater setUpdateMetadataUrl(String url) {
        this.updateMetadataUrl = url;
        return this;
    }

    public ReactNativeAutoUpdater setMetadataAssetName(String metadataAssetName) {
        this.metadataAssetName = metadataAssetName;
        return this;
    }

    public ReactNativeAutoUpdater setUpdateFrequency(ReactNativeAutoUpdaterFrequency frequency) {
        this.updateFrequency = frequency;
        return this;
    }

    public ReactNativeAutoUpdater setUpdateTypesToDownload(ReactNativeAutoUpdaterUpdateType updateType) {
        this.updateType = updateType;
        return this;
    }

    public ReactNativeAutoUpdater setHostnameForRelativeDownloadURLs(String hostnameForRelativeDownloadURLs) {
        this.hostname = hostnameForRelativeDownloadURLs;
        return this;
    }

    public ReactNativeAutoUpdater showProgress(boolean progress) {
        this.showProgress = progress;
        return this;
    }

    public ReactNativeAutoUpdater setParentActivity(Interface activity) {
        this.activity = activity;
        return this;
    }

    public void checkForUpdates() {
        if (this.shouldCheckForUpdates()) {
            this.showProgressToast(R.string.auto_updater_checking);
            FetchMetadataTask task = new FetchMetadataTask();
            task.execute(this.updateMetadataUrl);
        }
    }

    private boolean shouldCheckForUpdates() {
        if (this.updateFrequency == ReactNativeAutoUpdaterFrequency.EACH_TIME) {
            return true;
        }

        SharedPreferences prefs = context.getSharedPreferences(RNAU_SHARED_PREFERENCES, Context.MODE_PRIVATE);

        long msSinceUpdate = System.currentTimeMillis() - prefs.getLong(RNAU_LAST_UPDATE_TIMESTAMP, 0);
        int daysSinceUpdate = (int) (msSinceUpdate / 1000 / 60 / 60 / 24);

        switch (this.updateFrequency) {
            case DAILY:
                return daysSinceUpdate >= 1;
            case WEEKLY:
                return daysSinceUpdate >= 7;
            default:
                return true;
        }
    }

    public String getLatestJSCodeLocation() {
        SharedPreferences prefs = context.getSharedPreferences(RNAU_SHARED_PREFERENCES, Context.MODE_PRIVATE);
        String currentVersionStr = prefs.getString(RNAU_STORED_VERSION, null);

        Version currentVersion;
        try {
            currentVersion = new Version(currentVersionStr);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }

        String jsonString = this.getStringFromAsset(this.metadataAssetName);
        if (jsonString == null) {
            return null;
        } else {
            String jsCodePath = null;
            try {
                JSONObject assetMetadata = new JSONObject(jsonString);
                String assetVersionStr = assetMetadata.getString("version");
                Version assetVersion = new Version(assetVersionStr);

                if (currentVersion.compareTo(assetVersion) > 0) {
                    File jsCodeDir = context.getDir(RNAU_STORED_JS_FOLDER, Context.MODE_PRIVATE);
                    File jsCodeFile = new File(jsCodeDir, RNAU_STORED_JS_FILENAME);
                    jsCodePath = jsCodeFile.getAbsolutePath();
                } else {
                    SharedPreferences.Editor editor = prefs.edit();
                    editor.putString(RNAU_STORED_VERSION, currentVersionStr);
                    editor.apply();
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            return jsCodePath;
        }
    }

    private String getStringFromAsset(String assetName) {
        String jsonString = null;
        try {
            InputStream inputStream = this.context.getAssets().open(assetName);
            int size = inputStream.available();
            byte[] buffer = new byte[size];
            inputStream.read(buffer);
            inputStream.close();
            jsonString = new String(buffer, "UTF-8");
        } catch (Exception e) {
            e.printStackTrace();
        }
        return jsonString;
    }

    private void verifyMetadata(JSONObject metadata) {
        try {
            String version = metadata.getString("version");
            String minContainerVersion = metadata.getString("minContainerVersion");
            if (this.shouldDownloadUpdate(version, minContainerVersion)) {
                this.showProgressToast(R.string.auto_updater_downloading);
                String downloadURL = metadata.getJSONObject("url").getString("url");
                if (metadata.getJSONObject("url").getBoolean("isRelative")) {
                    if (this.hostname == null) {
                        this.showProgressToast(R.string.auto_updater_no_hostname);
                        System.out.println("No hostname provided for relative downloads. Aborting");
                    } else {
                        downloadURL = this.hostname + downloadURL;
                    }
                }
                FetchUpdateTask updateTask = new FetchUpdateTask();
                updateTask.execute(downloadURL, version);
            } else {
                this.showProgressToast(R.string.auto_updater_up_to_date);
                System.out.println("Already Up to Date");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private boolean shouldDownloadUpdate(String versionStr, String minContainerVersionStr) {
        boolean shouldDownload = false;

        SharedPreferences prefs = context.getSharedPreferences(RNAU_SHARED_PREFERENCES, Context.MODE_PRIVATE);
        String currentVersionStr = prefs.getString(RNAU_STORED_VERSION, null);
        if (currentVersionStr == null) {
            shouldDownload = true;
        } else {
            Version currentVersion = new Version(currentVersionStr);
            Version updateVersion = new Version(versionStr);
            switch (this.updateType) {
                case MAJOR:
                    if (currentVersion.compareMajor(updateVersion) < 0) {
                        shouldDownload = true;
                    }
                    break;

                case MINOR:
                    if (currentVersion.compareMinor(updateVersion) < 0) {
                        shouldDownload = true;
                    }
                    break;

                case PATCH:
                    if (currentVersion.compareTo(updateVersion) < 0) {
                        shouldDownload = true;
                    }
                    break;

                default:
                    shouldDownload = true;
                    break;
            }
        }

        /*
         * Then check if the update is good for our container version.
         */
        String containerVersionStr = this.getContainerVersion();
        Version containerVersion = new Version(containerVersionStr);
        Version minReqdContainerVersion = new Version(minContainerVersionStr);

        return shouldDownload && containerVersion.compareTo(minReqdContainerVersion) >= 0;
    }

    private String getContainerVersion() {
        String version = null;
        try {
            PackageInfo pInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            version = pInfo.versionName;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return version;
    }

    private void updateDownloaded() {
        this.activity.updateFinished();
    }

    private void showProgressToast(int message) {
        if (this.showProgress) {
            int duration = Toast.LENGTH_SHORT;
            Toast toast = Toast.makeText(context, message, duration);
            toast.show();
        }
    }

    private class FetchMetadataTask extends AsyncTask<String, Void, JSONObject> {

        @Override
        protected JSONObject doInBackground(String... params) {
            String metadataStr;
            JSONObject metadata = null;
            try {
                URL url = new URL(params[0]);

                BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
                StringBuilder total = new StringBuilder();
                String line;
                while ((line = in.readLine()) != null) {
                    total.append(line);
                }
                metadataStr = total.toString();
                if (!metadataStr.isEmpty()) {
                    metadata = new JSONObject(metadataStr);
                } else {
                    ReactNativeAutoUpdater.this.showProgressToast(R.string.auto_updater_no_metadata);
                }
            } catch (Exception e) {
                ReactNativeAutoUpdater.this.showProgressToast(R.string.auto_updater_invalid_metadata);
                e.printStackTrace();
            }
            return metadata;
        }

        @Override
        protected void onPostExecute(JSONObject jsonObject) {
            ReactNativeAutoUpdater.this.verifyMetadata(jsonObject);
        }
    }

    private class FetchUpdateTask extends AsyncTask<String, Void, String> {

        private PowerManager.WakeLock mWakeLock;

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
            PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            mWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, getClass().getName());
            mWakeLock.acquire();
        }

        @Override
        protected String doInBackground(String... params) {
            InputStream input = null;
            FileOutputStream output = null;
            HttpURLConnection connection = null;
            try {
                URL url = new URL(params[0]);
                connection = (HttpURLConnection) url.openConnection();
                connection.connect();

                // expect HTTP 200 OK, so we don't mistakenly save error report
                // instead of the file
                if (connection.getResponseCode() != HttpURLConnection.HTTP_OK) {
                    return "Server returned HTTP " + connection.getResponseCode()
                            + " " + connection.getResponseMessage();
                }

                // download the file
                input = connection.getInputStream();
                File jsCodeDir = context.getDir(RNAU_STORED_JS_FOLDER, Context.MODE_PRIVATE);
                if (!jsCodeDir.exists()) {
                    jsCodeDir.mkdirs();
                }
                File jsCodeFile = new File(jsCodeDir, RNAU_STORED_JS_FILENAME);
                output = new FileOutputStream(jsCodeFile);

                byte data[] = new byte[4096];
                int count;
                while ((count = input.read(data)) != -1) {
                    // allow canceling with back button
                    if (isCancelled()) {
                        input.close();
                        return null;
                    }
                    output.write(data, 0, count);
                }

                SharedPreferences prefs = context.getSharedPreferences(RNAU_SHARED_PREFERENCES, Context.MODE_PRIVATE);
                SharedPreferences.Editor editor = prefs.edit();
                editor.putString(RNAU_STORED_VERSION, params[1]);
                editor.putLong(RNAU_LAST_UPDATE_TIMESTAMP, new Date().getTime());
                editor.apply();
            } catch (Exception e) {
                e.printStackTrace();
                return e.toString();
            } finally {
                try {
                    if (output != null)
                        output.close();
                    if (input != null)
                        input.close();
                } catch (IOException ignored) {
                }

                if (connection != null)
                    connection.disconnect();
            }
            return null;
        }

        @Override
        protected void onPostExecute(String result) {
            mWakeLock.release();
            if (result != null) {
                ReactNativeAutoUpdater.this.showProgressToast(R.string.auto_updater_downloading_error);
            } else {
                ReactNativeAutoUpdater.this.updateDownloaded();
                ReactNativeAutoUpdater.this.showProgressToast(R.string.auto_updater_downloading_success);
            }
        }
    }

    public interface Interface {
        void updateFinished();
    }
}

