import SwiftUI

struct SearchPanelView: View {
    @ObservedObject var promptStore: PromptStore
    var onDismiss: () -> Void
    var onSelectPrompt: (Prompt) -> Void

    @State private var searchText = ""
    @State private var selectedIndex = 0

    private var filteredPrompts: [Prompt] {
        if searchText.isEmpty {
            return promptStore.prompts
        }
        let lowercased = searchText.lowercased()
        return promptStore.prompts.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.content.lowercased().contains(lowercased)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            SearchFieldView(
                text: $searchText,
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
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                                SearchResultRow(
                                    prompt: prompt,
                                    isSelected: index == selectedIndex,
                                    searchText: searchText
                                )
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    selectCurrentPrompt()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: selectedIndex) { newIndex in
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
        .onChange(of: searchText) { _ in
            selectedIndex = 0
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "text.quote" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No prompts saved yet" : "No matching prompts")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Select text and press Cmd+Shift+P to save" : "Try a different search term")
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
        let newIndex = selectedIndex + offset
        if newIndex >= 0 && newIndex < filteredPrompts.count {
            selectedIndex = newIndex
        }
    }

    private func selectCurrentPrompt() {
        guard !filteredPrompts.isEmpty,
              selectedIndex >= 0,
              selectedIndex < filteredPrompts.count else { return }

        let prompt = filteredPrompts[selectedIndex]
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

    func makeNSView(context: Context) -> NSTextField {
        let textField = SearchTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = "Search prompts..."
        textField.font = .systemFont(ofSize: 24, weight: .light)
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.cell?.sendsActionOnEndEditing = false

        textField.onEscape = onEscape
        textField.onArrowUp = onArrowUp
        textField.onArrowDown = onArrowDown
        textField.onReturn = onReturn

        // Auto-focus
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
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
    }
}

class SearchTextField: NSTextField {
    var onEscape: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            onEscape?()
        case 126: // Arrow Up
            onArrowUp?()
        case 125: // Arrow Down
            onArrowDown?()
        case 36: // Return
            onReturn?()
        default:
            super.keyDown(with: event)
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

#Preview {
    SearchPanelView(
        promptStore: PromptStore(),
        onDismiss: {},
        onSelectPrompt: { _ in }
    )
}
