public enum SidebarHighlights {
    public static let defaultLimit = 5
}

extension Array where Element: Identifiable {
    func withSelected(_ selectedID: Element.ID?, from all: [Element], limit: Int) -> [Element] {
        guard let selectedID,
            !contains(where: { $0.id == selectedID }),
            let selected = all.first(where: { $0.id == selectedID })
        else { return self }

        var result = self
        if result.count >= limit {
            result.removeLast()
        }
        result.append(selected)
        return result
    }
}
