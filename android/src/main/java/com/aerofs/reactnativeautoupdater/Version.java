package com.aerofs.reactnativeautoupdater;

import android.support.annotation.NonNull;

/**
 * @author rahul
 */
public class Version implements Comparable<Version> {

    private String version;

    public final String get() {
        return this.version;
    }

    public Version(String version) {
        if (version == null)
            throw new IllegalArgumentException("Version can not be null");
        if (!version.matches("[0-9]+(\\.[0-9]+)*"))
            throw new IllegalArgumentException("Invalid version format");
        this.version = version;
    }

    @Override
    public int compareTo(@NonNull Version that) {
        String[] thisParts = this.get().split("\\.");
        String[] thatParts = that.get().split("\\.");
        int length = Math.max(thisParts.length, thatParts.length);
        for (int i = 0; i < length; i++) {
            int thisPart = i < thisParts.length ?
                    Integer.parseInt(thisParts[i]) : 0;
            int thatPart = i < thatParts.length ?
                    Integer.parseInt(thatParts[i]) : 0;
            if (thisPart < thatPart)
                return -1;
            if (thisPart > thatPart)
                return 1;
        }
        return 0;
    }

    public int compareMajor(Version that) {
        if (that == null)
            return 1;
        String[] thisParts = this.get().split("\\.");
        String[] thatParts = that.get().split("\\.");

        int thisMajor = thisParts.length > 0 ? Integer.parseInt(thisParts[0]) : 0;
        int thatMajor = thatParts.length > 0 ? Integer.parseInt(thatParts[0]) : 0;

        return thisMajor - thatMajor;
    }

    public int compareMinor(Version that) {
        if (that == null)
            return 1;

        if (this.compareMajor(that) == 0) {
            String[] thisParts = this.get().split("\\.");
            String[] thatParts = that.get().split("\\.");

            int thisMinor = thisParts.length > 1 ? Integer.parseInt(thisParts[1]) : 0;
            int thatMinor = thatParts.length > 1 ? Integer.parseInt(thatParts[1]) : 0;

            return thisMinor - thatMinor;
        } else {
            return this.compareMajor(that);
        }
    }

    @Override
    public boolean equals(Object that) {
        if (this == that)
            return true;
        if (that == null)
            return false;
        if (this.getClass() != that.getClass())
            return false;
        return this.compareTo((Version) that) == 0;
    }

}
