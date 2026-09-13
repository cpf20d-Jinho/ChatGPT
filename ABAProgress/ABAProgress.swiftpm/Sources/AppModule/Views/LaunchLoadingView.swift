import SwiftUI

struct LaunchLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        VStack(spacing: 28) {
            Image("LaunchLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 180, height: 180)
                .accessibilityHidden(true)

            if reduceMotion {
                Circle()
                    .strokeBorder(rippleColor, lineWidth: 3)
                    .frame(width: 44, height: 44)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    ZStack {
                        ripple(elapsed: elapsed, offset: 0)
                        ripple(elapsed: elapsed, offset: 0.5)
                        Circle()
                            .strokeBorder(rippleColor, lineWidth: 3)
                            .frame(width: 44, height: 44)
                    }
                    .frame(width: 82, height: 82)
                }
                .frame(width: 82, height: 82)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("쉬운 ABA 시작 중")
    }

    private var rippleColor: Color { Color(red: 0.89, green: 0.29, blue: 0.51) }

    private func ripple(elapsed: TimeInterval, offset: Double) -> some View {
        let phase = (elapsed / 1.4 + offset).truncatingRemainder(dividingBy: 1)
        return Circle()
            .strokeBorder(rippleColor.opacity(0.35 * (1 - phase)), lineWidth: 2)
            .frame(width: 44, height: 44)
            .scaleEffect(CGFloat(0.95 + 0.85 * phase))
    }
}

struct LaunchGateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingLaunch = true

    var body: some View {
        ZStack {
            RootView()
                .accessibilityHidden(showingLaunch)

            if showingLaunch {
                LaunchLoadingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // RootView is created immediately; the short transition lets the
            // static launch image hand off to the animated loading state.
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                showingLaunch = false
            }
        }
    }
}
