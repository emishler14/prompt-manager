import AppKit
import SwiftUI

/// A floating panel that appears centered on screen, similar to Spotlight.
/// Does not steal focus from other applications.
class FloatingPanel: NSPanel {

    init<Content: View>(contentView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // Panel configuration
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true

        // Allow the panel to become key (for keyboard input) but not main
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false

        // Set up the SwiftUI content
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        // Add visual effect background for blur
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.frame = self.contentView?.bounds ?? .zero
        visualEffect.autoresizingMask = [.width, .height]

        self.contentView?.addSubview(visualEffect)
        self.contentView?.addSubview(hostingView)

        // Center on screen
        centerOnScreen()
    }

    /// Centers the panel on the main screen
    func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = self.frame

        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2 + 100 // Slightly above center like Spotlight

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Shows the panel with animation
    func showPanel() {
        centerOnScreen()
        self.alphaValue = 0
        self.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1
        }
    }

    /// Hides the panel with animation
    func hidePanel() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    // Allow the panel to become key window for keyboard input
    override var canBecomeKey: Bool {
        return true
    }

    // Don't become main window
    override var canBecomeMain: Bool {
        return false
    }

    // Handle escape key to close
    override func cancelOperation(_ sender: Any?) {
        hidePanel()
    }
}
