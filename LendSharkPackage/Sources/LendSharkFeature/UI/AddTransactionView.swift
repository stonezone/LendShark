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
                // Main input section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter a transaction")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g. lent 20 to john for lunch", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .onChange(of: inputText) { newValue in
                            Task {
                                await viewModel.updateParsePreview(newValue)
                            }
                        }
                    
                    // Examples
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Examples:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• \"lent 50 to sarah\"")
                            Text("• \"borrowed 20 from mike\"")
                            Text("• \"john owes me 15 for coffee\"")
                            Text("• \"paid back emma 30\"")
                            Text("• \"settle with john\"")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Parse preview
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
                
                // Error display
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            let success = await viewModel.parseAndAddTransaction(inputText, context: viewContext)
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(inputText.isEmpty)
                }
            }
            .onAppear {
                // Clear any previous errors
                viewModel.clearError()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AddTransactionView()
}