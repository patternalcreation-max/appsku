import SwiftUI
import UIKit

struct ApprovalReviewOverlay: View {
    let request: ApprovalRequest
    let focusDeny: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void

    @AccessibilityFocusState private var denyIsFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                K3VisualSystem.Palette.dim
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: K3VisualSystem.Space.standard) {
                            HStack(alignment: .firstTextBaseline, spacing: K3VisualSystem.Space.compact) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(K3VisualSystem.Palette.approval)
                                    .accessibilityHidden(true)
                                Text(approveLabel)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer(minLength: K3VisualSystem.Space.compact)
                            }

                            Text(request.call.tool)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            Text(request.preview)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !request.reason.isEmpty {
                                Text(request.reason)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(K3VisualSystem.Space.generous)
                    }
                    .frame(maxHeight: max(120, geometry.size.height * 0.62))

                    K3VisualSystem.Palette.separator
                        .frame(height: K3VisualSystem.Space.hairline)
                        .accessibilityHidden(true)

                    HStack(spacing: K3VisualSystem.Space.standard) {
                        Button(action: onDeny) {
                            Text("Deny")
                                .frame(maxWidth: .infinity, minHeight: K3VisualSystem.Space.control)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Deny action")
                        .accessibilityHint("Rejects this action and stops the current run")
                        .accessibilityFocused($denyIsFocused)

                        Button(action: onApprove) {
                            Text(approveLabel)
                                .frame(maxWidth: .infinity, minHeight: K3VisualSystem.Space.control)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(K3VisualSystem.Palette.interaction)
                        .accessibilityLabel(approveLabel)
                        .accessibilityHint("Authorizes only the action shown above")
                    }
                    .padding(.horizontal, K3VisualSystem.Space.generous)
                    .padding(.vertical, K3VisualSystem.Space.standard)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: geometry.size.height)
                .background(.regularMaterial)
                .overlay(alignment: .top) {
                    K3VisualSystem.Palette.approval
                        .frame(height: K3VisualSystem.Space.hairline)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Review pending browser action")
                .accessibilityAction(.escape, onDeny)
            }
        }
        .allowsHitTesting(true)
        .onAppear {
            if focusDeny {
                DispatchQueue.main.async { denyIsFocused = true }
            } else {
                UIAccessibility.post(notification: .announcement, argument: "Approval required. Review the pending browser action.")
            }
        }
        .onChange(of: focusDeny) { shouldFocus in
            if shouldFocus {
                DispatchQueue.main.async { denyIsFocused = true }
            }
        }
    }

    private var approveLabel: String {
        switch request.call.tool {
        case "click_selector": return "Click once"
        case "fill_selector": return "Fill once"
        case "select_option": return "Select once"
        case "submit_form": return "Submit once"
        case "open_url": return "Open once"
        case "back": return "Go back once"
        case "forward": return "Go forward once"
        case "reload": return "Reload once"
        case "scroll": return "Scroll once"
        case "export_markdown", "export_json", "export_csv": return "Export once"
        default: return "Run once"
        }
    }
}
