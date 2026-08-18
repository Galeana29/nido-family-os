import Foundation
import NidoDomain
import NidoRoutineEngine

/// Renders a resolved day as reviewable text.
///
/// This is the artifact a human approves: the engine produces the numbers, the diff shows what moved.
/// Nobody ever writes an expected time by hand.
public struct SnapshotRenderer: Sendable {
    private let timeZone: TimeZone
    private let ruleNames: [RuleID: String]

    public init(template: RoutineTemplate, timeZone: TimeZone) {
        self.timeZone = timeZone
        var names: [RuleID: String] = [:]
        for rule in template.rules { names[rule.id] = rule.name }
        self.ruleNames = names
    }

    public func render(_ result: ResolutionResult) -> String {
        var lines: [String] = []
        lines.append("NIDO scenario snapshot")
        lines.append("policy   \(result.policyVersion)")
        lines.append("day      \(dayText(result.plan.id.anchorDate)) (\(timeZone.identifier))")
        lines.append("mode     \(result.plan.mode.rawValue)")
        lines.append("now      \(clockText(result.plan.generatedAt))")
        lines.append("")
        lines.append(row("occurrence", "pri", "status", "original", "resolved", "reasons"))
        lines.append(String(repeating: "-", count: 118))

        for occurrence in result.plan.occurrences {
            lines.append(row(
                ruleNames[occurrence.ruleID] ?? "?",
                priorityText(occurrence.priority),
                occurrence.status.rawValue,
                windowText(occurrence.originalTiming),
                windowText(occurrence.resolvedTiming),
                occurrence.adjustmentReasons.isEmpty ? "-" : occurrence.adjustmentReasons.map(reasonText).joined(separator: ", ")
            ))
        }

        lines.append("")
        if result.conflicts.isEmpty {
            lines.append("conflicts: none")
        } else {
            for conflict in result.conflicts {
                switch conflict.kind {
                case .unsatisfiable(let ruleID):
                    lines.append("conflict: no free slot for \(ruleNames[ruleID] ?? "?")")
                case .overlap(let first, let second):
                    lines.append("conflict: overlap between \(ruleNames[first] ?? "?") and \(ruleNames[second] ?? "?")")
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func row(_ name: String, _ priority: String, _ status: String, _ original: String, _ resolved: String, _ reasons: String) -> String {
        pad(name, 14) + pad(priority, 5) + pad(status, 11) + pad(original, 19) + pad(resolved, 19) + reasons
    }

    private func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }

    private func windowText(_ timing: ResolvedTiming) -> String {
        "\(clockText(timing.earliest)) \(clockText(timing.preferred)) \(clockText(timing.latest))"
    }

    private func clockText(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func dayText(_ date: LocalDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    private func priorityText(_ priority: RoutinePriority) -> String { "P\(priority.rawValue)" }

    private func reasonText(_ reason: AdjustmentReason) -> String {
        switch reason {
        case .dependencyResolved: return "dependencyResolved"
        case .retainedForStability(let minutes): return "retainedForStability(\(minutes)m)"
        case .shortDuration(_, let minutes): return "shortDuration(\(minutes)m)"
        case .externalCommitmentConflict: return "externalCommitmentConflict"
        case .manualOverride: return "manualOverride"
        case .priorityDisplacement(let priority): return "priorityDisplacement(\(priorityText(priority)))"
        case .omittedForSimplifiedDay: return "omittedForSimplifiedDay"
        case .estimatedFromPlan: return "estimatedFromPlan"
        case .careConstraint: return "careConstraint"
        }
    }
}
