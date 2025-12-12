import SwiftUI
import LendSharkFeature

@main
struct LendSharkApp: App {
    private let persistenceController: PersistenceController
    @StateObject private var settingsService: SettingsService
    
    init() {
        // Initialize persistence first
        let persistence = PersistenceController()
        self.persistenceController = persistence
        
        // Create settings service
        let settings = SettingsService()
        _settingsService = StateObject(wrappedValue: settings)
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settingsService)
                .preferredColorScheme(settingsService.darkMode ? .dark : .light)
        }
    }
}
