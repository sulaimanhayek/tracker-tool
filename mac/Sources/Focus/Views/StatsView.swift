import FocusKit
import SwiftUI

struct StatsView: View {
    @ObservedObject var log: SessionLog
    var onChangeFolder: (URL, Bool) -> Void
    @State private var grain: Grain = .day

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

            headline
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

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        // A floor of 2pt keeps empty periods visible as a gap in the
                        // run rather than nothing at all.
                        RoundedRectangle(cornerRadius: 3)
                            .fill(bucket.seconds == 0 ? Color.secondary.opacity(0.18) : Color.accentColor)
                            .frame(height: max(2, 120 * CGFloat(bucket.seconds) / CGFloat(peak)))

                        Text(grain.shortTitle(for: bucket.start, calendar: calendar))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .help("\(grain.title(for: bucket.start, calendar: calendar)): \(Statistics.format(seconds: bucket.seconds))")
                }
            }
            .frame(height: 140, alignment: .bottom)
        }
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
