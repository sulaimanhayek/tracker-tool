import FocusKit
import SwiftUI

struct StatsView: View {
    @ObservedObject var log: SessionLog
    var onChangeFolder: (URL, Bool) -> Void
    var onAddTime: () -> Void
    @State private var grain: Grain = .day
    @State private var hovered: Date?
    /// The chart, worked out once. Pointing at a bar only reads from this, so
    /// moving along the row costs nothing but a redraw.
    @State private var periods: [PeriodBreakdown] = []

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
            legend
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
        .onAppear(perform: rebuild)
        .onChange(of: grain) { rebuild() }
        .onChange(of: log.sessions.count) { rebuild() }
    }

    private func rebuild() {
        periods = Statistics.breakdown(log.sessions, grain: grain, calendar: calendar)
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
        let peak = max(periods.map(\.seconds).max() ?? 0, 1)
        let height: CGFloat = 120

        return GeometryReader { geometry in
            // A bar is the same width whatever the period is; when there are few
            // of them the gaps grow instead, rather than five years turning into
            // five slabs.
            let width = barWidth(chartWidth: geometry.size.width)
            let spacing = gap(chartWidth: geometry.size.width, barWidth: width)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(periods) { period in
                    VStack(spacing: 6) {
                        bar(for: period, peak: peak, height: height)
                            .frame(width: width)

                        Text(period.shortTitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    // The column, gap and all, is the target — so a thin bar, a
                    // wide gap or an empty period is as easy to point at as a
                    // tall bar.
                    .frame(width: width + spacing)
                    // The whole column is the target, so a thin bar — or an empty
                    // period — is as easy to point at as a tall one.
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside {
                            hovered = period.start
                        } else if hovered == period.start {
                            hovered = nil
                        }
                    }
                    .accessibilityLabel("\(period.title): \(Statistics.format(seconds: period.seconds))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140, alignment: .bottom)
            .overlay(alignment: .topLeading) {
                if let hovered, let index = periods.firstIndex(where: { $0.start == hovered }) {
                    label(for: periods[index])
                        .offset(
                            x: cardOffset(
                                barCentre: (width + spacing) * (CGFloat(index) + 0.5),
                                chartWidth: geometry.size.width
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 140)
    }

    /// One bar, stacked out of its themes so the colours say where the time went
    /// without anything having to be pointed at.
    private func bar(for period: PeriodBreakdown, peak: Int, height: CGFloat) -> some View {
        let scale = height / CGFloat(peak)

        return VStack(spacing: 0) {
            if period.slices.isEmpty {
                // A sliver keeps empty periods visible as a gap in the run rather
                // than nothing at all.
                Rectangle()
                    .fill(Color.secondary.opacity(hovered == period.start ? 0.3 : 0.18))
                    .frame(height: 2)
            } else {
                ForEach(period.slices.reversed()) { slice in
                    Rectangle()
                        .fill(Color(ChartPalette.colour(slice.colour)))
                        .frame(height: max(1, scale * CGFloat(slice.seconds)))
                }
            }
        }
        .opacity(hovered == nil || hovered == period.start ? 1 : 0.55)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func barWidth(chartWidth: CGFloat) -> CGFloat {
        CGFloat(ChartLayout.barWidth(count: periods.count, chartWidth: Double(chartWidth)))
    }

    private func gap(chartWidth: CGFloat, barWidth width: CGFloat) -> CGFloat {
        CGFloat(ChartLayout.gap(count: periods.count, chartWidth: Double(chartWidth), barWidth: Double(width)))
    }

    /// Keeps the card beside the bar it belongs to without letting it run off
    /// either end of the chart.
    private func cardOffset(barCentre: CGFloat, chartWidth: CGFloat) -> CGFloat {
        let cardWidth: CGFloat = 170
        return min(max(0, barCentre - cardWidth / 2), max(0, chartWidth - cardWidth))
    }

    /// The hover label: the day, its themes, the total. Plain shapes and no
    /// blur, because this is redrawn every time the pointer crosses a bar.
    private func label(for period: PeriodBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(period.title)
                .font(.caption.weight(.bold))

            if period.slices.isEmpty {
                Text("Nothing logged")
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(period.slices) { slice in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(ChartPalette.colour(slice.colour)))
                            .frame(width: 8, height: 8)
                        Text("\(slice.theme):")
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Statistics.clock(seconds: slice.seconds))
                            .monospacedDigit()
                    }
                }

                Text("TOTAL: \(Statistics.clock(seconds: period.seconds))")
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .padding(.top, 1)
            }
        }
        .font(.caption2)
        .foregroundStyle(.white)
        .padding(8)
        .frame(width: 170, alignment: .leading)
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
    }

    /// Which colour is which theme, for the whole span on screen.
    private var legend: some View {
        var seen: Set<String> = []
        let slices = periods.flatMap(\.slices)
            .filter { seen.insert($0.theme).inserted }
            .sorted { $0.colour < $1.colour }

        return FlowLayout(spacing: 10) {
            ForEach(slices) { slice in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(ChartPalette.colour(slice.colour)))
                        .frame(width: 9, height: 9)
                    Text(slice.theme)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var themes: some View {
        let colours = ChartPalette.order(of: log.sessions)
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
                                .fill(Color(ChartPalette.colour(colours.firstIndex(of: total.theme) ?? 0)))
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
