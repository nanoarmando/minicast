import Foundation

@main
struct SettingsBackupTest {
    static func main() {
        var failures = 0

        func check(_ description: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                print("PASS  \(description)")
            } else {
                print("FAIL  \(description)")
                failures += 1
            }
        }

        // Offenders go in the description so a failure names the key rather than just the rule.
        func naming(_ rule: String, _ offenders: [String]) -> String {
            offenders.isEmpty ? rule : "\(rule) — \(offenders.sorted().joined(separator: ", "))"
        }

        let mirrored = SettingsBackupCoverage.mirrored
        let excluded = SettingsBackupCoverage.deliberatelyExcluded
        let external = SettingsBackupCoverage.externallySourced
        let capabilities = SettingsBackupCoverage.capabilities
        let elsewhere = SettingsBackupCoverage.carriedElsewhere
        let allKeys = AppSettingsKey.allCases.map(\.rawValue)
        let mirroredKeys = mirrored.values.map(\.rawValue)
        let capabilityKeys = capabilities.values.map(\.rawValue)

        // Exactly one bucket per key: mirrored, capability, another part, or machine-local.
        let buckets = [Set(mirroredKeys), Set(capabilityKeys), Set(elsewhere.keys), Set(excluded.keys)]
        let uncovered = allKeys.filter { key in !buckets.contains { $0.contains(key) } }
        check(naming("every AppSettings key sits in a declared bucket", uncovered), uncovered.isEmpty)
        let doubled = allKeys.filter { key in buckets.filter { $0.contains(key) }.count > 1 }
        check(naming("no key sits in two buckets", doubled), doubled.isEmpty)

        let unknownElsewhere = elsewhere.keys.filter { AppSettingsKey(rawValue: $0) == nil }
        check(
            naming("every key carried elsewhere is a real key", Array(unknownElsewhere)),
            unknownElsewhere.isEmpty)
        check(
            "seven capability switches are declared",
            Set(capabilityKeys) == Set([
                AppSettingsKey.extensionsEnabled, .mcpEnabled, .aiEnabled, .quickActionsEnabled,
                .calendarEnabled, .autoJoinMeetings, .clipboardTextSearchEnabled
            ].map(\.rawValue)))
        let machineLocal: [AppSettingsKey] = [
            .palettePosition, .paletteExpandedCenterDisplays, .extensionPackageManager,
            .extensionCustomSearchPaths, .autoSwitchInputSource, .meetingBrowser,
            .settingsFileEnabled
        ]
        check(
            "only machine-local keys are excluded",
            Set(excluded.keys) == Set(machineLocal.map(\.rawValue)))

        let unknownExclusions = excluded.keys.filter { AppSettingsKey(rawValue: $0) == nil }
        check(
            naming("every excluded key names a real AppSettings key", Array(unknownExclusions)),
            unknownExclusions.isEmpty)

        let doubleClaimed = Dictionary(grouping: mirroredKeys, by: { $0 })
            .filter { $0.value.count > 1 }.keys
        check(
            naming("no two backup fields claim the same key", Array(doubleClaimed)),
            doubleClaimed.isEmpty)
        check(
            "fileSearchEnabled rides the settings backup",
            mirrored["fileSearchEnabled"] == .fileSearchEnabled)
        check(
            "file search scopes ride the settings backup",
            mirrored["fileSearchScopes"] == .fileSearchScopes)
        check(
            "user ignore patterns ride the settings backup",
            mirrored["fileSearchIgnorePatterns"] == .fileSearchIgnorePatterns)
        check(
            "clipboard enablement rides the settings backup",
            mirrored["clipboardEnabled"] == .clipboardEnabled)
        check(
            "emoji grid density rides the settings backup",
            mirrored["emojiGridColumns"] == .emojiGridColumns)

        // A capability rides the bundle but never the settings mirror the import applies directly.
        for key in capabilityKeys {
            check("\(key) is not mirrored", !mirroredKeys.contains(key))
        }

        // A reason that only echoes the key name explains nothing, so it fails like a missing one.
        let emptyReasons = excluded.filter { key, reason in
            let trimmed = reason.trimmingCharacters(in: .whitespaces)
            return trimmed.count <= key.count || !trimmed.contains(" ")
        }.keys
        check(
            naming("every exclusion carries a real reason", Array(emptyReasons)),
            emptyReasons.isEmpty)

        let claimedTwice = external.keys.filter { mirrored[$0] != nil }
        check(
            naming("no field is both mirrored and externally sourced", Array(claimedTwice)),
            claimedTwice.isEmpty)

        let notActuallyExternal = external.keys.filter { AppSettingsKey(rawValue: $0) != nil }
        check(
            naming("externally sourced fields have no AppSettings key", Array(notActuallyExternal)),
            notActuallyExternal.isEmpty)

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
