import Foundation
import NidoDomain

public struct ResolutionPolicy: Sendable, Equatable { public let materialityThresholdMinutes:Int; public init(materialityThresholdMinutes:Int=5){self.materialityThresholdMinutes=materialityThresholdMinutes} }
public enum ResolutionError: Error, Equatable { case invalidOffsets, infeasibleWindow }
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
