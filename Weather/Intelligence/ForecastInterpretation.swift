import Foundation
import FoundationModels
import Observation

@Generable
enum ForecastFact: String, CaseIterable, Hashable, Sendable {
    case dry, rain, mixed, changingIntensity

    var text: String {
        switch self {
        case .dry: "Die verbleibenden Radardaten zeigen keinen messbaren Regen."
        case .rain: "Die verbleibenden Radardaten enthalten Regen."
        case .mixed: "Regen und Intervalle ohne messbaren Regen wechseln sich im Verlauf ab."
        case .changingIntensity: "Die Regenintensität unterscheidet sich im Verlauf deutlich."
        }
    }
}

@Generable
struct ForecastFactSelection {
    @Guide(description: "Ein oder zwei unterschiedliche IDs aus den vorgegebenen zulässigen Fakten.", .count(1...2))
    var facts: [ForecastFact]
}

struct InterpretationSnapshot: Hashable, Sendable {
    struct Sample: Hashable, Sendable {
        let date: Date
        let amount: Double?
    }
    let reference: Date
    let samples: [Sample]
    let remainingDates: [Date]
    let facts: [ForecastFact]
    let fallback: String

    init(forecast: RainForecast, hasCurrentError: Bool, now: Date) {
        reference = forecast.referenceTime
        samples = forecast.samples.map { Sample(date: $0.date, amount: $0.amountMM) }
        let remaining = forecast.samples.filter { $0.date >= now }
        remainingDates = remaining.map(\.date)
        var valid: [ForecastFact] = []
        if !hasCurrentError && !forecast.isStale(at: now) && !remaining.isEmpty,
           remaining.allSatisfy({ $0.amountMM.map { $0.isFinite && $0 >= 0 } ?? false }) {
            let rates = remaining.compactMap(\.rateMMPerHour)
            let wet = rates.filter { $0 >= RainForecast.rainThresholdMMPerHour }
            if wet.isEmpty { valid = [.dry] }
            else {
                valid.append(.rain)
                if wet.count < rates.count { valid.append(.mixed) }
                if let low = wet.min(), let high = wet.max(), high >= low * 2, high - low >= 1 {
                    valid.append(.changingIntensity)
                }
            }
        }
        facts = valid
        fallback = valid.isEmpty
            ? (hasCurrentError ? "Die Prognose ist nicht aktuell bestätigt." : forecast.summary(at: now))
            : valid.prefix(2).map(\.text).joined(separator: " ")
    }

    func render(_ selection: [ForecastFact]) -> String? {
        guard (1...2).contains(selection.count), Set(selection).count == selection.count,
              selection.allSatisfy({ facts.contains($0) }) else { return nil }
        return selection.map(\.text).joined(separator: " ")
    }
}

@MainActor @Observable
final class ForecastInterpretation {
    private(set) var text: String?
    private(set) var notice: String?
    private(set) var isGenerating = false
    private(set) var usedModel = false
    private(set) var renderedSnapshot: InterpretationSnapshot?
    @ObservationIgnored private var identity = UUID()
    @ObservationIgnored private var cache: [InterpretationSnapshot: String] = [:]
    @ObservationIgnored private let availability: @MainActor () -> String?
    @ObservationIgnored private let generate: @MainActor (InterpretationSnapshot) async throws -> [ForecastFact]

    init(availability: @escaping @MainActor () -> String? = ForecastInterpretation.unavailableMessage,
         generate: @escaping @MainActor (InterpretationSnapshot) async throws -> [ForecastFact] = ForecastInterpretation.generateFacts) {
        self.availability = availability
        self.generate = generate
    }

    func reset() {
        identity = UUID()
        text = nil
        notice = nil
        usedModel = false
        renderedSnapshot = nil
    }

    func interpret(_ snapshot: InterpretationSnapshot) async {
        guard !isGenerating else { return }
        text = nil
        renderedSnapshot = nil
        usedModel = false
        notice = nil
        guard snapshot.facts.count > 1 else {
            notice = "Die vorhandenen Daten sind bereits knapp zusammengefasst."
            return
        }
        guard let unavailable = availability() else {
            if let cached = cache[snapshot] { text = cached; renderedSnapshot = snapshot; usedModel = true; return }
            let request = identity
            isGenerating = true
            defer { isGenerating = false }
            do {
                let selection = try await generate(snapshot)
                guard !Task.isCancelled, identity == request else { return }
                guard let result = snapshot.render(selection) else {
                    notice = "Die lokale Einordnung ist gerade nicht verfügbar."
                    return
                }
                if cache.count >= 8 { cache.removeAll(keepingCapacity: true) }
                cache[snapshot] = result
                text = result
                renderedSnapshot = snapshot
                usedModel = true
            } catch {
                guard !Task.isCancelled, identity == request else { return }
                notice = "Die lokale Einordnung ist gerade nicht verfügbar."
            }
            return
        }
        notice = unavailable
    }

    static func unavailableMessage() -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "de_DE")) ? nil : "Die lokale Einordnung unterstützt Deutsch hier noch nicht."
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "Apple Intelligence ist auf diesem Gerät nicht verfügbar."
            case .appleIntelligenceNotEnabled: return "Apple Intelligence ist auf diesem Gerät nicht aktiviert."
            case .modelNotReady: return "Das lokale Apple-Modell ist noch nicht bereit."
            @unknown default: return "Apple Intelligence ist momentan nicht verfügbar."
            }
        }
    }

    private static func generateFacts(_ snapshot: InterpretationSnapshot) async throws -> [ForecastFact] {
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: "Du ordnest vorhandene Radardaten auf Deutsch ein. Wähle die ein oder zwei wichtigsten unterschiedlichen Fakten ausschließlich aus der erlaubten Liste. Ergänze keine Wetterdaten, Zahlen, Sicherheit oder Warnungen. Bevorzuge aussagekräftige Verlaufsmerkmale gegenüber einer allgemeinen Regenaussage.")
        let prompt = snapshot.facts.map { "\($0.rawValue): \($0.text)" }.joined(separator: "\n")
        let response = try await session.respond(to: "Zulässige belegte Fakten:\n\(prompt)", generating: ForecastFactSelection.self,
                                                 options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 128))
        return response.content.facts
    }
}
