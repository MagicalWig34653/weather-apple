import Foundation
import FoundationModels
import Observation

@Generable
enum ForecastFact: String, CaseIterable, Hashable, Sendable {
    case dry, rain, mixed, changingIntensity

    var text: String { text(bundle: .main) }

    func text(bundle: Bundle) -> String {
        switch self {
        case .dry: NSLocalizedString("INTERP_FACT_DRY", bundle: bundle, value: "Die verbleibenden Radardaten zeigen keinen messbaren Regen.", comment: "Interpretation")
        case .rain: NSLocalizedString("INTERP_FACT_RAIN", bundle: bundle, value: "Die verbleibenden Radardaten enthalten Regen.", comment: "Interpretation")
        case .mixed: NSLocalizedString("INTERP_FACT_MIXED", bundle: bundle, value: "Regen und Intervalle ohne messbaren Regen wechseln sich im Verlauf ab.", comment: "Interpretation")
        case .changingIntensity: NSLocalizedString("INTERP_FACT_INTENSITY", bundle: bundle, value: "Die Regenintensität unterscheidet sich im Verlauf deutlich.", comment: "Interpretation")
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

    init(forecast: RainForecast, hasCurrentError: Bool, now: Date, bundle: Bundle = .main) {
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
            ? (hasCurrentError ? NSLocalizedString("INTERP_NOT_CONFIRMED", bundle: bundle, value: "Die Prognose ist nicht aktuell bestätigt.", comment: "Interpretation") : forecast.summary(at: now, bundle: bundle))
            : valid.prefix(2).map { $0.text(bundle: bundle) }.joined(separator: " ")
    }

    func render(_ selection: [ForecastFact], bundle: Bundle = .main) -> String? {
        guard (1...2).contains(selection.count), Set(selection).count == selection.count,
              selection.allSatisfy({ facts.contains($0) }) else { return nil }
        return selection.map { $0.text(bundle: bundle) }.joined(separator: " ")
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
            notice = NSLocalizedString("INTERP_ALREADY_BRIEF", value: "Die vorhandenen Daten sind bereits knapp zusammengefasst.", comment: "Interpretation")
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
                    notice = NSLocalizedString("INTERP_NOT_AVAILABLE", value: "Die lokale Einordnung ist gerade nicht verfügbar.", comment: "Interpretation")
                    return
                }
                if cache.count >= 8 { cache.removeAll(keepingCapacity: true) }
                cache[snapshot] = result
                text = result
                renderedSnapshot = snapshot
                usedModel = true
            } catch {
                guard !Task.isCancelled, identity == request else { return }
                notice = NSLocalizedString("INTERP_NOT_AVAILABLE", value: "Die lokale Einordnung ist gerade nicht verfügbar.", comment: "Interpretation")
            }
            return
        }
        notice = unavailable
    }

    /// Locale for the model support check: follows the app language (not the region format).
    static func modelLocale(language: String = AppLanguage.code) -> Locale {
        Locale(identifier: language == "de" ? "de_DE" : "en_US")
    }

    static func unavailableMessage() -> String? { unavailableMessage(bundle: .main) }

    static func unavailableMessage(bundle: Bundle, language: String = AppLanguage.code) -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(modelLocale(language: language)) ? nil
                : NSLocalizedString("INTERP_LANGUAGE_UNSUPPORTED", bundle: bundle, value: "Die lokale Einordnung unterstützt Deutsch hier noch nicht.", comment: "Interpretation")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return NSLocalizedString("INTERP_DEVICE_NOT_ELIGIBLE", bundle: bundle, value: "Apple Intelligence ist auf diesem Gerät nicht verfügbar.", comment: "Interpretation")
            case .appleIntelligenceNotEnabled: return NSLocalizedString("INTERP_AI_NOT_ENABLED", bundle: bundle, value: "Apple Intelligence ist auf diesem Gerät nicht aktiviert.", comment: "Interpretation")
            case .modelNotReady: return NSLocalizedString("INTERP_MODEL_NOT_READY", bundle: bundle, value: "Das lokale Apple-Modell ist noch nicht bereit.", comment: "Interpretation")
            @unknown default: return NSLocalizedString("INTERP_AI_UNAVAILABLE", bundle: bundle, value: "Apple Intelligence ist momentan nicht verfügbar.", comment: "Interpretation")
            }
        }
    }

    /// Instructions for the on-device model; the language of the instructions follows the app language.
    static func instructions(bundle: Bundle = .main) -> String {
        NSLocalizedString("INTERP_PROMPT_INSTRUCTIONS", bundle: bundle, value: "Du ordnest vorhandene Radardaten auf Deutsch ein. Wähle die ein oder zwei wichtigsten unterschiedlichen Fakten ausschließlich aus der erlaubten Liste. Ergänze keine Wetterdaten, Zahlen, Sicherheit oder Warnungen. Bevorzuge aussagekräftige Verlaufsmerkmale gegenüber einer allgemeinen Regenaussage.", comment: "Prompt for the on-device model")
    }

    /// User prompt: the allowed facts as `id: text` lines in the app language.
    static func prompt(for snapshot: InterpretationSnapshot, bundle: Bundle = .main) -> String {
        let lines = snapshot.facts.map { "\($0.rawValue): \($0.text(bundle: bundle))" }.joined(separator: "\n")
        return String(format: NSLocalizedString("INTERP_PROMPT_FACTS", bundle: bundle, value: "Zulässige belegte Fakten:\n%@", comment: "Prompt for the on-device model"), lines)
    }

    private static func generateFacts(_ snapshot: InterpretationSnapshot) async throws -> [ForecastFact] {
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions())
        let response = try await session.respond(to: prompt(for: snapshot), generating: ForecastFactSelection.self,
                                                 options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 128))
        return response.content.facts
    }
}
