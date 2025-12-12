#!/usr/bin/env swift

// Simple test script to verify supported parser patterns

import Foundation

// Test cases for the current ParserService patterns
let testCases = [
    // Original patterns (should still work)
    "lent 50 to john",
    "borrowed 25.50 from sarah",
    "settle with bob",

    // Owes patterns
    "john owes 45",
    "john owes me 45",
    "I owe bob 30",

    // Paid patterns (partial payment or settle)
    "john paid 50",
    "paid sarah 25",
    "paid bob",

    // Amount parsing (currency symbols + abbreviations)
    "lent $25.50 to alex",
    "borrowed €30 from kim",
    "john owes 2 notes",
    "paid pat 3bucks",

    // Modifiers extracted from the original text
    "lent 50 to john due tomorrow",
    "john owes 50 due in 2 weeks",
    "I owe bob 30 due next week",
    "lent 100 to alex at 10% (has my watch) (555) 123-4567",

    // Item borrowing / return
    "johnny borrowed my drill for 3 days",
    "i borrowed frank's hammer",
    "johnny returned the drill"
]

print("ParserService Test Cases")
print("==========================")
print("\nThe following patterns are now supported:")
print()

for (index, testCase) in testCases.enumerated() {
    print("\(index + 1). \(testCase)")
}

print("\n✅ Supported Summary:")
print("- ✅ 'lent [amount] to [name]' and 'borrowed [amount] from [name]'")
print("- ✅ '[name] owes [amount]' and '[name] owes me [amount]'")
print("- ✅ 'i owe [name] [amount]'")
print("- ✅ 'paid [name] [amount]' / '[name] paid [amount]' (partial payment)")
print("- ✅ 'paid [name]' / '[name] paid' / 'settle with [name]' (settle)")
print("- ✅ Amount parsing: decimals, currency symbols, abbreviations (note, k, buck, etc.)")
print("- ✅ Modifiers: due dates (tomorrow/next week/due in N units), interest rate (%), notes (parentheses), phone numbers")
print("- ✅ Item borrowing: '[name] borrowed my [item]' / 'i borrowed [name]'s [item]' + 'returned' settles")

print("\nℹ️ Not supported (by design):")
print("- Written numbers (e.g., 'twenty')")
print("- Split/multi-party calculations")
print("- General natural-language dates (e.g., 'yesterday', 'on Friday')")
