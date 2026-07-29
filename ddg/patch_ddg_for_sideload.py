#!/usr/bin/env python3
"""Patch duckduckgo/apple-browsers for public unsigned sideload builds.

Applied inside a freshly checked-out upstream repo by GitHub Actions.
- Removes private DuckSansFont Swift package references.
- Leaves app code intact; DDG falls back to system font.
"""
from pathlib import Path

pbx = Path("iOS/DuckDuckGo-iOS.xcodeproj/project.pbxproj")
s = pbx.read_text()

replacements = {
    '\t\t9FADFC4A2F5FC56400CA16F7 /* DuckSansFont in Frameworks */ = {isa = PBXBuildFile; productRef = 9FADFC492F5FC56400CA16F7 /* DuckSansFont */; };\n': '',
    '\t\t\t\t9FADFC4A2F5FC56400CA16F7 /* DuckSansFont in Frameworks */,\n': '',
    '\t\t\t\t9FADFC492F5FC56400CA16F7 /* DuckSansFont */,\n': '',
    '''\t\t9FADFC482F5FC56400CA16F7 /* XCRemoteSwiftPackageReference "native-apps-ducksans" */ = {
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "git@github.com:duckduckgo/native-apps-ducksans.git";
\t\t\trequirement = {
\t\t\t\tkind = exactVersion;
\t\t\t\tversion = 1.0.0;
\t\t\t};
\t\t};
''': '',
    '''\t\t9FADFC492F5FC56400CA16F7 /* DuckSansFont */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = 9FADFC482F5FC56400CA16F7 /* XCRemoteSwiftPackageReference "native-apps-ducksans" */;
\t\t\tproductName = DuckSansFont;
\t\t};
''': '',
    '\t\t\t\t9FADFC482F5FC56400CA16F7 /* XCRemoteSwiftPackageReference "native-apps-ducksans" */,\n': '',
}

missing = []
for old, new in replacements.items():
    if old not in s:
        missing.append(old.splitlines()[0])
    s = s.replace(old, new)

pbx.write_text(s)

if "DuckSansFont" in s or "native-apps-ducksans" in s:
    raise SystemExit("DuckSans removal incomplete")

# Xcode can still read stale pins from Package.resolved and try to resolve the
# removed private SSH package. Delete it so Package.resolved is regenerated from
# the patched packageReferences list.
resolved = Path("iOS/DuckDuckGo-iOS.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
if resolved.exists():
    text = resolved.read_text(errors="ignore")
    if "native-apps-ducksans" in text or "git@github.com:duckduckgo/native-apps-ducksans.git" in text:
        resolved.unlink()
        print(f"Deleted stale private SwiftPM lockfile: {resolved}")

# Current DDG main references a WebKit constant that exists only in newer SDKs.
# GitHub macos-15 currently exposes Xcode 16.4 / iPhoneOS 18.5, so the symbol is
# unavailable at compile time. WKWebsiteDataStore data type constants are String
# values; keep the same runtime value without requiring the SDK symbol.
screen_time_cleaner = Path("SharedPackages/ScreenTimeDataCleaner/Sources/ScreenTimeDataCleaner/ScreenTimeDataCleaner.swift")
if screen_time_cleaner.exists():
    t = screen_time_cleaner.read_text()
    t2 = t.replace("WKWebsiteDataTypeScreenTime", '"WKWebsiteDataTypeScreenTime"')
    if t2 != t:
        screen_time_cleaner.write_text(t2)
        print(f"Patched unavailable SDK symbol in {screen_time_cleaner}")

# DDG main also uses iOS 26 SwiftUI glass button style. Xcode 16.4's SwiftUI
# module does not expose it yet, and Swift still type-checks the available branch.
sync_success = Path("iOS/LocalPackages/SyncUI-iOS/Sources/SyncUI-iOS/Views/SyncSuccessViewV2.swift")
if sync_success.exists():
    t = sync_success.read_text()
    t2 = t.replace(".buttonStyle(.glassProminent)", ".buttonStyle(.plain)")
    if t2 != t:
        sync_success.write_text(t2)
        print(f"Patched unavailable SwiftUI glass style in {sync_success}")

print(f"Patched {pbx}: removed DuckSansFont references")
if missing:
    print("Non-fatal missing patterns, upstream may have changed:")
    for m in missing:
        print("  -", m)
