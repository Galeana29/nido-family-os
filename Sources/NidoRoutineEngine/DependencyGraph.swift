import Foundation
import NidoDomain

enum DependencyGraph {
    /// Topological order over rule references, so a rule is always resolved after everything it depends on.
    ///
    /// Ties are broken by declaration order rather than by hash order: two runs over the same template
    /// must produce not just a valid order but the *same* order, or determinism is only apparent.
    /// A cycle is a configuration error, not something to resolve arbitrarily.
    static func topologicalOrder(rules: [RoutineRule]) throws -> [RoutineRule] {
        var indexByID: [RuleID: Int] = [:]
        for (index, rule) in rules.enumerated() { indexByID[rule.id] = index }

        var remainingDependencies = [Int](repeating: 0, count: rules.count)
        var dependents: [[Int]] = Array(repeating: [], count: rules.count)

        for (index, rule) in rules.enumerated() {
            for reference in rule.references {
                guard let referenceIndex = indexByID[reference] else {
                    throw ResolutionError.unknownReference(reference)
                }
                dependents[referenceIndex].append(index)
                remainingDependencies[index] += 1
            }
        }

        var queue = (0..<rules.count).filter { remainingDependencies[$0] == 0 }
        var ordered: [RoutineRule] = []
        var head = 0
        while head < queue.count {
            let node = queue[head]
            head += 1
            ordered.append(rules[node])
            for dependent in dependents[node].sorted() {
                remainingDependencies[dependent] -= 1
                if remainingDependencies[dependent] == 0 { queue.append(dependent) }
            }
        }

        guard ordered.count == rules.count else { throw ResolutionError.dependencyCycle }
        return ordered
    }
}
