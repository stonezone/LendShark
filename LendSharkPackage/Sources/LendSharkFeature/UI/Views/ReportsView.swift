import SwiftUI

/// Reports and export view
public struct ReportsView: View {
    @State private var selectedFormat = ExportFormat.csv
    @State private var dateFrom = Date().addingTimeInterval(-30 * 24 * 60 * 60)
    @State private var dateTo = Date()
    @State private var isExporting = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                // Date range selection
                dateRangeCard
                
                // Export format selection
                formatSelectionCard
                
                // Export button
                exportButton
                
                // Recent exports
                recentExportsCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("DATE RANGE")
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            VStack(spacing: Layout.itemSpacing) {
                DatePicker("From", selection: $dateFrom, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .foregroundColor(.textPrimary)
                
                DatePicker("To", selection: $dateTo, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .foregroundColor(.textPrimary)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    private var formatSelectionCard: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("EXPORT FORMAT")
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            VStack(spacing: 0) {
                FormatRow(format: .csv, 
                         icon: "tablecells",
                         description: "Spreadsheet compatible",
                         isSelected: selectedFormat == .csv) {
                    selectedFormat = .csv
                }
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                FormatRow(format: .pdf,
                         icon: "doc.text",
                         description: "Printable report",
                         isSelected: selectedFormat == .pdf) {
                    selectedFormat = .pdf
                }
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                FormatRow(format: .json,
                         icon: "curlybraces",
                         description: "Developer format",
                         isSelected: selectedFormat == .json) {
                    selectedFormat = .json
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    private var exportButton: some View {
        Button(action: startExport) {
            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isExporting ? "Exporting..." : "Export Report")
                    .font(.cardTitle)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.tealAccent)
            .foregroundColor(.white)
            .cornerRadius(Layout.cornerRadius)
        }
        .disabled(isExporting)
    }
    
    private var recentExportsCard: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("RECENT EXPORTS")
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            VStack(spacing: 0) {
                RecentExportRow(date: Date(), format: "CSV", size: "24 KB")
                Divider().background(Color.textSecondary.opacity(0.2))
                RecentExportRow(date: Date().addingTimeInterval(-86400), format: "PDF", size: "156 KB")
                Divider().background(Color.textSecondary.opacity(0.2))
                RecentExportRow(date: Date().addingTimeInterval(-172800), format: "JSON", size: "18 KB")
            }
            .background(Color.cardBackground)
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    private func startExport() {
        isExporting = true
        // Simulate export
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
        }
    }
}

/// Format selection row
struct FormatRow: View {
    let format: ExportFormat
    let icon: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.tealAccent)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.rawValue)
                        .font(.cardTitle)
                        .foregroundColor(.textPrimary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.tealAccent)
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Recent export row
struct RecentExportRow: View {
    let date: Date
    let format: String
    let size: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(format)
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                
                Text(formatDate(date))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Text(size)
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.tealAccent)
            }
        }
        .padding()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ReportsView()
            .preferredColorScheme(.dark)
    }
}
