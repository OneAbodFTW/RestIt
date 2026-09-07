import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController {
    private var panels: [RestPanel] = []
    private var session: BreakSession?

    func show(
        duration: Int,
        onFinished: @escaping @MainActor (Bool) -> Void
    ) {
        guard panels.isEmpty else { return }

        let session = BreakSession(duration: duration) { [weak self] completed in
            self?.closePanels()
            onFinished(completed)
        }
        self.session = session

        for screen in NSScreen.screens {
            let panel = RestPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.level = .screenSaver
            panel.backgroundColor = .black
            panel.isOpaque = true
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: BreakOverlayView(session: session))
            panel.setFrame(screen.frame, display: true)
            panel.makeKeyAndOrderFront(nil)
            panels.append(panel)
        }

        NSApp.activate(ignoringOtherApps: true)
        session.start()
    }

    func dismiss() {
        session?.invalidate()
        closePanels()
    }

    private func closePanels() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        session?.invalidate()
        session = nil
    }
}

private final class RestPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class BreakSession: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    let totalSeconds: Int

    private var timer: Timer?
    private var hasFinished = false
    private let onFinished: @MainActor (Bool) -> Void

    init(
        duration: Int,
        onFinished: @escaping @MainActor (Bool) -> Void
    ) {
        let safeDuration = max(1, duration)
        totalSeconds = safeDuration
        remainingSeconds = safeDuration
        self.onFinished = onFinished
    }

    var progress: Double {
        1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    func start() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advance()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func finishEarly() {
        finish(completed: false)
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        remainingSeconds = max(0, remainingSeconds - 1)
        if remainingSeconds == 0 { finish(completed: true) }
    }

    private func finish(completed: Bool) {
        guard !hasFinished else { return }
        hasFinished = true
        invalidate()
        onFinished(completed)
    }
}

private struct BreakOverlayView: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.075, blue: 0.18),
                    Color(red: 0.055, green: 0.22, blue: 0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 620, height: 620)
                .blur(radius: 20)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: session.progress)
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 28, weight: .medium))
                        Text("\(session.remainingSeconds)")
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 170, height: 170)

                VStack(spacing: 10) {
                    Text("Give your eyes a moment")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("Close your eyes, relax your face, and take a slow breath.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Button("End break early") {
                    session.finishEarly()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.white.opacity(0.8))
                .keyboardShortcut(.escape, modifiers: [])
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(50)
        }
    }
}
