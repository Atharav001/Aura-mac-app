import SwiftUI

struct TodoWidget: View {
    @State private var viewModel = TodoViewModel()
    @State private var hoveredDelete: UUID?
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("To-Do")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(viewModel.items.filter(\.isCompleted).count)/\(viewModel.items.count)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack(spacing: 8) {
                TextField("Add a task...", text: $viewModel.newItemTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white)
                    .accentColor(.blue)
                    .focused($textFieldFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                    .onSubmit { viewModel.addItem() }

                Button(action: viewModel.addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.blue.opacity(0.3))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            if viewModel.items.isEmpty {
                Spacer()
                Text("No tasks yet")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.items) { item in
                            todoRow(item)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    if let completedID = viewModel.completedItemID {
                        ConfettiView()
                            .allowsHitTesting(false)
                            .id(completedID)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    viewModel.clearConfetti()
                                }
                            }
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                textFieldFocused = true
            }
        }
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 10) {
            Button {
                viewModel.toggleItem(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isCompleted ? .green.opacity(0.7) : .white.opacity(0.3))
            }
            .buttonStyle(PlainButtonStyle())

            Text(item.title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(item.isCompleted ? 0.35 : 0.8))
                .strikethrough(item.isCompleted)
                .lineLimit(1)

            Spacer()

            Button {
                viewModel.deleteItem(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red.opacity(hoveredDelete == item.id ? 0.7 : 0.35))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Delete task")
            .onHover { hovering in
                hoveredDelete = hovering ? item.id : nil
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(item.isCompleted ? 0.02 : 0.05))
        )
    }
}
