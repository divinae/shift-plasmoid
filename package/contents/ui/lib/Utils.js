.pragma library

// A file:// url from a file dialog, as the plain path the config keys hold.
function getPath(fileUrl) {
    var path = fileUrl.toString().replace(/^file:\/\//, "");
    try {
        return decodeURIComponent(path);
    } catch (e) {
        // Already a plain path containing a stray '%'; leave it alone.
        return path;
    }
}
