# LendShark UI Implementation Specifications

## Reference App Analysis
Based on the uploaded image showing a financial tracking app with 5 screens:

### Screen 1: Balance Overview
- Total balance prominently displayed: $300,462.04
- Asset breakdown in colored bar chart
- Three sections:
  - PAYMENT ACCOUNTS ($36,715.55)
    - Cash Fund
    - Money Pro Bank
    - National Bank
  - CREDIT CARDS (-$4,601)
    - Money Pro Bank
    - National Bank
  - OTHER ASSETS ($350,778.50)
    - Bike, Motorbike, Parking Place, Car

### Screen 2: Today/Goals View
- Date header: "Tuesday, August 2023"
- Goals section with "No debt" goal
- Yacht goal with progress
- Transaction items with amounts
- Add button for new entries

### Screen 3: Budget Overview
- Calendar grid showing July 2023
- Daily expense indicators
- Total amounts displayed
- Actual vs Budget vs Remaining
- Category breakdowns with circular icons:
  - Traveling, Education, Cafe, Clothing
  - Home, Car, Utilities
- Income section at bottom

### Screen 4: Analytics/Expenses
- Date range selector (Jan 1 - Dec 31, 2023)
- Donut chart showing expense breakdown
- Categories with percentages:
  - Debt (22%), Travelling (20%), Clothing (12%)
  - Cafe (6%), Home (29%), Education, Car, Utilities
- Total expenses: $48,529

### Screen 5: Transactions List
- Date range filter (Jul 1 - Jul 31, 2023)
- Categorized transaction list
- Each row shows:
  - Date | Category | Description | Amount
- Income and expense items
- Running totals

## Implementation Strategy

### Phase 1: Core Structure
1. Tab bar with 5 tabs (Today, Balance, Budget, Reports, More)
2. Navigation and routing setup
3. Core Data integration for all screens

### Phase 2: Balance Screen
```swift
struct BalanceView: View {
    // Total balance card
    // Segmented bar chart
    // Three sections with account lists
    // Each account shows icon, name, balance
}
```

### Phase 3: Transaction Management
```swift
struct TransactionListView: View {
    // Date range header
    // Grouped by date
    // Swipe actions (settle, delete)
    // Category icons
    // Amount color coding (green/red)
}
```

### Phase 4: Analytics Dashboard
```swift
struct AnalyticsView: View {
    // Swift Charts for donut chart
    // Category breakdown
    // Date range selector
    // Percentage calculations
}
```

### Phase 5: Budget Planning
```swift
struct BudgetView: View {
    // Calendar grid
    // Daily expense tracking
    // Category budgets
    // Progress indicators
}
```

## Design Tokens

### Colors (Dark Theme)
```swift
extension Color {
    static let background = Color(hex: "1C1C1E")
    static let cardBackground = Color(hex: "2C2C2E")
    static let tealAccent = Color(hex: "00BCD4")
    static let incomeGreen = Color(hex: "4CAF50")
    static let expenseRed = Color(hex: "FF5252")
    static let warningYellow = Color(hex: "FFC107")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
}
```

### Layout Constants
```swift
struct Layout {
    static let cardPadding: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let cornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 32
    static let buttonHeight: CGFloat = 44
}
```

### Typography
```swift
extension Font {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 28, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let amount = Font.system(size: 20, weight: .medium).monospacedDigit()
}
```

## Component Library Needed

### Reusable Components
1. BalanceCard - Shows account balance with icon
2. TransactionRow - Single transaction display
3. CategoryIcon - Circular icon with background
4. DateRangePicker - Select date range
5. ProgressBar - Visual progress indicator
6. DonutChart - Expense breakdown chart
7. CalendarGrid - Month view with daily amounts

### Interaction Patterns
- Pull to refresh on all list views
- Swipe left to delete/settle
- Tap to expand details
- Long press for quick actions
- Pinch to zoom on charts

## Testing Requirements
- Screenshot tests for each screen
- Accessibility labels on all elements
- VoiceOver support
- Dynamic Type support
- Dark/Light theme switching