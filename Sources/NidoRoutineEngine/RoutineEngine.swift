import Foundation
import NidoDomain

public struct ResolutionPolicy: Sendable, Equatable { public let materialityThresholdMinutes:Int; public init(materialityThresholdMinutes:Int=5){self.materialityThresholdMinutes=materialityThresholdMinutes} }
public enum ResolutionError: Error, Equatable { case invalidOffsets, infeasibleWindow }
public struct RoutineEngine: Sendable {
    public let policy: ResolutionPolicy
    public init(policy:ResolutionPolicy=ResolutionPolicy()){self.policy=policy}
    public func resolveDependent(referenceEnd:Date,minMinutes:Int,preferredMinutes:Int,maxMinutes:Int,previousPreferred:Date?=nil) throws -> ResolvedTiming {
        guard minMinutes <= preferredMinutes, preferredMinutes <= maxMinutes else { throw ResolutionError.invalidOffsets }
        let earliest=referenceEnd.addingTimeInterval(TimeInterval(minMinutes*60)); let candidate=referenceEnd.addingTimeInterval(TimeInterval(preferredMinutes*60)); let latest=referenceEnd.addingTimeInterval(TimeInterval(maxMinutes*60))
        guard earliest <= latest else { throw ResolutionError.infeasibleWindow }
        let preferred:Date
        if let previousPreferred { let delta=Int(abs(candidate.timeIntervalSince(previousPreferred))/60); preferred=(delta < policy.materialityThresholdMinutes && previousPreferred >= earliest && previousPreferred <= latest) ? previousPreferred : candidate } else { preferred=candidate }
        return ResolvedTiming(earliest:earliest,preferred:preferred,latest:latest)
    }
}
