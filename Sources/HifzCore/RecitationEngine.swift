public actor RecitationEngine {
    private var reducer: RecitationStateReducer
    private var storedSnapshots: [RecitationSnapshot]

    public init() {
        self.reducer = RecitationStateReducer()
        self.storedSnapshots = []
    }

    public var snapshots: [RecitationSnapshot] {
        storedSnapshots
    }

    public func start(_ request: RecitationSessionRequest) {
        emit(.startRequested(request))
        emit(.permissionGranted)
        emit(.placeLocked(ayah: request.startAyah, word: 1))
    }

    public func stop() {
        emit(.stop)
    }

    private func emit(_ action: RecitationAction) {
        storedSnapshots.append(reducer.reduce(action))
    }
}
