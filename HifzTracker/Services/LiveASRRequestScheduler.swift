import HifzCore

struct LiveASRRequestScheduler {
    private var hasActiveRequest = false
    private var pendingWindow: LiveASRAudioWindow?

    mutating func submit(_ window: LiveASRAudioWindow) -> LiveASRAudioWindow? {
        guard !hasActiveRequest else {
            pendingWindow = window
            return nil
        }

        hasActiveRequest = true
        return window
    }

    mutating func completeActiveRequest() -> LiveASRAudioWindow? {
        guard let pendingWindow else {
            hasActiveRequest = false
            return nil
        }

        self.pendingWindow = nil
        hasActiveRequest = true
        return pendingWindow
    }

    mutating func reset() {
        hasActiveRequest = false
        pendingWindow = nil
    }
}
