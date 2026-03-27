import AppKit
import Foundation

@MainActor
public final class CountdownOverlayController {
    private var window: NSWindow?
    private var titleLabel: NSTextField?
    private var valueLabel: NSTextField?
    private var timer: Timer?
    private var countdownEndDate: Date?

    public init() {}

    public func present(title: String, seconds: Int) {
        ensureWindow()
        guard let window, let titleLabel, let valueLabel else {
            return
        }

        countdownEndDate = Date().addingTimeInterval(TimeInterval(max(1, seconds)))
        titleLabel.stringValue = title
        valueLabel.stringValue = "\(max(1, seconds))"
        position(window: window)
        window.orderFrontRegardless()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Task { @MainActor [weak self] in
                self?.updateCountdown()
            }
        }
    }

    public func dismiss() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        countdownEndDate = nil
    }

    private func updateCountdown() {
        guard let countdownEndDate, let valueLabel else {
            dismiss()
            return
        }

        let remaining = countdownEndDate.timeIntervalSinceNow

        if remaining > 0 {
            valueLabel.stringValue = "\(Int(ceil(remaining)))"
            return
        }

        if remaining > -0.35 {
            valueLabel.stringValue = "0"
            return
        }

        if remaining > -1.15 {
            valueLabel.stringValue = "GO"
            return
        }

        dismiss()
    }

    private func ensureWindow() {
        guard window == nil else {
            return
        }

        let contentView = NSVisualEffectView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.material = .hudWindow
        contentView.state = .active
        contentView.blendingMode = .withinWindow
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 22
        contentView.layer?.masksToBounds = true

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = NSTextField(labelWithString: "10")
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 58, weight: .heavy)
        valueLabel.textColor = .white
        valueLabel.alignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        self.window = window
        self.titleLabel = titleLabel
        self.valueLabel = valueLabel
    }

    private func position(window: NSWindow) {
        guard let screen = NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let x = visibleFrame.maxX - windowSize.width - 24
        let y = visibleFrame.maxY - windowSize.height - 36
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
