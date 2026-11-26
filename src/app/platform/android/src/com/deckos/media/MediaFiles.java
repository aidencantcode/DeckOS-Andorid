// DeckOS - media
// A file picked in Android's file manager (C++ MediaLibrary::pickFile) arrives as a content:// address,
// not a path: this copies it into the game's media folder, with the extension its type says. Called on
// a worker thread (a trailer can be large).

package com.deckos.media;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;
import android.webkit.MimeTypeMap;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Locale;


public final class MediaFiles {
    private static final String TAG = "DeckOS/media";

    private MediaFiles() {}

    /// copies `uri` to `destWithoutExtension` + "." + its extension; the file's path, or "" if it failed
    public static String copy(Context ctx, String uri, String destWithoutExtension) {
        if (ctx == null || uri == null || destWithoutExtension == null)
            return "";
        ContentResolver resolver = ctx.getContentResolver();
        Uri source = Uri.parse(uri);
        File out = new File(destWithoutExtension + "." + extensionOf(resolver, source));
        try (InputStream in = resolver.openInputStream(source);
             OutputStream os = new FileOutputStream(out)) {
            if (in == null)
                return "";
            byte[] buf = new byte[256 * 1024];
            int n;
            while ((n = in.read(buf)) > 0)
                os.write(buf, 0, n);
            return out.getAbsolutePath();
        }
        catch (Exception e) {
            Log.w(TAG, "can't copy the picked file: " + e);
            //noinspection ResultOfMethodCallIgnored
            out.delete();
            return "";
        }
    }

    /// from the file's type (image/png -> png), else its name; "bin" if neither says
    private static String extensionOf(ContentResolver resolver, Uri uri) {
        String ext = null;
        try {
            String type = resolver.getType(uri);
            if (type != null)
                ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(type);
        }
        catch (Exception ignored) {}
        if (ext == null || ext.isEmpty()) {
            try (Cursor c = resolver.query(uri, new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null)) {
                if (c != null && c.moveToFirst()) {
                    String name = c.getString(0);
                    int dot = name != null ? name.lastIndexOf('.') : -1;
                    if (dot > 0 && dot < name.length() - 1)
                        ext = name.substring(dot + 1);
                }
            }
            catch (Exception ignored) {}
        }
        if (ext == null || ext.isEmpty())
            return "bin";
        ext = ext.toLowerCase(Locale.ROOT);
        return ext.equals("jpeg") ? "jpg" : ext;
    }
}
