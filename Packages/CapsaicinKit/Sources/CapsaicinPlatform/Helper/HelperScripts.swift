import Foundation

enum HelperScripts {
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    static func appleScript(_ script: String) -> String {
        let literal = script.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        // エラー番号は終了コードに収まらないので、認証の取り消しを stdout で区別する。
        return """
        try
            do shell script "\(literal)" with administrator privileges
            return "success"
        on error messageText number errorNumber
            if errorNumber is -128 then return "cancelled"
            return "failed:" & errorNumber & ":" & messageText
        end try
        """
    }

    static func sudoers(paths: HelperPaths, uid: UInt32) -> String {
        "#\(uid) ALL=(root) NOPASSWD: \(paths.helper) on, \(paths.helper) off"
    }

    static func daemonPlist(paths: HelperPaths) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Label</key><string>\(paths.label)</string>
        <key>ProgramArguments</key><array><string>\(paths.helper)</string><string>off</string></array>
        <key>RunAtLoad</key><true/>
        </dict></plist>
        """
    }

    static func install(paths: HelperPaths, bundledHelperPath: String, uid: UInt32) throws -> String {
        guard bundledHelperPath.hasPrefix("/"), !bundledHelperPath.utf8.contains(0), uid > 0 else {
            throw HelperError.invalidInstallerInput
        }
        let helper = shellQuote(paths.helper)
        let sudoersPath = shellQuote(paths.sudoers)
        let daemon = shellQuote(paths.daemon)
        return """
        set -eu
        source=\(shellQuote(bundledHelperPath))
        /bin/test -f "$source"
        /bin/test -x "$source"
        source_hash=$(/usr/bin/shasum -a 256 < "$source")
        /usr/bin/install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools /etc/sudoers.d
        /usr/bin/install -o root -g wheel -m 755 "$source" \(helper)
        installed_hash=$(/usr/bin/shasum -a 256 < \(helper))
        /bin/test "$source_hash" = "$installed_hash"
        rules=$(/usr/bin/mktemp \(shellQuote(paths.sudoers + ".XXXXXX")))
        trap '/bin/rm -f "$rules"' EXIT
        /usr/bin/printf '%s\\n' \(shellQuote(sudoers(paths: paths, uid: uid))) > "$rules"
        /usr/sbin/chown root:wheel "$rules"
        /bin/chmod 440 "$rules"
        /usr/sbin/visudo -c -f "$rules"
        /bin/mv -f "$rules" \(sudoersPath)
        /usr/bin/printf '%s\\n' \(shellQuote(daemonPlist(paths: paths))) > \(daemon)
        /usr/sbin/chown root:wheel \(daemon)
        /bin/chmod 644 \(daemon)
        """
    }

    static func remove(paths: HelperPaths, restoreSleep: Bool) -> String {
        """
        set -eu
        \(restoreSleep ? "/usr/bin/pmset -a disablesleep 0\n" : "")\
        if /bin/launchctl print system/\(paths.label) >/dev/null 2>&1; then
            /bin/launchctl bootout system/\(paths.label)
        fi
        /bin/rm -f \(shellQuote(paths.daemon))
        /bin/rm -f \(shellQuote(paths.sudoers))
        /bin/rm -f \(shellQuote(paths.helper))
        """
    }
}
