import Foundation
import Testing
import MechBuddyData

/// The onboarding "What do you have?" screen reads `as-getting-started.json`.
/// Spec: specs/features/OnboardingSpec.md § Kit content.
@Suite("Onboarding kit content")
struct OnboardingContentTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: OnboardingBundleToken.self))
    }

    @Test("Gear tiles are minis, dice, tape, and table, in that order")
    func gearOrder() throws {
        let items = try catalog.gettingStarted().items
        let gear = items.filter { $0.linkURL == nil }.map(\.id)
        #expect(gear == ["minis", "dice", "tape", "maps"])
    }

    @Test("Every gear tile has a short title and a detail line")
    func gearCopy() throws {
        for item in try catalog.gettingStarted().items where item.linkURL == nil {
            #expect(!item.title.isEmpty, "\(item.id)")
            #expect(item.title.count <= 24, "\(item.id) title is too long for a tile")
            #expect(item.detail?.isEmpty == false, "\(item.id)")
        }
    }

    @Test("Ids are unique and links are https")
    func idsAndLinks() throws {
        let items = try catalog.gettingStarted().items
        #expect(Set(items.map(\.id)).count == items.count)
        for item in items {
            guard let link = item.linkURL else { continue }
            let url = try #require(URL(string: link), "\(item.id)")
            #expect(url.scheme == "https", "\(item.id)")
        }
    }
}

private final class OnboardingBundleToken {}
