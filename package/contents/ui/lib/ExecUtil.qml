// Version 6

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Plasma5Support.DataSource {
    id: executable

    property var listeners: ({}) // Empty Map

    signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)

    function wrapToken(token) {
        token = "" + token;
        // ' => '"'"' to escape the single quotes
        token = token.replace(/\'/g, "\'\"\'\"\'");
        token = "\'" + token + "\'";
        return token;
    }

    function exec(cmd, callback) {
        if (Array.isArray(cmd)) {
            cmd = cmd.map(wrapToken);
            cmd = cmd.join(' ');
        }
        if (typeof callback === 'function') {
            // One callback per command: a second exec of a command still running replaces
            // the first. Listeners are called from onNewData, never connected to `exited`,
            // so there is nothing to disconnect.
            listeners[cmd] = execCallback.bind(executable, callback);
        }
        connectSource(cmd);
    }

    function stopExec(cmd) {
        delete listeners[cmd];
        disconnectSource(cmd);
    }

    function execCallback(callback, cmd, exitCode, exitStatus, stdout, stderr) {
        delete listeners[cmd];
        callback(cmd, exitCode, exitStatus, stdout, stderr);
    }

    engine: "executable"
    connectedSources: []
    onNewData: (sourceName, data) => {
        var cmd = sourceName;
        var exitCode = data["exit code"];
        var exitStatus = data["exit status"];
        var stdout = data["stdout"];
        var stderr = data["stderr"];
        var listener = listeners[cmd];
        if (listener)
            listener(cmd, exitCode, exitStatus, stdout, stderr);
        exited(cmd, exitCode, exitStatus, stdout, stderr);
        disconnectSource(sourceName); // cmd finished
    }
}
