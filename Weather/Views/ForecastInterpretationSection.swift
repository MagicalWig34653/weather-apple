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
                Text("Einordnung").font(.headline)
                Text(interpretation.renderedSnapshot == snapshot ? (interpretation.text ?? snapshot.fallback) : snapshot.fallback)
                if snapshot.facts.count > 1 {
                    Button {
                        request = Task { await interpretation.interpret(snapshot) }
                    } label: {
                        HStack {
                            if interpretation.isGenerating { ProgressView() }
                            Text(interpretation.isGenerating ? "Wird lokal eingeordnet …" : "Lokal einordnen")
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(interpretation.isGenerating)
                    .accessibilityHint("Apple Intelligence gewichtet vorhandene Wetterfakten auf diesem Gerät")
                }
                if interpretation.usedModel && interpretation.renderedSnapshot == snapshot {
                    Text("Lokal mit Apple Intelligence").font(.caption).foregroundStyle(.secondary)
                }
                if let notice = interpretation.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }
                Text("Einordnung vorhandener Radardaten; keine zusätzliche Vorhersage oder amtliche Warnung.")
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
