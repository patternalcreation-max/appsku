import SwiftUI

struct BrowserChromeView: View {
    @Binding var address: String
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let estimatedProgress: Double
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onStop: () -> Void
    let onSubmitAddress: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: K3VisualSystem.Space.compact) {
                chromeButton("chevron.left", label: "Back", enabled: canGoBack, action: onBack)
                chromeButton("chevron.right", label: "Forward", enabled: canGoForward, action: onForward)

                TextField("Search or enter website", text: $address, onCommit: onSubmitAddress)
                    .keyboardType(.webSearch)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.go)
                    .padding(.horizontal, K3VisualSystem.Space.standard)
                    .frame(minHeight: K3VisualSystem.Space.control)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: K3VisualSystem.Space.standard, style: .continuous))
                    .accessibilityLabel("Search or website address")

                if isLoading {
                    chromeButton("xmark", label: "Stop loading", enabled: true, action: onStop)
                } else {
                    chromeButton("arrow.clockwise", label: "Reload", enabled: true, action: onReload)
                }
            }
            .padding(.horizontal, K3VisualSystem.Space.compact)
            .padding(.vertical, K3VisualSystem.Space.compact)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    K3VisualSystem.Palette.separator
                    K3VisualSystem.Palette.interaction
                        .frame(width: geometry.size.width * CGFloat(min(max(estimatedProgress, 0), 1)))
                        .opacity(isLoading ? 1 : 0)
                }
            }
            .frame(height: K3VisualSystem.Space.progress)
            .accessibilityHidden(true)
        }
        .background(K3VisualSystem.Palette.rail)
    }

    private func chromeButton(
        _ symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: K3VisualSystem.Space.control, height: K3VisualSystem.Space.control)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
