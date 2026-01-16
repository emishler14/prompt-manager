import SwiftUI
import AppKit

struct ToastView: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(minWidth: 250)
    }
}

class ToastPanel: NSPanel {
    private var hideTimer: Timer?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isFloatingPanel = true
    }

    func show(title: String, message: String, icon: String = "checkmark.circle.fill") {
        hideTimer?.invalidate()

        let toastView = ToastView(title: title, message: message, icon: icon)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        // Visual effect background
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true
        visualEffect.frame = self.contentView?.bounds ?? .zero
        visualEffect.autoresizingMask = [.width, .height]

        self.contentView?.subviews.forEach { $0.removeFromSuperview() }
        self.contentView?.addSubview(visualEffect)
        self.contentView?.addSubview(hostingView)

        // Size to fit content
        let fittingSize = hostingView.fittingSize
        self.setContentSize(fittingSize)

        // Position at top center of screen
        positionAtTop()

        // Show with animation
        self.alphaValue = 0
        self.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1
        }

        // Auto-hide after 2 seconds
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideToast()
        }
    }

    private func positionAtTop() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = self.frame

        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.maxY - panelFrame.height - 20

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func hideToast() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
