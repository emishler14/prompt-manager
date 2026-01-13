import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var isAccessibilityGranted = false
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Accessibility Permission Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Prompt Manager needs accessibility permission to capture selected text from other apps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                Text("How to enable:")
                    .font(.headline)

                InstructionRow(number: 1, text: "Click \"Open System Settings\" below")
                InstructionRow(number: 2, text: "Find Prompt Manager in the list (or click + to add it)")
                InstructionRow(number: 3, text: "Toggle the switch to enable access")
                InstructionRow(number: 4, text: "This window will update automatically")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Status indicator
            HStack(spacing: 8) {
                Image(systemName: isAccessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isAccessibilityGranted ? .green : .red)

                Text(isAccessibilityGranted ? "Permission granted!" : "Permission not yet granted")
                    .font(.callout)
                    .foregroundColor(isAccessibilityGranted ? .green : .secondary)
            }
            .padding(.vertical, 8)

            // Buttons
            HStack(spacing: 16) {
                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isAccessibilityGranted)
            }

            // Skip option
            Button("Skip for now") {
                completeOnboarding()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding(32)
        .frame(width: 450, height: 500)
        .onAppear {
            checkAccessibilityStatus()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func checkAccessibilityStatus() {
        isAccessibilityGranted = AccessibilityService.shared.isAccessibilityEnabled()
    }

    private func startPolling() {
        // Poll every 1 second to check if permission was granted
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkAccessibilityStatus()
        }
    }

    private func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func openAccessibilitySettings() {
        // Request permission (shows system dialog) and open settings
        AccessibilityService.shared.requestAccessibility()

        // Also open the Privacy & Security settings directly
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isPresented = false
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.callout)
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
