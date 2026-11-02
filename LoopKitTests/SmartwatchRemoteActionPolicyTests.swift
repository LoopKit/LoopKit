//
//  SmartwatchRemoteActionPolicyTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

final class SmartwatchRemoteActionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let token = UUID()

    private func context(recommended: Double? = 2.0, maximum: Double? = 5.0, issuedAgo: TimeInterval = 60) -> SmartwatchBolusContext {
        SmartwatchBolusContext(token: token, issuedAt: now.addingTimeInterval(-issuedAgo), recommendedBolus: recommended, maximumBolus: maximum, supportedBolusVolumes: [])
    }

    /// 0.05 U steps, built like the pumps build theirs. Dividing by 0.05 instead
    /// would turn 1.15 into 1.10 (1.15 / 0.05 is 22.999… in floating point).
    private static let supportedVolumes = (1...600).map { Double($0) / 20 }

    /// Rounds down to a supported volume, like OmniPumpManager.
    private func policy(
        limits: SmartwatchBolusPolicy.Limits = .standard,
        allowed: Bool = true,
        context: SmartwatchBolusContext? = nil,
        glucoseAgo: TimeInterval? = 5 * 60,
        deliveries: [SmartwatchBolusPolicy.Delivery] = []
    ) -> SmartwatchBolusPolicy {
        SmartwatchBolusPolicy(
            limits: limits,
            isAllowed: allowed,
            currentContext: context ?? self.context(),
            latestGlucoseDate: glucoseAgo.map { now.addingTimeInterval(-$0) },
            recentDeliveries: deliveries,
            roundToSupportedVolume: { units in Self.supportedVolumes.last { $0 <= units } ?? 0 }
        )
    }

    private func request(_ units: Double, token: UUID? = nil, confirmedAgo: TimeInterval = 5, forced: Bool = false) -> SmartwatchBolusRequest {
        SmartwatchBolusRequest(units: units, contextToken: token ?? self.token, requestedAt: now.addingTimeInterval(-confirmedAgo), isForced: forced)
    }

    func testDeliversARoundedBolusWithinTheRecommendation() throws {
        let units = try policy().evaluate(request(1.53), now: now).get()
        XCTAssertEqual(units, 1.5, accuracy: 0.0001)
    }

    func testKeepsASupportedVolume() {
        XCTAssertEqual(try? policy().evaluate(request(1.15), now: now).get(), 1.15)
    }

    func testAllowsExactlyTheRecommendation() {
        XCTAssertEqual(try? policy().evaluate(request(2.0), now: now).get(), 2.0)
    }

    func testOffUnlessAllowed() {
        XCTAssertEqual(policy(allowed: false).evaluate(request(1), now: now), .failure(.notAllowed))
    }

    func testRejectsInvalidAmounts() {
        XCTAssertEqual(policy().evaluate(request(0), now: now), .failure(.invalidAmount))
        XCTAssertEqual(policy().evaluate(request(-1), now: now), .failure(.invalidAmount))
        XCTAssertEqual(policy().evaluate(request(.nan), now: now), .failure(.invalidAmount))
        XCTAssertEqual(policy().evaluate(request(0.04), now: now), .failure(.invalidAmount), "Rounds to 0 U")
    }

    func testRejectsOldAndFutureRequests() {
        XCTAssertEqual(policy().evaluate(request(1, confirmedAgo: 31), now: now), .failure(.expiredRequest))
        XCTAssertEqual(policy().evaluate(request(1, confirmedAgo: -6), now: now), .failure(.expiredRequest))
        XCTAssertNotNil(try? policy().evaluate(request(1, confirmedAgo: 30), now: now).get())
    }

    func testRejectsAStaleOrMissingContext() {
        XCTAssertEqual(policy().evaluate(request(1, token: UUID()), now: now), .failure(.staleContext))
        XCTAssertEqual(policy(context: context(issuedAgo: 16 * 60)).evaluate(request(1), now: now), .failure(.staleContext))
        let noContext = SmartwatchBolusPolicy(isAllowed: true, currentContext: nil, latestGlucoseDate: now, recentDeliveries: [], roundToSupportedVolume: { $0 })
        XCTAssertEqual(noContext.evaluate(request(1), now: now), .failure(.staleContext))
    }

    func testRefusesWithoutRecentGlucoseEvenForced() {
        XCTAssertEqual(policy(glucoseAgo: nil).evaluate(request(1), now: now), .failure(.noRecentGlucose))
        XCTAssertEqual(policy(glucoseAgo: 16 * 60).evaluate(request(1), now: now), .failure(.noRecentGlucose))
        XCTAssertEqual(policy(glucoseAgo: 16 * 60).evaluate(request(1, forced: true), now: now), .failure(.noRecentGlucose))
        XCTAssertNotNil(try? policy(glucoseAgo: 15 * 60).evaluate(request(1), now: now).get())
    }

    func testBolusIncrementIsTheSmallestStep() {
        XCTAssertEqual(SmartwatchStatusSnapshot.bolusIncrement(of: [0.05, 0.1, 0.15]) ?? 0, 0.05, accuracy: 0.0001)
        XCTAssertEqual(SmartwatchStatusSnapshot.bolusIncrement(of: [0.1, 0.2, 0.25, 0.3]) ?? 0, 0.05, accuracy: 0.0001)
        XCTAssertEqual(SmartwatchStatusSnapshot.bolusIncrement(of: [0.1]), 0.1)
        XCTAssertNil(SmartwatchStatusSnapshot.bolusIncrement(of: []))
    }

    func testStandardLimitsByDefault() {
        let limits = SmartwatchRemoteActionLimits.standard
        XCTAssertEqual(limits.bolusPolicyLimits, .standard)
        XCTAssertEqual(limits.carbEntryPolicyLimits, .standard)
        XCTAssertTrue(limits.bolus.requiresContextToken)
        XCTAssertTrue(limits.bolus.capsAtRecommendation)
    }

    func testAPluginsRequestWindowAppliesToBothPolicies() {
        let limits = SmartwatchRemoteActionLimits(requestWindow: SmartwatchRequestWindow(maximumAge: 120, maximumClockSkew: 60))
        XCTAssertEqual(limits.bolusPolicyLimits.requestWindow.maximumAge, 120)
        XCTAssertEqual(limits.carbEntryPolicyLimits.requestWindow.maximumClockSkew, 60)
        XCTAssertNotNil(try? policy(limits: limits.bolusPolicyLimits).evaluate(request(1, confirmedAgo: 90), now: now).get())
    }

    func testWithoutTheTokenRequirementTheCurrentContextStillApplies() {
        var limits = SmartwatchBolusPolicy.Limits.standard
        limits.requiresContextToken = false
        XCTAssertNotNil(try? policy(limits: limits).evaluate(request(1, token: UUID()), now: now).get())
        XCTAssertEqual(policy(limits: limits, context: context(issuedAgo: 16 * 60)).evaluate(request(1, token: UUID()), now: now), .failure(.staleContext))
        XCTAssertEqual(policy(limits: limits).evaluate(request(1, token: UUID(), forced: true), now: now), .success(1))
        XCTAssertEqual(policy(limits: limits).evaluate(request(2.5, token: UUID()), now: now), .failure(.exceedsRecommendation))
    }

    func testWithoutTheRecommendationCapTheMaximumBolusStillApplies() {
        var limits = SmartwatchBolusPolicy.Limits.standard
        limits.capsAtRecommendation = false
        let policy = policy(limits: limits, context: context(recommended: 1, maximum: 5))
        XCTAssertEqual(try? policy.evaluate(request(4), now: now).get(), 4)
        XCTAssertEqual(policy.evaluate(request(5.5), now: now), .failure(.exceedsMaximumBolus))
    }

    func testRejectsMoreThanTheMaximumBolus() {
        let policy = policy(context: context(recommended: 8, maximum: 5))
        XCTAssertEqual(policy.evaluate(request(5.5), now: now), .failure(.exceedsMaximumBolus))
        let noMaximum = self.policy(context: context(maximum: nil))
        XCTAssertEqual(noMaximum.evaluate(request(1), now: now), .failure(.exceedsMaximumBolus))
    }

    func testRejectsMoreThanTheRecommendation() {
        XCTAssertEqual(policy().evaluate(request(2.1), now: now), .failure(.exceedsRecommendation))
        let noRecommendation = policy(context: context(recommended: nil))
        XCTAssertEqual(noRecommendation.evaluate(request(0.5), now: now), .failure(.exceedsRecommendation))
    }

    // A forced request skips only the recommendation: the maximum bolus, the
    // permission and the rate limits still apply.
    func testForcedRequestSkipsOnlyTheRecommendation() {
        let noRecommendation = policy(context: context(recommended: nil))
        XCTAssertEqual(try? noRecommendation.evaluate(request(0.1, forced: true), now: now).get(), 0.1)
        XCTAssertEqual(noRecommendation.evaluate(request(100, forced: true), now: now), .failure(.exceedsMaximumBolus))
        XCTAssertEqual(policy(allowed: false).evaluate(request(0.1, forced: true), now: now), .failure(.notAllowed))
        let recent = policy(context: context(recommended: nil), deliveries: [.init(date: now.addingTimeInterval(-60), units: 0.1)])
        XCTAssertEqual(recent.evaluate(request(0.1, forced: true), now: now), .failure(.rateLimited))
    }

    func testRateLimitsWatchBoluses() {
        let recent = [SmartwatchBolusPolicy.Delivery(date: now.addingTimeInterval(-10 * 60), units: 1)]
        XCTAssertEqual(policy(deliveries: recent).evaluate(request(1), now: now), .failure(.rateLimited))
        let older = [SmartwatchBolusPolicy.Delivery(date: now.addingTimeInterval(-16 * 60), units: 1)]
        XCTAssertNotNil(try? policy(deliveries: older).evaluate(request(1), now: now).get())
    }

    func testLimitsTheDailyTotal() {
        // Daily limit is 2 × the 5 U maximum bolus = 10 U.
        let earlier = [
            SmartwatchBolusPolicy.Delivery(date: now.addingTimeInterval(-20 * 60 * 60), units: 5),
            SmartwatchBolusPolicy.Delivery(date: now.addingTimeInterval(-2 * 60 * 60), units: 4),
        ]
        XCTAssertEqual(policy(deliveries: earlier).evaluate(request(1.5), now: now), .failure(.dailyLimitReached))
        XCTAssertNotNil(try? policy(deliveries: earlier).evaluate(request(1), now: now).get())
        let yesterday = [SmartwatchBolusPolicy.Delivery(date: now.addingTimeInterval(-25 * 60 * 60), units: 9)]
        XCTAssertNotNil(try? policy(deliveries: yesterday).evaluate(request(2), now: now).get())
    }

    func testAHostCanTightenTheLimits() {
        var limits = SmartwatchBolusPolicy.Limits.standard
        limits.requestWindow.maximumAge = 10
        limits.minimumInterval = 60 * 60
        let strict = SmartwatchBolusPolicy(
            limits: limits,
            isAllowed: true,
            currentContext: context(),
            latestGlucoseDate: now,
            recentDeliveries: [.init(date: now.addingTimeInterval(-30 * 60), units: 0.5)],
            roundToSupportedVolume: { $0 }
        )
        XCTAssertEqual(strict.evaluate(request(1, confirmedAgo: 15), now: now), .failure(.expiredRequest))
        XCTAssertEqual(strict.evaluate(request(1), now: now), .failure(.rateLimited))
    }

    // MARK: - Bolus context issuer

    private func inputs(recommended: Double? = 2, glucoseDate: Date? = nil) -> SmartwatchBolusContextIssuer.Inputs {
        .init(recommendedBolus: recommended, maximumBolus: 5, supportedBolusVolumes: [0.05], latestGlucoseDate: glucoseDate ?? now)
    }

    func testIssuerKeepsTheTokenWhileTheInputsAreUnchanged() {
        var issuer = SmartwatchBolusContextIssuer()
        let first = issuer.context(for: inputs(), now: now)
        XCTAssertEqual(issuer.context(for: inputs(), now: now.addingTimeInterval(60)).token, first.token)
        XCTAssertNotEqual(issuer.context(for: inputs(recommended: 1), now: now).token, first.token)
        XCTAssertNotEqual(issuer.context(for: inputs(recommended: 1, glucoseDate: now.addingTimeInterval(300)), now: now).token, first.token)
    }

    func testIssuerTreatsNoPositiveRecommendationAsNone() {
        var issuer = SmartwatchBolusContextIssuer()
        XCTAssertNil(issuer.context(for: inputs(recommended: 0), now: now).recommendedBolus)
        XCTAssertNil(issuer.context(for: inputs(recommended: -0.5), now: now).recommendedBolus)
    }

    func testABolusSpendsTheContextAndAResendIsInProgress() {
        var issuer = SmartwatchBolusContextIssuer()
        let context = issuer.context(for: inputs(), now: now)
        let bolus = SmartwatchBolusRequest(units: 1, contextToken: context.token, requestedAt: now)
        XCTAssertFalse(issuer.isDelivering(bolus))
        issuer.beginDelivery(of: bolus)
        XCTAssertNil(issuer.current, "Spent: the same request can't pass the policy again")
        XCTAssertTrue(issuer.isDelivering(bolus))
        issuer.endDelivery()
        XCTAssertFalse(issuer.isDelivering(bolus))
        XCTAssertNotEqual(issuer.context(for: inputs(), now: now).token, context.token, "A new context after a bolus")
    }

    func testDeliveriesRoundTripAsJSON() throws {
        let deliveries = [SmartwatchBolusPolicy.Delivery(date: now, units: 1.25)]
        let decoded = try JSONDecoder().decode([SmartwatchBolusPolicy.Delivery].self, from: JSONEncoder().encode(deliveries))
        XCTAssertEqual(decoded, deliveries)
    }

    // MARK: - Carb entry policy

    private func carbs(_ grams: Double, confirmedAgo: TimeInterval = 5) -> SmartwatchCarbEntryRequest {
        SmartwatchCarbEntryRequest(grams: grams, requestedAt: now.addingTimeInterval(-confirmedAgo))
    }

    private func carbPolicy(allowed: Bool = true, lastEntry: Date? = nil) -> SmartwatchCarbEntryPolicy {
        SmartwatchCarbEntryPolicy(isAllowed: allowed, maximumGrams: 100, lastEntry: lastEntry)
    }

    func testAddsAllowedCarbs() {
        XCTAssertEqual(try? carbPolicy().evaluate(carbs(30), now: now).get(), 30)
        XCTAssertEqual(try? carbPolicy().evaluate(carbs(100), now: now).get(), 100)
    }

    func testRejectsCarbsThatArentAllowedOrValid() {
        XCTAssertEqual(carbPolicy(allowed: false).evaluate(carbs(30), now: now), .failure(.notAllowed))
        XCTAssertEqual(carbPolicy().evaluate(carbs(0), now: now), .failure(.invalidAmount))
        XCTAssertEqual(carbPolicy().evaluate(carbs(.nan), now: now), .failure(.invalidAmount))
        XCTAssertEqual(carbPolicy().evaluate(carbs(101), now: now), .failure(.exceedsMaximum))
    }

    func testRejectsOldAndFutureCarbRequests() {
        XCTAssertEqual(carbPolicy().evaluate(carbs(30, confirmedAgo: 31), now: now), .failure(.expiredRequest))
        XCTAssertEqual(carbPolicy().evaluate(carbs(30, confirmedAgo: -6), now: now), .failure(.expiredRequest))
    }

    func testRateLimitsCarbEntries() {
        XCTAssertEqual(carbPolicy(lastEntry: now.addingTimeInterval(-10 * 60)).evaluate(carbs(30), now: now), .failure(.rateLimited))
        XCTAssertEqual(try? carbPolicy(lastEntry: now.addingTimeInterval(-16 * 60)).evaluate(carbs(30), now: now).get(), 30)
    }

    // MARK: - Request window

    func testTheRequestWindowAcceptsRequestsUpToItsEdges() {
        let window = SmartwatchRequestWindow.standard
        XCTAssertTrue(window.contains(now.addingTimeInterval(-30), now: now))
        XCTAssertFalse(window.contains(now.addingTimeInterval(-30.5), now: now))
        XCTAssertTrue(window.contains(now.addingTimeInterval(5), now: now))
        XCTAssertFalse(window.contains(now.addingTimeInterval(5.5), now: now))
    }

    func testAStricterWindowAppliesToBothPolicies() {
        let window = SmartwatchRequestWindow(maximumAge: 10)
        let bolus = SmartwatchBolusPolicy(
            limits: .init(requestWindow: window),
            isAllowed: true,
            currentContext: context(),
            latestGlucoseDate: now,
            recentDeliveries: [],
            roundToSupportedVolume: { $0 }
        )
        XCTAssertEqual(bolus.evaluate(request(1, confirmedAgo: 15), now: now), .failure(.expiredRequest))
        let carbs = SmartwatchCarbEntryPolicy(limits: .init(requestWindow: window), isAllowed: true, maximumGrams: 100, lastEntry: nil)
        XCTAssertEqual(carbs.evaluate(self.carbs(30, confirmedAgo: 15), now: now), .failure(.expiredRequest))
    }
}
