import SwiftUI

struct ForecastInterpretationSection: View {
    let forecast: RainForecast
    let hasCurrentError: Bool
    @State private var interpretation = ForecastInterpretation()
    @State private var request: Task<Void, Never>?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let snapshot = InterpretationSnapshot(forecast: forecast, hasCurrentError: hasCurrentError, now: context.date)
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey("INTERP_TITLE")).font(.headline)
                Text(interpretation.renderedSnapshot == snapshot ? (interpretation.text ?? snapshot.fallback) : snapshot.fallback)
                if snapshot.facts.count > 1 {
                    Button {
                        request = Task { await interpretation.interpret(snapshot) }
                    } label: {
                        HStack {
                            if interpretation.isGenerating { ProgressView() }
                            Text(LocalizedStringKey(interpretation.isGenerating ? "INTERP_BUTTON_BUSY" : "INTERP_BUTTON"))
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(interpretation.isGenerating)
                    .accessibilityHint(Text("INTERP_BUTTON_HINT"))
                }
                if interpretation.usedModel && interpretation.renderedSnapshot == snapshot {
                    Text("INTERP_BADGE").font(.caption).foregroundStyle(.secondary)
                }
                if let notice = interpretation.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }
                Text("INTERP_DISCLAIMER")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .onChange(of: snapshot) { _, _ in
                request?.cancel()
                interpretation.reset()
            }
        }
        .onDisappear {
            request?.cancel()
            interpretation.reset()
        }
    }
}
