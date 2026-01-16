import SwiftUI
import KeyboardShortcuts
import UserNotifications

@main
struct PromptManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        // Main window for prompt management
        WindowGroup("Prompt Manager") {
            MainWindowView(store: appDelegate.promptStore)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Settings window for customizing shortcuts
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var searchPanel: FloatingPanel?
    private var toastPanel: ToastPanel?
    let promptStore = PromptStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupSearchPanel()
        setupToastPanel()
        setupKeyboardShortcuts()
        setDefaultShortcutIfNeeded()
        requestNotificationPermission()
        setupBackgroundRename()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindow),
            name: NSNotification.Name("OpenMainWindow"),
            object: nil
        )
    }

    @objc private func handleOpenMainWindow() {
        openMainWindow()
    }

    private func setupBackgroundRename() {
        // Start network monitoring
        _ = NetworkMonitor.shared

        // Start background rename service to rename timestamp-named prompts
        BackgroundRenameService.shared.start(promptStore: promptStore)
    }

    private func setupToastPanel() {
        toastPanel = ToastPanel()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback to system symbol if custom icon not found
                button.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Prompt Manager")
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 220)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(promptStore: promptStore))
    }

    private func setupSearchPanel() {
        let searchView = SearchPanelView(
            promptStore: promptStore,
            onDismiss: { [weak self] in
                self?.hideSearchPanel()
            },
            onSelectPrompt: { [weak self] prompt in
                self?.handlePromptSelected(prompt)
            }
        )
        searchPanel = FloatingPanel(contentView: searchView)
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .triggerPromptManager) { [weak self] in
            self?.handleShortcutTriggered()
        }
    }

    private func setDefaultShortcutIfNeeded() {
        if KeyboardShortcuts.getShortcut(for: .triggerPromptManager) == nil {
            KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.command, .shift]), for: .triggerPromptManager)
        }
    }

    private func handleShortcutTriggered() {
        let hasAccessibility = AccessibilityService.shared.isAccessibilityEnabled()
        Logger.logApp("Shortcut triggered - Accessibility enabled: \(hasAccessibility)")

        // If no accessibility, request it and show search panel as fallback
        if !hasAccessibility {
            Logger.logApp("Requesting accessibility permission")
            AccessibilityService.shared.requestAccessibility()
        }

        // Try to capture selected text from the frontmost app
        let selectedText = AccessibilityService.shared.getSelectedText()
        Logger.logApp("Selected text: \(selectedText != nil ? "\(selectedText!.count) chars" : "none")")

        if let text = selectedText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Text found → save as new prompt (with AI naming if enabled)
            Logger.logApp("Saving captured text as prompt")
            saveTextAsPrompt(text)
        } else {
            // No text selected → show search panel
            Logger.logApp("No text selected, showing search panel")
            showSearchPanel()
        }
    }

    // MARK: - Save with AI Naming

    private func saveTextAsPrompt(_ text: String) {
        let aiNamingEnabled = AIServiceFactory.shared.isAINamingEnabled
        let hasAPIKey = AIServiceFactory.shared.hasAPIKey()

        Logger.logApp("Saving prompt - AI naming: \(aiNamingEnabled), Has API key: \(hasAPIKey)")

        // If AI naming is disabled or no API key, save immediately with timestamp
        if !aiNamingEnabled || !hasAPIKey {
            Logger.logApp("Using timestamp name (AI disabled or no key)")
            let prompt = Prompt.withTimestampName(content: text)
            promptStore.save(prompt)
            showNotification(title: "Prompt Saved", body: prompt.name)
            return
        }

        // Show "Saving..." notification
        showNotification(title: "Saving...", body: "Generating name with AI")

        // Use AI to generate name
        Task {
            let aiService = AIServiceFactory.shared.getCurrentService()
            let name: String
            if let aiName = await aiService.generateName(for: text) {
                Logger.logApp("AI generated name: \(aiName)")
                name = aiName
            } else {
                // Fallback to timestamp if AI fails
                Logger.logApp("AI naming failed, using timestamp fallback")
                name = "Prompt - \(Date().formatted(date: .abbreviated, time: .shortened))"
            }

            await MainActor.run {
                let prompt = Prompt(name: name, content: text)
                promptStore.save(prompt)
                showNotification(title: "Prompt Saved", body: name)
            }
        }
    }

    // MARK: - Search Panel

    private func showSearchPanel() {
        // Store the currently active app before showing the panel
        PasteService.shared.storePreviousApp()

        // Show the panel
        searchPanel?.showPanel()
    }

    private func hideSearchPanel() {
        searchPanel?.hidePanel()
    }

    private func handlePromptSelected(_ prompt: Prompt) {
        // Hide the panel first
        hideSearchPanel()

        // Paste the prompt content into the previous app
        PasteService.shared.pasteText(prompt.content)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.logError("Notification permission request failed: \(error.localizedDescription)", category: .app)
            } else {
                Logger.logApp("Notification permission \(granted ? "granted" : "denied")")
            }
        }
    }

    private func showNotification(title: String, body: String) {
        // Show visual toast (always works, doesn't require permission)
        toastPanel?.show(title: title, message: body)

        // Also send system notification (may be blocked by user preferences)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // This is not critical since we have the toast fallback
                Logger.logDebug("System notification failed: \(error.localizedDescription)", category: .app)
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private var mainWindow: NSWindow?

    func openMainWindow() {
        // Close the popover first
        popover?.performClose(nil)

        // For menu bar apps, we need to set activation policy to show windows
        NSApp.setActivationPolicy(.regular)

        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Use our managed window or create one
        if let window = mainWindow, window.isVisible || !window.isMiniaturized {
            // Window exists - bring it to front
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // Create and show window
            createAndShowMainWindow()
        }
    }

    func createAndShowMainWindow() {
        // Create a new window with MainWindowView
        let contentView = MainWindowView(store: promptStore)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Prompt Manager"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 600, height: 400)

        // Center on main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.setFrameAutosaveName("PromptManagerMainWindow")
        window.isReleasedWhenClosed = false

        // Store reference and show
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Ensure it's visible
        NSApp.activate(ignoringOtherApps: true)
    }
}
