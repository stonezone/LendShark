import SwiftUI
import LendSharkFeature

@main
struct LendSharkApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Validate versions on startup
        let versionResult = VersionManager.shared.validateAllVersions()
        if !versionResult.isValid {
            print("Version validation issues found:")
            for issue in versionResult.issues {
                print("- \(issue.component): \(issue.current) (required: \(issue.required)) [\(issue.severity)]")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}
