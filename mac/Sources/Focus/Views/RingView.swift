import FocusKit
import SwiftUI

/// The countdown ring. It reports progress and nothing else — there is no drag
/// handle, so the time cannot be knocked out of place by a stray click.
struct RingView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // No animation between ticks: the ring moves a hair each second, and
            // animating that would keep the screen redrawing all the time.
        }
    }
}
