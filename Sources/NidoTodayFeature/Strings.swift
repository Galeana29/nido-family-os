import Foundation
import NidoDomain

/// The two languages this household actually speaks.
///
/// Copy lives here rather than in a String Catalog because the catalog needs Xcode and this has to
/// stay testable on CI. When the app target exists these move across unchanged — the wording is the
/// part that was expensive, not the file format.
public enum Language: String, Sendable, CaseIterable {
    case english = "en"
    case spanish = "es"
}

/// All caregiver-facing copy, held to `docs/design/content-style.md`: calm, specific, never guilty.
public enum Strings {
    public static func greeting(hour: Int, _ language: Language) -> String {
        switch (hour, language) {
        case (..<12, .english): return "Good morning"
        case (..<12, .spanish): return "Buenos días"
        case (..<19, .english): return "Good afternoon"
        case (..<19, .spanish): return "Buenas tardes"
        case (_, .english): return "Good evening"
        case (_, .spanish): return "Buenas noches"
        }
    }

    public static func now(_ language: Language) -> String {
        language == .english ? "NOW" : "AHORA"
    }

    public static func status(_ status: OccurrenceStatus, _ language: Language) -> String {
        switch (status, language) {
        case (.upcoming, .english): return "Upcoming"
        case (.upcoming, .spanish): return "Próximo"
        case (.ready, .english): return "Ready"
        case (.ready, .spanish): return "Listo"
        case (.active, .english): return "In progress"
        case (.active, .spanish): return "En curso"
        case (.completed, .english): return "Done"
        case (.completed, .spanish): return "Terminado"
        case (.skipped, .english): return "Not done"
        case (.skipped, .spanish): return "No realizado"
        case (.cancelled, .english): return "Not needed today"
        case (.cancelled, .spanish): return "No hizo falta hoy"
        }
    }

    public static func mealRating(_ rating: MealRating, _ language: Language) -> String {
        switch (rating, language) {
        case (.none, .english): return "Nothing"
        case (.none, .spanish): return "Nada"
        case (.taste, .english): return "Tasted"
        case (.taste, .spanish): return "Probó"
        case (.small, .english): return "A little"
        case (.small, .spanish): return "Poquito"
        case (.normal, .english): return "Usual amount"
        case (.normal, .spanish): return "Cantidad habitual"
        case (.more, .english): return "Wanted more"
        case (.more, .spanish): return "Quiso más"
        }
    }

    public static func actionLabel(_ action: TodayAction, _ language: Language) -> String {
        switch (action, language) {
        case (.startSleep, .english): return "Asleep"
        case (.startSleep, .spanish): return "Se durmió"
        case (.endSleep, .english): return "Woke up"
        case (.endSleep, .spanish): return "Despertó"
        case (.startMeal, .english): return "Start"
        case (.startMeal, .spanish): return "Empezar"
        case (.finishMeal, .english): return "Finish"
        case (.finishMeal, .spanish): return "Terminar"
        case (.rateMeal, .english): return "How did it go?"
        case (.rateMeal, .spanish): return "¿Cómo le fue?"
        case (.delay, .english): return "Later"
        case (.delay, .spanish): return "Más tarde"
        case (.skip, .english): return "Not today"
        case (.skip, .spanish): return "Hoy no"
        }
    }

    // MARK: - Day state

    public static func onTrack(_ language: Language) -> String {
        language == .english ? "Everything is roughly on track." : "Todo va más o menos en orden."
    }

    public static func runningLater(minutes: Int, _ language: Language) -> String {
        language == .english
            ? "Today is running about \(minutes) minutes later — already adjusted."
            : "Hoy vamos como \(minutes) minutos más tarde — ya está ajustado."
    }

    public static func runningEarlier(minutes: Int, _ language: Language) -> String {
        language == .english
            ? "Today is running about \(minutes) minutes ahead — already adjusted."
            : "Hoy vamos como \(minutes) minutos adelantados — ya está ajustado."
    }

    public static func shortNap(_ language: Language) -> String {
        language == .english
            ? "The last nap was short, so bedtime may be earlier."
            : "La última siesta fue corta, así que la hora de dormir puede adelantarse."
    }

    public static func simplifiedDay(_ language: Language) -> String {
        language == .english
            ? "Simplified day: the essentials only."
            : "Día simplificado: solo lo esencial."
    }

    public static func nothingLeft(_ language: Language) -> String {
        language == .english ? "Nothing else is planned for today." : "Ya no queda nada planeado para hoy."
    }

    // MARK: - Explanations
    //
    // Every number in these sentences is injected from the engine's structured output. The wording may
    // change; the figures are never regenerated or rounded into something the engine did not decide.

    public static func explanation(for reasons: [AdjustmentReason], _ language: Language) -> String? {
        for reason in reasons {
            switch reason {
            case .shortDuration(_, let minutes):
                return language == .english
                    ? "That nap ran \(minutes) minutes, so the rest of the day moved with it."
                    : "Esa siesta duró \(minutes) minutos, así que el resto del día se movió con ella."
            case .actualEventRecorded(let delta) where delta > 0:
                return language == .english
                    ? "Started \(delta) minutes after the plan, and the day followed."
                    : "Empezó \(delta) minutos después del plan, y el día lo siguió."
            case .actualEventRecorded(let delta) where delta < 0:
                return language == .english
                    ? "Started \(abs(delta)) minutes before the plan, and the day followed."
                    : "Empezó \(abs(delta)) minutos antes del plan, y el día lo siguió."
            case .externalCommitmentConflict:
                return language == .english
                    ? "Moved to leave room for something already on the calendar."
                    : "Se movió para dejar espacio a algo que ya estaba en el calendario."
            case .dependencyResolved:
                return language == .english
                    ? "Timed from when the last nap actually ended."
                    : "Calculado desde que terminó la siesta anterior de verdad."
            case .manualOverride:
                return language == .english ? "You moved this one." : "Tú moviste esto."
            case .omittedForSimplifiedDay:
                return language == .english
                    ? "Left out of today's simplified plan."
                    : "Quedó fuera del plan simplificado de hoy."
            case .careConstraint:
                return language == .english
                    ? "Held in place by a care plan instruction."
                    : "Fijado por una instrucción del plan de cuidado."
            case .retainedForStability, .priorityDisplacement, .estimatedFromPlan, .actualEventRecorded:
                continue
            }
        }
        return nil
    }

    // MARK: - Notices

    public static func conflictNotice(_ title: String, _ language: Language) -> String {
        language == .english
            ? "\(title) overlaps something else. Worth a look when you have a moment."
            : "\(title) se encima con otra cosa. Vale la pena revisarlo cuando puedas."
    }

    public static func unsatisfiableNotice(_ title: String, _ language: Language) -> String {
        language == .english
            ? "There was no free slot for \(title) today."
            : "Hoy no hubo un hueco libre para \(title)."
    }
}
