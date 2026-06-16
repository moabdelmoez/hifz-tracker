struct LiveASRRequestScheduler {
    private var hasActiveRequest = false
    private var pendingSamples: [Float]?

    mutating func submit(_ samples: [Float]) -> [Float]? {
        guard !hasActiveRequest else {
            pendingSamples = samples
            return nil
        }

        hasActiveRequest = true
        return samples
    }

    mutating func completeActiveRequest() -> [Float]? {
        guard let pendingSamples else {
            hasActiveRequest = false
            return nil
        }

        self.pendingSamples = nil
        hasActiveRequest = true
        return pendingSamples
    }

    mutating func reset() {
        hasActiveRequest = false
        pendingSamples = nil
    }
}
