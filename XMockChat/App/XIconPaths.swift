import SwiftUI

// MARK: - Built-in icon path constants
// Tab icons: x.com operator SVGs. Verified/voice/call icons: instagram.com operator SVGs.
// All paths byte-exact, tokenizer-verified (numbers match regex reference 1:1).

enum XIconPaths {
    static let homePath = "M20 9.838c0-.502-.25-.97-.668-1.248l-6.5-4.333c-.504-.336-1.16-.336-1.664 0l-6.5 4.333C4.251 8.868 4 9.336 4 9.838V18.5c0 .828.672 1.5 1.5 1.5h3v-3.5c0-1.933 1.567-3.5 3.5-3.5s3.5 1.567 3.5 3.5V20h3c.828 0 1.5-.672 1.5-1.5V9.838zm2 8.662c0 1.933-1.567 3.5-3.5 3.5h-5v-5.5c0-.829-.672-1.5-1.5-1.5s-1.5.671-1.5 1.5V22h-5C3.567 22 2 20.433 2 18.5V9.838c0-1.17.585-2.263 1.559-2.912l6.5-4.333c1.175-.784 2.707-.784 3.882 0l6.5 4.333C21.415 7.575 22 8.668 22 9.838V18.5z"
    static let homeViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
    static let searchPath = "M10.25 3.75c-3.59 0-6.5 2.91-6.5 6.5s2.91 6.5 6.5 6.5c1.795 0 3.419-.726 4.596-1.904 1.178-1.177 1.904-2.801 1.904-4.596 0-3.59-2.91-6.5-6.5-6.5zm-8.5 6.5c0-4.694 3.806-8.5 8.5-8.5s8.5 3.806 8.5 8.5c0 1.986-.682 3.815-1.824 5.262l4.781 4.781-1.414 1.414-4.781-4.781c-1.447 1.142-3.276 1.824-5.262 1.824-4.694 0-8.5-3.806-8.5-8.5z"
    static let searchViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
    static let grokPath = "M12.745 20.54l10.97-8.19c.539-.4 1.307-.244 1.564.38 1.349 3.288.746 7.241-1.938 9.955-2.683 2.714-6.417 3.31-9.83 1.954l-3.728 1.745c5.347 3.697 11.84 2.782 15.898-1.324 3.219-3.255 4.216-7.692 3.284-11.693l.008.009c-1.351-5.878.332-8.227 3.782-13.031L33 0l-4.54 4.59v-.014L12.743 20.544m-2.263 1.987c-3.837-3.707-3.175-9.446.1-12.755 2.42-2.449 6.388-3.448 9.852-1.979l3.72-1.737c-.67-.49-1.53-1.017-2.515-1.387-4.455-1.854-9.789-.931-13.41 2.728-3.483 3.523-4.579 8.94-2.697 13.561 1.405 3.454-.899 5.898-3.22 8.364C1.49 30.2.666 31.074 0 32l10.478-9.466"
    static let grokViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
    static let bellPath = "M19.993 9.042C19.48 5.017 16.054 2 11.996 2s-7.49 3.021-7.999 7.051L2.866 18H7.1c.463 2.282 2.481 4 4.9 4s4.437-1.718 4.9-4h4.236l-1.143-8.958zM12 20c-1.306 0-2.417-.835-2.829-2h5.658c-.412 1.165-1.523 2-2.829 2zm-6.866-4l.847-6.698C6.364 6.272 8.941 4 11.996 4s5.627 2.268 6.013 5.295L18.864 16H5.134z"
    static let bellViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
    static let mailPath = "M12.001 1.5c5.858 0 10.7 4.518 10.7 10.2-.001 5.683-4.842 10.2-10.7 10.2-1.785 0-2.96-.555-3.95-1.095-1.876.768-4.02 1.2-6.245-.075l-.885-.505.523-.875c.54-.904.77-1.581.849-2.118.077-.526.02-.98-.11-1.463-.066-.25-.15-.502-.247-.788-.095-.277-.204-.59-.301-.92-.2-.674-.36-1.449-.332-2.39C1.319 6.002 6.153 1.5 12 1.5z"
    static let mailViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)

    static let verifiedPath = "M19.998 3.094 14.638 0l-2.972 5.15H5.432v6.354L0 14.64 3.094 20 0 25.359l5.432 3.137v5.905h5.975L14.638 40l5.36-3.094L25.358 40l3.232-5.6h6.162v-6.01L40 25.359 36.905 20 40 14.641l-5.248-3.03v-6.46h-6.419L25.358 0l-5.36 3.094Zm7.415 11.225 2.254 2.287-11.43 11.5-6.835-6.93 2.244-2.258 4.587 4.581 9.18-9.18Z"
    static let verifiedViewBox = CGRect(x: 0, y: 0, width: 40, height: 40)

    static let voicePath = "M19.5 10.671v.897a7.5 7.5 0 0 1-15 0v-.897"
    static let voiceViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)

    static let audioCallPath = "M18.227 22.912c-4.913 0-9.286-3.627-11.486-5.828C4.486 14.83.731 10.291.921 5.231a3.289 3.289 0 0 1 .908-2.138 17.116 17.116 0 0 1 1.865-1.71 2.307 2.307 0 0 1 3.004.174 13.283 13.283 0 0 1 3.658 5.325 2.551 2.551 0 0 1-.19 1.941l-.455.853a.463.463 0 0 0-.024.387 7.57 7.57 0 0 0 4.077 4.075.455.455 0 0 0 .386-.024l.853-.455a2.548 2.548 0 0 1 1.94-.19 13.278 13.278 0 0 1 5.326 3.658 2.309 2.309 0 0 1 .174 3.003 17.319 17.319 0 0 1-1.71 1.866 3.29 3.29 0 0 1-2.138.91 10.27 10.27 0 0 1-.368.006Zm-13.144-20a.27.27 0 0 0-.167.054A15.121 15.121 0 0 0 3.28 4.47a1.289 1.289 0 0 0-.36.836c-.161 4.301 3.21 8.34 5.235 10.364s6.06 5.403 10.366 5.236a1.284 1.284 0 0 0 .835-.36 15.217 15.217 0 0 0 1.504-1.637.324.324 0 0 0-.047-.41 11.62 11.62 0 0 0-4.457-3.119.545.545 0 0 0-.411.044l-.854.455a2.452 2.452 0 0 1-2.071.116 9.571 9.571 0 0 1-5.189-5.188 2.457 2.457 0 0 1 .115-2.071l.456-.855a.544.544 0 0 0 .043-.41 11.629 11.629 0 0 0-3.118-4.458.36.36 0 0 0-.244-.1Z"
    static let audioCallViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)

    static let videoCallPath = "m17.999 9.146 2.495-2.256A1.5 1.5 0 0 1 23 8.003v7.994a1.5 1.5 0 0 1-2.506 1.113L18 14.854"
    static let videoCallViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)

    static let backArrowPath = "M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"
    static let backArrowViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)
}

