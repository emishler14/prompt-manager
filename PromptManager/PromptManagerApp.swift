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
        // Debug: Check accessibility status
        let hasAccessibility = AccessibilityService.shared.isAccessibilityEnabled()
        print("[DEBUG] Accessibility enabled: \(hasAccessibility)")

        // If no accessibility, request it and show search panel as fallback
        if !hasAccessibility {
            print("[DEBUG] Requesting accessibility permission...")
            AccessibilityService.shared.requestAccessibility()
        }

        // Try to capture selected text from the frontmost app
        let selectedText = AccessibilityService.shared.getSelectedText()
        print("[DEBUG] Selected text result: \(selectedText ?? "nil")")

        if let text = selectedText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Text found → save as new prompt (with AI naming if enabled)
            print("[DEBUG] Saving text as prompt")
            saveTextAsPrompt(text)
        } else {
            // No text selected → show search panel
            print("[DEBUG] No text found, showing search panel")
            showSearchPanel()
        }
    }

    // MARK: - Save with AI Naming

    private func saveTextAsPrompt(_ text: String) {
        let aiNamingEnabled = UserDefaults.standard.bool(forKey: "aiNamingEnabled")
        let hasAPIKey = KeychainService.hasAPIKey()

        print("[SavePrompt] AI naming enabled: \(aiNamingEnabled), Has API key: \(hasAPIKey)")

        // If AI naming is disabled or no API key, save immediately with timestamp
        if !aiNamingEnabled || !hasAPIKey {
            print("[SavePrompt] Using timestamp name (AI disabled or no key)")
            let prompt = Prompt.withTimestampName(content: text)
            promptStore.save(prompt)
            showNotification(title: "Prompt Saved", body: prompt.name)
            return
        }

        // Show "Saving..." notification
        showNotification(title: "Saving...", body: "Generating name with AI")

        // Use AI to generate name
        Task {
            let name: String
            if let aiName = await GeminiService.shared.generateName(for: text) {
                print("[SavePrompt] AI generated name: \(aiName)")
                name = aiName
            } else {
                // Fallback to timestamp if AI fails
                print("[SavePrompt] AI failed, using timestamp fallback")
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showNotification(title: String, body: String) {
        // Show visual toast
        toastPanel?.show(title: title, message: body)

        // Also send system notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
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

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Prompt Manager" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Create new window if none exists
            NSApp.sendAction(NSSelectorFromString("newWindowForTab:"), to: nil, from: nil)
        }
    }
}
