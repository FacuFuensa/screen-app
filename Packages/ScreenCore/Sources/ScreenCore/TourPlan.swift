/// The guided first-run tour. `invite` and `share` are two screens of the same
/// visible step ("Paso 7 de 7").
public enum TourStep: Int, CaseIterable, Codable, Sendable {
    case permissions = 1, newLimit, name, apps, minutes, save, invite, share

    public static let total = 7
    public var number: Int { min(rawValue, Self.total) }
}

public enum TourPlan {
    /// Where the tour starts for someone in this state; nil when there is nothing
    /// left to teach (existing users never see it).
    public static func firstPending(authorized: Bool, groupCount: Int, paired: Bool) -> TourStep? {
        if !authorized { return .permissions }
        if groupCount == 0 { return .newLimit }
        if !paired { return .invite }
        return nil
    }

    public static func next(after step: TourStep) -> TourStep? {
        TourStep(rawValue: step.rawValue + 1)
    }
}
