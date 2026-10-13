import ScreenCore

/// Plain-Spanish summaries of a limit, shared by both tabs and the editor.
enum LimitText {
    static func summary(dailyMinutes: Int?, window: BlockWindow?, apps: Int) -> String {
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if let dailyMinutes { parts.append("\(Formatting.minutes(dailyMinutes)) por día") }
        if let window { parts.append("bloqueo \(Formatting.window(window))") }
        return parts.joined(separator: " · ")
    }

    static func summary(_ group: LimitGroup) -> String {
        summary(dailyMinutes: group.dailyMinutes, window: group.window, apps: group.appCount)
    }

    static func summary(_ group: GroupRow) -> String {
        summary(dailyMinutes: group.dailyMinutes, window: group.window, apps: group.appCount)
    }

    /// "45 min por día → 75 min por día", "borrar el límite" or "cambia qué apps entran".
    static func change(from old: LimitGroup, to edit: PendingEdit) -> String {
        if edit.delete { return "borrar el límite" }
        let before = Formatting.limitSummary(dailyMinutes: old.dailyMinutes, window: old.window)
        let after = Formatting.limitSummary(dailyMinutes: edit.group.dailyMinutes, window: edit.group.window)
        return before == after ? "cambia qué apps entran" : "\(before) → \(after)"
    }
}
