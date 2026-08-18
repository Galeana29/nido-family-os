import Foundation
import NidoDomain

public struct ResolutionPolicy: Sendable, Equatable {
    /// Movements smaller than this are not worth redrawing the caregiver's day over.
    public let materialityThresholdMinutes: Int
    public let version: EnginePolicyVersion
    public init(materialityThresholdMinutes: Int = 5, version: EnginePolicyVersion = .v0) {
        self.materialityThresholdMinutes = materialityThresholdMinutes
        self.version = version
    }
}

public enum ResolutionError: Error, Equatable {
    case invalidOffsets
    case infeasibleWindow
    /// A rule references another rule that is not in the template.
    case unknownReference(RuleID)
    /// A → B → C → A. Invalid configuration rather than something to break arbitrarily.
    case dependencyCycle
    /// An event whose payload does not match its type, e.g. `napStarted` carrying a meal payload.
    case inconsistentEventPayload(EventID)
    /// A rule whose guardrails are inverted, e.g. an anchor whose earliest is after its latest.
    case malformedWindow(RuleID)
}
/// Timing plus the structured reasons behind it, so explanations never have to be reconstructed after the fact.
public struct DependentResolution: Sendable, Equatable {
    public let timing: ResolvedTiming
    public let adjustmentReasons: [AdjustmentReason]
    public init(timing:ResolvedTiming, adjustmentReasons:[AdjustmentReason]){ self.timing=timing; self.adjustmentReasons=adjustmentReasons }
}
public struct RoutineEngine: Sendable {
    public let policy: ResolutionPolicy
    public init(policy:ResolutionPolicy=ResolutionPolicy()){self.policy=policy}
    public func resolveDependent(referenceEnd:Date,minMinutes:Int,preferredMinutes:Int,maxMinutes:Int,previousPreferred:Date?=nil,reference:OccurrenceID?=nil) throws -> DependentResolution {
        guard minMinutes <= preferredMinutes, preferredMinutes <= maxMinutes else { throw ResolutionError.invalidOffsets }
        let earliest=referenceEnd.addingTimeInterval(TimeInterval(minMinutes*60)); let candidate=referenceEnd.addingTimeInterval(TimeInterval(preferredMinutes*60)); let latest=referenceEnd.addingTimeInterval(TimeInterval(maxMinutes*60))
        guard earliest <= latest else { throw ResolutionError.infeasibleWindow }
        var reasons:[AdjustmentReason]=[]
        if let reference { reasons.append(.dependencyResolved(reference:reference)) }
        let preferred:Date
        if let previousPreferred {
            let delta=Int(abs(candidate.timeIntervalSince(previousPreferred))/60)
            if delta < policy.materialityThresholdMinutes && previousPreferred >= earliest && previousPreferred <= latest {
                preferred=previousPreferred
                reasons.append(.retainedForStability(deltaMinutes:delta))
            } else { preferred=candidate }
        } else { preferred=candidate }
        return DependentResolution(timing:ResolvedTiming(earliest:earliest,preferred:preferred,latest:latest),adjustmentReasons:reasons)
    }
}
