import SwiftUI

/// Small bar chart of the five-minute precipitation rate; unknown values are drawn as hatched gaps.
struct RainBarChart: View {
    let samples: [RainSample]
    var barSpacing: CGFloat = 2
    var accentable = false

    /// Square-root scale keeps light drizzle visible next to heavy rain (cap 10 mm/h).
    private func fraction(_ rate: Double) -> CGFloat {
        CGFloat(min(1, (max(0, rate) / 10).squareRoot()))
    }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(samples) { sample in
                    let rate = sample.rateMMPerHour
                    let wet = (rate ?? 0) >= RainForecast.rainThresholdMMPerHour
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(rate == nil ? Color.orange.opacity(0.4)
                              : wet ? RainOutlook.Intensity(rateMMPerHour: rate!).barColor
                              : Color.secondary.opacity(0.3))
                        .frame(height: max(2, geo.size.height * (wet ? max(0.15, fraction(rate!)) : 0)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
