import SwiftUI
import SwiftData

@main
struct EasyFlyApp: App {
    // Provide a SwiftData model container so views using @Query/@Model work at runtime
    var modelContainer: ModelContainer = try! ModelContainer(for: [Item.self])

    var body: some Scene {
        WindowGroup {
            AppFlowView()
                .modelContainer(modelContainer)
        }
    }
}
