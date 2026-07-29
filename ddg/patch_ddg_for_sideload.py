#!/usr/bin/env python3
"""Patch duckduckgo/apple-browsers for public unsigned sideload builds.

Applied inside a freshly checked-out upstream repo by GitHub Actions.
- Removes private DuckSansFont Swift package references.
- Leaves app code intact; DDG falls back to system font.
"""
from pathlib import Path
import re
import shutil

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

# DDG's Copy GRDB framework phase always codesigns the copied framework. In an
# unsigned sideload build EXPANDED_CODE_SIGN_IDENTITY is empty, causing keychain
# lookup failure. Patch the generated shell script text in project.pbxproj to
# copy GRDB but skip codesign when no identity is present.
grdb_pattern = r'# Sign the framework directory contents.*?--generate-entitlement-der.*?\\\\n'
grdb_replacement = '# Sign the framework directory contents skipped for unsigned sideload build\\necho \\\"Skipping GRDB codesign for unsigned sideload build\\\"\\n'
s2, grdb_count = re.subn(grdb_pattern, grdb_replacement, s, count=1, flags=re.S)
if grdb_count:
    s = s2
    print("Patched GRDB framework codesign phase for unsigned build")
else:
    missing.append("GRDB codesign shell phase")

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

# Network.NWError.wifiAware is also newer than Xcode 16.4's Network framework.
vpn_leak = Path("SharedPackages/VPN/Sources/VPN/LeakCheck/VPNLeakCheckService.swift")
if vpn_leak.exists():
    t = vpn_leak.read_text()
    t2 = t.replace("            case .wifiAware:\n                return false\n", "")
    if t2 != t:
        vpn_leak.write_text(t2)
        print(f"Patched unavailable NWError.wifiAware case in {vpn_leak}")

# BGContinuedProcessingTask is iOS 26 SDK-only. For a sideload browser build on
# Xcode 16.4, disable that optional background flow with a no-op coordinator.
continued = Path("iOS/LocalPackages/DataBrokerProtection-iOS/Sources/DataBrokerProtection-iOS/ManagingAndCoordinating/ContinuedProcessing/DBPContinuedProcessingCoordinator.swift")
if continued.exists():
    continued.write_text('''//
//  DBPContinuedProcessingCoordinator.swift
//  Patched for external sideload build on Xcode 16.x: iOS 26 continued
//  processing BackgroundTasks APIs are unavailable in this SDK.
//

import DataBrokerProtectionCore
import Foundation

protocol DBPContinuedProcessingDelegate: AnyObject {
    func coordinatorDidStartRun()
    func coordinatorDidFinishRun()
    func coordinatorIsReadyForScanOperations() async
    func coordinatorIsReadyForOptOutOperations()
    func coordinatorDidRequestStopOperations()
    func continuedProcessingScanJobTimeout() -> TimeInterval
    func makeContinuedProcessingOptOutPlan() throws -> DBPContinuedProcessingPlans.OptOutPlan
}

enum DBPContinuedProcessingEvent {
    case scanJobCompleted(DBPContinuedProcessingPlans.ScanJobID)
    case optOutJobCompleted(DBPContinuedProcessingPlans.OptOutJobID)
    case scanPhaseCompleted
    case optOutPhaseCompleted
}

protocol DBPContinuedProcessingCoordinating: AnyObject, Sendable {
    func hasAttachedTask() async -> Bool
    func startInitialRun(scanPlan: DBPContinuedProcessingPlans.InitialScanPlan) async throws
    func didEmit(event: DBPContinuedProcessingEvent) async
}

@available(iOS 26.0, *)
actor DBPContinuedProcessingCoordinator: DBPContinuedProcessingCoordinating {
    init(delegate: DBPContinuedProcessingDelegate,
         progressReporter: DBPContinuedProcessingProgressReporter? = nil) {}

    func hasAttachedTask() async -> Bool { false }

    func startInitialRun(scanPlan: DBPContinuedProcessingPlans.InitialScanPlan) async throws {
        // No-op for external sideload builds compiled with pre-iOS-26 SDKs.
    }

    func didEmit(event: DBPContinuedProcessingEvent) async {
        // No-op.
    }
}
''')
    print(f"Replaced iOS 26 BGContinuedProcessing coordinator with no-op stub in {continued}")

# Xcode 16.4 actool only supports symbol template format 6.0; DDG main has
# iOS 26 Control Center symbolsets using format 7.0. Remove them so the widget
# asset catalog can compile on GitHub's public macos-15 runner.
for rel in [
    "iOS/Widgets/SharedWidgetAssets.xcassets/ControlCenter/AIVoiceChat-Symbol.symbolset",
]:
    p = Path(rel)
    if p.exists():
        shutil.rmtree(p)
        print(f"Removed unsupported Xcode 16 asset symbolset: {p}")

# DDG main pins a future Xcode in .xcode-version and fails the app target
# late in the build via scripts/assert_xcode_version.sh. For this external
# sideload build we intentionally use GitHub's public macos-15 Xcode 16.4.
for xcode_version_file in [Path(".xcode-version"), Path("iOS/.xcode-version")]:
    if xcode_version_file.exists():
        xcode_version_file.write_text("16.4\n")
        print(f"Pinned DDG Xcode gate to GitHub runner version in {xcode_version_file}")



# v0.4.2-canary: probe-only isolate build.
# No native UI/button/alert. This only attaches a tiny WKUserScript probe so we
# can tell whether launch crashes are from the UI overlay or from script injection.
tab = Path("iOS/DuckDuckGo/TabViewController.swift")
if tab.exists():
    t = tab.read_text()
    if "installDDGSuperAgentProbeOnly" not in t:
        t = t.replace(
            "        configuration.userContentController = userContentController\n        userContentController.delegate = self\n",
            "        configuration.userContentController = userContentController\n"
            "        userContentController.delegate = self\n"
            "        installDDGSuperAgentProbeOnly(on: userContentController)\n"
        )
        marker = "\n    private func addObservers() {\n"
        native = r'''

    private func installDDGSuperAgentProbeOnly(on userContentController: WKUserContentController) {
        let source = """
        (function() {
            window.__DDG_SUPERAGENT_NATIVE_PROBE__ = {
                version: "0.4.2-probe-only",
                ok: true,
                href: location.href
            };
        })();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(script)
    }
'''
        t = t.replace(marker, native + marker)
        tab.write_text(t)
        print(f"Injected DDG probe-only canary into {tab}")
    else:
        print("DDG probe-only canary already present")

print(f"Patched {pbx}: removed DuckSansFont references")
if missing:
    print("Non-fatal missing patterns, upstream may have changed:")
    for m in missing:
        print(f"  - {m[:80]}...")
