import XCTest

@testable import CourtVoiceApp

@MainActor
final class EntitlementStoreTests: XCTestCase {
  func testProductIdentifiersMatchCheckedInStoreKitConfiguration() {
    XCTAssertEqual(
      EntitlementStore.monthlyProductID,
      "com.claude89757.courtvoice.pro.monthly"
    )
    XCTAssertEqual(
      EntitlementStore.annualProductID,
      "com.claude89757.courtvoice.pro.annual"
    )
    XCTAssertEqual(
      Set(EntitlementStore.productIDs),
      [
        "com.claude89757.courtvoice.pro.monthly",
        "com.claude89757.courtvoice.pro.annual",
      ]
    )
  }

  func testIsProRequiresAnActiveKnownProduct() {
    let store = EntitlementStore()
    XCTAssertFalse(store.isPro)

    store.applyVerifiedProductIDsForTesting([EntitlementStore.monthlyProductID])
    XCTAssertTrue(store.isPro)

    store.applyVerifiedProductIDsForTesting(["unrelated.product"])
    XCTAssertFalse(store.isPro)
  }

  func testReloadProductsUsesLocalStoreKitConfiguration() async {
    let store = EntitlementStore()
    await store.reloadProducts()

    let loadedIDs = Set(store.products.map(\.id))
    XCTAssertTrue(
      loadedIDs.isSubset(of: Set(EntitlementStore.productIDs)),
      "Unexpected StoreKit product IDs: \(loadedIDs)"
    )
    if loadedIDs.isEmpty == false {
      XCTAssertEqual(loadedIDs, Set(EntitlementStore.productIDs))
    }
  }
}
