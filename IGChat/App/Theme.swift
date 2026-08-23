import SwiftUI

enum Theme {
    static let black = Color(red: 0, green: 0, blue: 0)
    static let bubbleGray = Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0)
    static let igBlue = Color(red: 0x00 / 255.0, green: 0x95 / 255.0, blue: 0xF6 / 255.0)
    static let secondaryText = Color(red: 0xA8 / 255.0, green: 0xA8 / 255.0, blue: 0xA8 / 255.0)
    static let dateText = Color(red: 0x73 / 255.0, green: 0x73 / 255.0, blue: 0x73 / 255.0)
    static let linkPale = Color(red: 0xE0 / 255.0, green: 0xF1 / 255.0, blue: 0xFF / 255.0)
    static let headerBorder = Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0)
    static let batteryBorder = Color.white.opacity(0.4)
    static let gradientStart = Color(red: 0x81 / 255.0, green: 0x34 / 255.0, blue: 0xAF / 255.0)
    static let gradientEnd = Color(red: 0x51 / 255.0, green: 0x58 / 255.0, blue: 0xDF / 255.0)

    static let bubbleGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

    // Operator chat bar art (Untitled.svg)
    static let barPill = Color(red: 29/255.0, green: 30/255.0, blue: 32/255.0)
    static let barPurple = Color(red: 84/255.0, green: 83/255.0, blue: 254/255.0)
    static let barMessageText = Color(red: 164/255.0, green: 168/255.0, blue: 179/255.0)
