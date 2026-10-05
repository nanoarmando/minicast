import Foundation

/// Version parsing, release selection and the places a copy of Minicast may update itself from.
@main
struct UpdatesTests {
    nonisolated(unsafe) static var failures = 0
    nonisolated(unsafe) static var passes = 0

    static func main() {
        versions()
        releases()
        eligibility()

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        print("\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    static func versions() {
        print("\n# versions")
        check("parses three numbers", AppVersion("0.2.10") == AppVersion(major: 0, minor: 2, patch: 10))
        check("compares numerically, not as text", AppVersion("0.2.10")! > AppVersion("0.2.9")!)
        check("0.2.10 follows 0.2.1", AppVersion("0.2.10")! > AppVersion("0.2.1")!)
        check("major outranks minor", AppVersion("1.0.0")! > AppVersion("0.9.9")!)
        check("equal versions are equal", AppVersion("0.2.1") == AppVersion("0.2.1"))
        for malformed in ["", "0.2", "0.2.1.4", "v0.2.1", "0.2.x", "0..1", "0.2.1-beta", " 0.2.1", "0.2.٣"] {
            check("rejects \"\(malformed)\"", AppVersion(malformed) == nil)
        }
        check("prints back as text", AppVersion("1.2.3")?.description == "1.2.3")
    }

    static func releases() {
        print("\n# releases")
        let current = AppVersion("0.2.1")!
        let newer = release(tag: "minicast-v0.2.10", assets: ["Minicast-0.2.10.dmg", "notes.txt"])
        guard case .available(let update) = newer?.outcome(comparedTo: current) else {
            check("a newer release is available", false)
            return
        }
        check("a newer release is available", update.version == AppVersion("0.2.10"))
        check("the DMG matching the tag is picked", update.downloadURL.lastPathComponent == "Minicast-0.2.10.dmg")
        check("the notes are carried", update.notes == "Fixes")
        check("the release page is carried", update.pageURL.absoluteString.hasSuffix("minicast-v0.2.10"))

        check(
            "the same version is up to date",
            release(tag: "minicast-v0.2.1", assets: ["Minicast-0.2.1.dmg"])?.outcome(comparedTo: current) == .upToDate)
        check(
            "an older version is up to date",
            release(tag: "minicast-v0.2.0", assets: ["Minicast-0.2.0.dmg"])?.outcome(comparedTo: current) == .upToDate)
        check(
            "a missing DMG is unusable",
            release(tag: "minicast-v0.3.0", assets: ["Minicast-0.2.9.dmg"])?.outcome(comparedTo: current) == .unusable)
        check(
            "a malformed tag is unusable",
            release(tag: "v0.3.0", assets: ["Minicast-0.3.0.dmg"])?.outcome(comparedTo: current) == .unusable)
        check(
            "an upstream tag is unusable",
            release(tag: "tinycast-v9.0.0", assets: ["Minicast-9.0.0.dmg"])?.outcome(comparedTo: current) == .unusable)

        let noBody = Data(#"{"tag_name":"minicast-v1.0.0","html_url":"https://github.com/x","body":null}"#.utf8)
        let decoded = try? JSONDecoder().decode(UpdateRelease.self, from: noBody)
        check("a null body and no assets still decode", decoded?.notes == "" && decoded?.assets.isEmpty == true)
        check(
            "an answer without a tag does not decode",
            (try? JSONDecoder().decode(UpdateRelease.self, from: Data(#"{"message":"Not Found"}"#.utf8))) == nil)
    }

    static func eligibility() {
        print("\n# eligibility")
        func evaluate(_ id: String?, _ path: String, writable: Bool = true) -> UpdateEligibility {
            UpdateEligibility.evaluate(bundleIdentifier: id, bundlePath: path, isParentWritable: writable)
        }
        check("an installed release is eligible", evaluate("com.minicast.app", "/Applications/Minicast.app") == .eligible)
        check(
            "the dev channel is refused",
            evaluate("com.minicast.app.dev", "/Applications/Minicast Dev.app") == .developmentBuild)
        check("a missing bundle id is refused", evaluate(nil, "/Applications/Minicast.app") == .developmentBuild)
        check("upstream Tinycast is refused", evaluate("com.tinycast.app", "/Applications/Tinycast.app") == .developmentBuild)
        check(
            "a mounted disk image is refused",
            evaluate("com.minicast.app", "/Volumes/Minicast/Minicast.app") == .notInApplications)
        check(
            "a translocated copy is refused",
            evaluate("com.minicast.app", "/private/var/folders/x/AppTranslocation/ABC/d/Minicast.app")
                == .notInApplications)
        check(
            "a read-only folder is refused",
            evaluate("com.minicast.app", "/Applications/Minicast.app", writable: false) == .readOnlyLocation)
        check("a refusal explains itself", UpdateEligibility.developmentBuild.refusal?.contains("release build") == true)
        check("eligible has no refusal", UpdateEligibility.eligible.refusal == nil)
    }

    // MARK: - Helpers

    static func release(tag: String, assets: [String]) -> UpdateRelease? {
        let assetJSON = assets.map {
            #"{"name":"\#($0)","browser_download_url":"https://github.com/nanoarmando/minicast/releases/download/\#(tag)/\#($0)"}"#
        }.joined(separator: ",")
        let json = #"""
            {"tag_name":"\#(tag)","body":"Fixes","draft":false,"prerelease":false,
             "html_url":"https://github.com/nanoarmando/minicast/releases/tag/\#(tag)","assets":[\#(assetJSON)]}
            """#
        return try? JSONDecoder().decode(UpdateRelease.self, from: Data(json.utf8))
    }

    static func check(_ description: String, _ condition: Bool) {
        if condition {
            passes += 1
            print("PASS  \(description)")
        } else {
            failures += 1
            print("FAIL  \(description)")
        }
    }
}
