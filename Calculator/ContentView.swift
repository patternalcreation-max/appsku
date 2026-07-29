//
//  ContentView.swift
//  K3 Calculator
//

import SwiftUI

// MARK: - Calculator Engine

struct K3Calculator {
    enum Operation: String {
        case add = "+"
        case subtract = "−"
        case multiply = "×"
        case divide = "÷"
    }

    var display: String = "0"
    var expressionLine: String = ""

    private var leftValue: Double?
    private var pendingOp: Operation?
    private var justEvaluated = false
    private var typingNewNumber = false

    // MARK: Digit Input

    mutating func inputDigit(_ digit: String) {
        if typingNewNumber {
            display = digit
            typingNewNumber = false
        } else {
            if display == "0" {
                display = digit
            } else if display.count < 12 {
                display += digit
            }
        }
    }

    mutating func inputDecimal() {
        if typingNewNumber {
            display = "0."
            typingNewNumber = false
            return
        }
        if !display.contains(".") {
            display += "."
        }
    }

    // MARK: Actions

    mutating func clear() {
        display = "0"
        leftValue = nil
        pendingOp = nil
        expressionLine = ""
        justEvaluated = false
        typingNewNumber = false
    }

    mutating func negate() {
        if display != "0" {
            if display.hasPrefix("-") {
                display.removeFirst()
            } else {
                display = "-" + display
            }
        }
    }

    mutating func percent() {
        if let val = Double(display) {
            display = formatResult(val / 100)
            expressionLine = ""
            typingNewNumber = true
        }
    }

    // MARK: Operations

    mutating func setOperation(_ op: Operation) {
        let current = Double(display) ?? 0

        // Chain: if pending op exists, evaluate first
        if let existing = pendingOp, let left = leftValue, !typingNewNumber {
            let result = performOp(left, current, existing)
            leftValue = result
            display = formatResult(result)
        } else {
            leftValue = current
        }

        pendingOp = op
        expressionLine = "\(formatResult(leftValue!)) \(op.rawValue)"
        typingNewNumber = true
    }

    mutating func evaluate() {
        guard let op = pendingOp, let left = leftValue else { return }
        let right = Double(display) ?? 0
        let result = performOp(left, right, op)
        expressionLine = "\(formatResult(left)) \(op.rawValue) \(formatResult(right)) ="
        display = formatResult(result)
        leftValue = result
        pendingOp = nil
        justEvaluated = true
        typingNewNumber = true
    }

    // MARK: Math

    private func performOp(_ left: Double, _ right: Double, _ op: Operation) -> Double {
        switch op {
        case .add:      return left + right
        case .subtract: return left - right
        case .multiply: return left * right
        case .divide:   return right == 0 ? Double.nan : left / right
        }
    }

    private func formatResult(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "Error" }
        if value == value.rounded() && abs(value) < 1e12 {
            return String(format: "%.0f", value)
        }
        var s = String(format: "%.8f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.count > 12 ? String(s.prefix(12)) : s
    }
}

// MARK: - UI

struct ContentView: View {
    @State private var calc = K3Calculator()
    private let btn: CGFloat = 75
    private let gap: CGFloat = 12

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.06),
                         Color(red: 0.02, green: 0.02, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Display
                VStack(alignment: .trailing, spacing: 8) {
                    Text(calc.expressionLine)
                        .font(.system(size: 20, weight: .light, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(height: 24)

                    Text(calc.display)
                        .font(.system(size: 72, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)

                Spacer()

                // Buttons
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        btnView("AC", .function) { calc.clear() }
                        btnView("+/−", .function) { calc.negate() }
                        btnView("%", .function) { calc.percent() }
                        btnView("÷", .operator) { calc.setOperation(.divide) }
                    }
                    HStack(spacing: gap) {
                        btnView("7", .digit) { calc.inputDigit("7") }
                        btnView("8", .digit) { calc.inputDigit("8") }
                        btnView("9", .digit) { calc.inputDigit("9") }
                        btnView("×", .operator) { calc.setOperation(.multiply) }
                    }
                    HStack(spacing: gap) {
                        btnView("4", .digit) { calc.inputDigit("4") }
                        btnView("5", .digit) { calc.inputDigit("5") }
                        btnView("6", .digit) { calc.inputDigit("6") }
                        btnView("−", .operator) { calc.setOperation(.subtract) }
                    }
                    HStack(spacing: gap) {
                        btnView("1", .digit) { calc.inputDigit("1") }
                        btnView("2", .digit) { calc.inputDigit("2") }
                        btnView("3", .digit) { calc.inputDigit("3") }
                        btnView("+", .operator) { calc.setOperation(.add) }
                    }
                    HStack(spacing: gap) {
                        btnView("0", .digit) { calc.inputDigit("0") }
                            .frame(maxWidth: .infinity)
                        btnView(".", .digit) { calc.inputDecimal() }
                        btnView("=", .operator) { calc.evaluate() }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            }
        }
    }

    private func btnView(
        _ label: String,
        _ type: BtnType,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundColor(type.fg)
                .frame(maxWidth: .infinity, minHeight: btn, maxHeight: btn)
                .background(type.bg)
                .clipShape(RoundedRectangle(cornerRadius: btn / 2))
        }
    }
}

enum BtnType {
    case digit, function, `operator`
    var fg: Color { .white }
    var bg: Color {
        switch self {
        case .digit:    return Color(white: 0.2)
        case .function: return Color(red: 0.25, green: 0.56, blue: 0.96)
        case .operator: return Color(red: 1.0, green: 0.58, blue: 0.12)
        }
    }
}
