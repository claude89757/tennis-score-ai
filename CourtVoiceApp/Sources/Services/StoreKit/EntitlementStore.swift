import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class EntitlementStore {
  static let monthlyProductID = "com.claude89757.courtvoice.pro.monthly"
  static let annualProductID = "com.claude89757.courtvoice.pro.annual"
  static let productIDs = [monthlyProductID, annualProductID]

  enum PurchaseState: Equatable {
    case idle
    case purchasing(productID: String)
    case pending
    case purchased
    case failed(String)
  }

  private(set) var products: [Product] = []
  private(set) var activeProductIDs: Set<String> = []
  private(set) var isLoadingProducts = false
  private(set) var purchaseState: PurchaseState = .idle
  private(set) var lastRefreshedAt: Date?
  var errorMessage: String?

  private var transactionUpdatesTask: Task<Void, Never>?

  var isPro: Bool {
    activeProductIDs.isDisjoint(with: Self.productIDs) == false
  }

  var annualProduct: Product? {
    products.first { $0.id == Self.annualProductID }
  }

  var monthlyProduct: Product? {
    products.first { $0.id == Self.monthlyProductID }
  }

  deinit {
    transactionUpdatesTask?.cancel()
  }

  func start() async {
    observeTransactionUpdates()
    await reloadProducts()
    await refreshEntitlements()
  }

  func reloadProducts() async {
    isLoadingProducts = true
    defer { isLoadingProducts = false }

    do {
      products = try await Product.products(for: Self.productIDs)
        .sorted { lhs, rhs in
          if lhs.id == Self.annualProductID { return true }
          if rhs.id == Self.annualProductID { return false }
          return lhs.price < rhs.price
        }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func purchase(_ product: Product) async -> Bool {
    purchaseState = .purchasing(productID: product.id)

    do {
      let result = try await product.purchase()
      switch result {
      case .success(let verification):
        let transaction = try verified(verification)
        await transaction.finish()
        await refreshEntitlements()
        purchaseState = .purchased
        return true
      case .pending:
        purchaseState = .pending
        return false
      case .userCancelled:
        purchaseState = .idle
        return false
      @unknown default:
        purchaseState = .failed("The App Store returned an unknown purchase result.")
        return false
      }
    } catch {
      purchaseState = .failed(error.localizedDescription)
      errorMessage = error.localizedDescription
      return false
    }
  }

  func restorePurchases() async {
    do {
      try await AppStore.sync()
      await refreshEntitlements()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshEntitlements() async {
    var active = Set<String>()

    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      guard transaction.revocationDate == nil else { continue }
      if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
        continue
      }
      active.insert(transaction.productID)
    }

    activeProductIDs = active
    lastRefreshedAt = Date()
  }

  private func observeTransactionUpdates() {
    guard transactionUpdatesTask == nil else { return }

    transactionUpdatesTask = Task { [weak self] in
      for await result in Transaction.updates {
        guard let self else { return }
        do {
          let transaction = try self.verified(result)
          await transaction.finish()
          await self.refreshEntitlements()
        } catch {
          self.errorMessage = error.localizedDescription
        }
      }
    }
  }

  private func verified<Value>(_ result: VerificationResult<Value>) throws -> Value {
    switch result {
    case .verified(let value):
      value
    case .unverified:
      throw EntitlementError.failedVerification
    }
  }
}

private enum EntitlementError: LocalizedError {
  case failedVerification

  var errorDescription: String? {
    "The App Store transaction signature could not be verified."
  }
}