// MARK: - Preset library (shown in icon picker)

struct IconPreset: Identifiable {
    let id: String
    let name: String
    let path: String
    let vbW: Double
    let vbH: Double
}

enum IconPresets {
    static let all: [IconPreset] = [
        IconPreset(id: "verified.default", name: "Verified (IG default)", path: XIconPaths.verifiedPath, vbW: 40, vbH: 40),
        IconPreset(id: "voice.wave", name: "Voice waveform", path: XIconPaths.voicePath, vbW: 24, vbH: 24),
        IconPreset(id: "call.audio", name: "Audio call", path: XIconPaths.audioCallPath, vbW: 24, vbH: 24),
        IconPreset(id: "call.video", name: "Video call", path: XIconPaths.videoCallPath, vbW: 24, vbH: 24),
        IconPreset(id: "arrow.back", name: "Back arrow", path: XIconPaths.backArrowPath, vbW: 24, vbH: 24),
        IconPreset(id: "tab.home", name: "Home", path: XIconPaths.homePath, vbW: 24, vbH: 24),
        IconPreset(id: "tab.search", name: "Search", path: XIconPaths.searchPath, vbW: 24, vbH: 24),
        IconPreset(id: "tab.grok", name: "Grok", path: XIconPaths.grokPath, vbW: 33, vbH: 32),
        IconPreset(id: "tab.bell", name: "Bell", path: XIconPaths.bellPath, vbW: 24, vbH: 24),
        IconPreset(id: "tab.mail", name: "Mail", path: XIconPaths.mailPath, vbW: 24, vbH: 24),
    ]
}
