import SwiftUI

struct MainWindowView: View {
    @ObservedObject var store: PromptStore
    @State private var showingAddPrompt = false
    @State private var newPromptContent = ""
    @State private var selectedPromptID: UUID?

    var body: some View {
        NavigationView {
            // Sidebar: Prompt List
            VStack(spacing: 0) {
                List(selection: $selectedPromptID) {
                    ForEach(store.prompts) { prompt in
                        PromptRowView(prompt: prompt)
                            .tag(prompt.id)
                            .contextMenu {
                                Button("Copy to Clipboard") {
                                    copyToClipboard(prompt)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    store.delete(id: prompt.id)
                                }
                            }
                    }
                    .onDelete(perform: deletePrompts)
                }
                .listStyle(.sidebar)

                Divider()

                // Add button at bottom
                Button(action: { showingAddPrompt = true }) {
                    Label("Add Prompt", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(minWidth: 250)

            // Detail View
            if let selectedID = selectedPromptID,
               let prompt = store.prompts.first(where: { $0.id == selectedID }) {
                PromptDetailView(prompt: prompt, store: store)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a prompt")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Or add a new one with the + button")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showingAddPrompt) {
            AddPromptSheet(store: store, isPresented: $showingAddPrompt)
        }
    }

    private func deletePrompts(at offsets: IndexSet) {
        for index in offsets {
            store.delete(id: store.prompts[index].id)
        }
    }

    private func copyToClipboard(_ prompt: Prompt) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        store.incrementUsage(id: prompt.id)
    }
}

struct PromptRowView: View {
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prompt.name)
                .font(.headline)
                .lineLimit(1)
            Text(prompt.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct PromptDetailView: View {
    let prompt: Prompt
    @ObservedObject var store: PromptStore
    @State private var editedName: String = ""
    @State private var editedContent: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Prompt name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveChanges() }
            }

            // Content field
            VStack(alignment: .leading, spacing: 4) {
                Text("Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editedContent)
                    .font(.body)
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.3), width: 1)
            }

            // Metadata
            HStack {
                Text("Created: \(prompt.createdAt.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Used \(prompt.usageCount) times")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Actions
            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prompt.content, forType: .string)
                    store.incrementUsage(id: prompt.id)
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Save Changes") {
                    saveChanges()
                }
                .disabled(editedName == prompt.name && editedContent == prompt.content)
            }
        }
        .padding()
        .onAppear {
            editedName = prompt.name
            editedContent = prompt.content
        }
        .onChange(of: prompt.id) { _ in
            editedName = prompt.name
            editedContent = prompt.content
        }
    }

    private func saveChanges() {
        var updated = prompt
        updated.name = editedName
        updated.content = editedContent
        store.update(updated)
    }
}

struct AddPromptSheet: View {
    @ObservedObject var store: PromptStore
    @Binding var isPresented: Bool
    @State private var content = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add New Prompt")
                .font(.headline)

            Text("Paste or type your prompt content below. A name will be auto-generated.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 150)
                .border(Color.secondary.opacity(0.3), width: 1)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Prompt") {
                    let prompt = Prompt.withTimestampName(content: content)
                    store.save(prompt)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
}

#Preview {
    MainWindowView(store: PromptStore())
}
