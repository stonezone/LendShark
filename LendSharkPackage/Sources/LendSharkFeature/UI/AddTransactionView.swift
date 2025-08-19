import SwiftUI

/// View for adding new transactions
public struct AddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TransactionViewModel()
    @State private var inputText = ""
    @State private var showingAdvanced = false
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Quick entry
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Entry")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g. lent 20 to john", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                    
                    if let preview = viewModel.parsePreview {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.cyan)
                            Text(preview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                Spacer()
                
                // Add button
                Button(action: {
                    Task {
                        await viewModel.parseAndAddTransaction(inputText, context: viewContext)
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }) {
                    Text("Add Transaction")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "00BCD4"))
                        .cornerRadius(12)
                }
                .disabled(inputText.isEmpty)
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AddTransactionView()
}