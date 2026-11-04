import SwiftUI
import UIKit

/// Grid of all selectable app icons. Changing the icon always shows a system alert ("Symbol geändert"); iOS offers no way to suppress it.
struct IconPickerView: View {
    @State private var selected = AppIconOption.option(forAlternateIconName: UIApplication.shared.alternateIconName)
    @State private var errorMessage: String?
    @State private var busy = false

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(AppIconOption.all) { option in
                    Button { choose(option) } label: { cell(option) }
                        .buttonStyle(.plain)
                        .disabled(busy || !UIApplication.shared.supportsAlternateIcons)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(option.name())
                        .accessibilityValue(option.detail())
                        .accessibilityHint(selected == option ? "" : "Als App-Symbol festlegen")
                        .accessibilityAddTraits(selected == option ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("icon-option-\(option.id)")
                }
            }
            .padding()
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange).padding(.horizontal)
                    .accessibilityIdentifier("icon-picker-error")
            }
            Text("Das System bestätigt jeden Wechsel mit einem Hinweis. Auf der Apple Watch bleibt das Standard-Symbol; Widgets sind nicht betroffen.")
                .font(.footnote).foregroundStyle(.secondary).padding()
                .accessibilityIdentifier("icon-picker-footer")
        }
        .navigationTitle("App-Symbol")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cell(_ option: AppIconOption) -> some View {
        VStack(spacing: 6) {
            Image(option.previewAssetName)
                .resizable().aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(selected == option ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected == option ? 4 : 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if selected == option {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette).foregroundStyle(.white, Color.accentColor)
                            .font(.title3).padding(4)
                    }
                }
            Text(option.name()).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func choose(_ option: AppIconOption) {
        guard option != selected, UIApplication.shared.supportsAlternateIcons else { return }
        busy = true
        errorMessage = nil
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            Task { @MainActor in
                busy = false
                if let error {
                    errorMessage = "Das Symbol konnte nicht gewechselt werden: \(error.localizedDescription)"
                } else {
                    selected = option
                }
            }
        }
    }
}
