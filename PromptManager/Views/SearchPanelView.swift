import SwiftUI

/// Observable state for search panel - needed for proper updates in NSHostingView
class SearchPanelState: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var scoredPrompts: [ScoredPrompt] = []
    @Published var isAISearching = false
    @Published var lastAISearchQuery = ""
    var aiSearchTask: Task<Void, Never>?
}

struct SearchPanelView: View {
    @ObservedObject var promptStore: PromptStore
    var onDismiss: () -> Void
    var onSelectPrompt: (Prompt) -> Void

    @StateObject private var state = SearchPanelState()

    private var filteredPrompts: [Prompt] {
        state.scoredPrompts.map { $0.prompt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            SearchFieldView(
                text: $state.searchText,
                onEscape: onDismiss,
                onArrowUp: { moveSelection(by: -1) },
                onArrowDown: { moveSelection(by: 1) },
                onReturn: selectCurrentPrompt
            )
            .padding(16)

            Divider()

            // Results list
            if filteredPrompts.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                                SearchResultRow(
                                    prompt: prompt,
                                    isSelected: index == state.selectedIndex,
                                    searchText: state.searchText
                                )
                                .id(index)
                                .onTapGesture {
                                    state.selectedIndex = index
                                    selectCurrentPrompt()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: state.selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            // Footer hint
            footerView
        }
        .frame(width: 600, height: 400)
        .background(Color.clear)
        .onAppear {
            performLocalSearch()
        }
        .onChange(of: state.searchText) { newValue in
            state.selectedIndex = 0
            performLocalSearch()
            scheduleAISearch(query: newValue)
        }
        .onChange(of: promptStore.prompts) { _ in
            performLocalSearch()
        }
    }

    // MARK: - Search Methods

    private func performLocalSearch() {
        state.scoredPrompts = SearchService.shared.searchLocal(query: state.searchText, in: promptStore.prompts)
    }

    private func scheduleAISearch(query: String) {
        // Cancel any pending AI search
        state.aiSearchTask?.cancel()

        // Don't AI search for very short queries or empty
        guard query.count >= 2 else {
            state.isAISearching = false
            return
        }

        // Don't re-run AI search for same query
        guard query != state.lastAISearchQuery else { return }

        // Check if AI is available
        guard AIServiceFactory.shared.hasAPIKey() else { return }

        // Skip AI search if we have a strong local match (exact or near-exact name match)
        // Score > 1000 means name contains the query phrase exactly
        if let topScore = state.scoredPrompts.first?.score, topScore >= 1000 {
            return
        }

        // Debounce: wait 600ms after user stops typing
        state.aiSearchTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

            guard !Task.isCancelled else { return }

            // Re-check if we now have a strong local match (user may have typed more)
            let currentTopScore = await MainActor.run { state.scoredPrompts.first?.score ?? 0 }
            if currentTopScore >= 1000 {
                return
            }

            await MainActor.run {
                state.isAISearching = true
            }

            // Pass the local results to AI, not all prompts
            let localResults = await MainActor.run { state.scoredPrompts.map { $0.prompt } }

            if let aiResults = await SearchService.shared.searchWithAI(query: query, in: localResults) {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    // Only update if query hasn't changed
                    if state.searchText == query {
                        state.scoredPrompts = aiResults
                        state.lastAISearchQuery = query
                    }
                    state.isAISearching = false
                }
            } else {
                await MainActor.run {
                    state.isAISearching = false
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: state.searchText.isEmpty ? "text.quote" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(state.searchText.isEmpty ? "No prompts saved yet" : "No matching prompts")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(state.searchText.isEmpty ? "Select text and press Cmd+Shift+P to save" : "Try a different search term")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footerView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                KeyboardHintView(keys: ["↑", "↓"])
                Text("navigate")
            }
            HStack(spacing: 4) {
                KeyboardHintView(keys: ["↩"])
                Text("paste")
            }
            HStack(spacing: 4) {
                KeyboardHintView(keys: ["esc"])
                Text("close")
            }
            Spacer()

            if state.isAISearching {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("AI ranking...")
                }
            } else if !state.searchText.isEmpty && state.lastAISearchQuery == state.searchText {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("AI ranked")
                }
                .foregroundColor(.accentColor)
            }

            Text("\(filteredPrompts.count) prompt\(filteredPrompts.count == 1 ? "" : "s")")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    private func moveSelection(by offset: Int) {
        guard !filteredPrompts.isEmpty else { return }
        let newIndex = state.selectedIndex + offset
        if newIndex >= 0 && newIndex < filteredPrompts.count {
            state.selectedIndex = newIndex
        }
    }

    private func selectCurrentPrompt() {
        guard !filteredPrompts.isEmpty,
              state.selectedIndex >= 0,
              state.selectedIndex < filteredPrompts.count else { return }

        let prompt = filteredPrompts[state.selectedIndex]
        promptStore.incrementUsage(id: prompt.id)
        onSelectPrompt(prompt)
    }
}

// MARK: - Search Field

struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    var onEscape: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onReturn: () -> Void

    func makeNSView(context: Context) -> SearchTextField {
        let textField = SearchTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = "Search prompts..."
        textField.font = .systemFont(ofSize: 24, weight: .light)
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.cell?.sendsActionOnEndEditing = false

        // Store coordinator reference for callbacks
        textField.coordinator = context.coordinator

        // Auto-focus
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }

        return textField
    }

    func updateNSView(_ nsView: SearchTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Update coordinator reference so callbacks stay current
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchFieldView

        init(_ parent: SearchFieldView) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func handleEscape() {
            parent.onEscape()
        }

        func handleArrowUp() {
            parent.onArrowUp()
        }

        func handleArrowDown() {
            parent.onArrowDown()
        }

        func handleReturn() {
            parent.onReturn()
        }
    }
}

class SearchTextField: NSTextField {
    weak var coordinator: SearchFieldView.Coordinator?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            coordinator?.handleEscape()
        case 126: // Arrow Up
            coordinator?.handleArrowUp()
        case 125: // Arrow Down
            coordinator?.handleArrowDown()
        case 36: // Return
            coordinator?.handleReturn()
        default:
            super.keyDown(with: event)
        }
    }

    // Also handle via performKeyEquivalent for better event capture
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            coordinator?.handleEscape()
            return true
        case 126: // Arrow Up
            coordinator?.handleArrowUp()
            return true
        case 125: // Arrow Down
            coordinator?.handleArrowDown()
            return true
        case 36: // Return
            coordinator?.handleReturn()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let prompt: Prompt
    let isSelected: Bool
    let searchText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text(prompt.content)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }

            Spacer()

            if prompt.usageCount > 0 {
                Text("\(prompt.usageCount)×")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Keyboard Hint

struct KeyboardHintView: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
    }
}
