import SwiftUI

extension View {
    @ViewBuilder
    func lendSharkAutocapitalizationWords() -> some View {
        #if os(iOS)
        self.autocapitalization(.words)
        #else
        self
        #endif
    }

    @ViewBuilder
    func lendSharkKeyboardTypeDecimalPad() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func lendSharkKeyboardTypeNumberPad() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func lendSharkNavigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
