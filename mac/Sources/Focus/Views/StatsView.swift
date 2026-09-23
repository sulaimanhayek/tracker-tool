import FocusKit
import SwiftUI

struct StatsView: View {
    @ObservedObject var log: SessionLog
    var onChangeFolder: (URL, Bool) -> Void
    var onAddTime: () -> Void
    @State private var grain: Grain = .day
    @State private var hovered: Date?

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("", selection: $grain) {
                ForEach(Grain.allCases) { grain in
                    Text(grain.label).tag(grain)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .top) {
                headline
                Spacer()
                Button {
                    onAddTime()
                } label: {
                    Label("Add untracked time", systemImage: "plus.circle")
                }
                .help("Log focus time you did not run the timer for")
            }

            chart
            themes

            Spacer(minLength: 0)

            Divider()

            HStack(alignment: .top) {
                DataFolderSection(onChange: onChangeFolder)
                Spacer()
                Text("\(log.sessions.count) sessions logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headline: some View {
        let seconds = Statistics.total(log.sessions, grain: grain, calendar: calendar)
        let period = Statistics.start(of: Date(), grain: grain, calendar: calendar)

        return VStack(alignment: .leading, spacing: 2) {
            Text(Statistics.format(seconds: seconds))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
            Text(grain.title(for: period, calendar: calendar))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        let buckets = Statistics.buckets(log.sessions, grain: grain, calendar: calendar)
        let peak = max(buckets.map(\.seconds).max() ?? 0, 1)
        let spacing: CGFloat = 6

        return GeometryReader { geometry in
            let width = (geometry.size.width - spacing * CGFloat(max(buckets.count - 1, 0)))
                / CGFloat(max(buckets.count, 1))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        // A floor of 2pt keeps empty periods visible as a gap in the
                        // run rather than nothing at all.
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fill(for: bucket))
                            .frame(height: max(2, 120 * CGFloat(bucket.seconds) / CGFloat(peak)))

                        Text(grain.shortTitle(for: bucket.start, calendar: calendar))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    // The whole column is the target, so a thin bar — or an empty
                    // period — is as easy to point at as a tall one.
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside {
                            hovered = bucket.start
                        } else if hovered == bucket.start {
                            hovered = nil
                        }
                    }
                    .accessibilityLabel("\(grain.title(for: bucket.start, calendar: calendar)): \(Statistics.format(seconds: bucket.seconds))")
                }
            }
            .frame(height: 140, alignment: .bottom)
            .overlay(alignment: .topLeading) {
                if let hovered, let index = buckets.firstIndex(where: { $0.start == hovered }) {
                    breakdown(for: hovered)
                        .offset(
                            x: cardOffset(
                                barCentre: (width + spacing) * CGFloat(index) + width / 2,
                                chartWidth: geometry.size.width
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 140)
    }

    /// Keeps the card beside the bar it belongs to without letting it run off
    /// either end of the chart.
    private func cardOffset(barCentre: CGFloat, chartWidth: CGFloat) -> CGFloat {
        let cardWidth: CGFloat = 200
        return min(max(0, barCentre - cardWidth / 2), max(0, chartWidth - cardWidth))
    }

    private func fill(for bucket: Bucket) -> Color {
        if bucket.seconds == 0 {
            return hovered == bucket.start ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.18)
        }
        return hovered == bucket.start ? Color.accentColor : Color.accentColor.opacity(0.8)
    }

    /// What one period was made of: the total, then the themes it went to.
    private func breakdown(for period: Date) -> some View {
        let totals = Statistics.byTheme(log.sessions, in: period, grain: grain, calendar: calendar)
        let seconds = totals.reduce(0) { $0 + $1.seconds }

        return VStack(alignment: .leading, spacing: 4) {
            Text(grain.title(for: period, calendar: calendar))
                .font(.caption.weight(.semibold))

            Text(Statistics.format(seconds: seconds))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if totals.isEmpty {
                Text("Nothing logged")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Divider()
                ForEach(totals) { total in
                    HStack(spacing: 8) {
                        Text(total.theme)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(Statistics.format(seconds: total.seconds))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(8)
        .frame(width: 200, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .shadow(radius: 6, y: 2)
    }

    private var themes: some View {
        let totals = Statistics.byTheme(log.sessions, grain: grain, calendar: calendar)
        let peak = max(totals.first?.seconds ?? 0, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("By theme")
                .font(.headline)

            if totals.isEmpty {
                Text("Nothing logged in this period yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(totals) { total in
                    HStack(spacing: 10) {
                        Text(total.theme)
                            .frame(width: 130, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.75))
                                .frame(width: max(2, geometry.size.width * CGFloat(total.seconds) / CGFloat(peak)))
                        }
                        .frame(height: 14)

                        Text(Statistics.format(seconds: total.seconds))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
    }
}
