    private func invalidatePerceptionWork(preserveRGBHistoryWork: Bool = false, preserveCapturedText: Bool = false) {
        if !preserveRGBHistoryWork && !preserveCapturedText { retireCapturedTextSource() }
        invalidateNativeLocalization(.trackingUnavailable)
        #if DEBUG
        latestGroundGeometry = nil; lastGroundGeometryAt = -.infinity
        #endif
        cancelVoiceRoomScanConfirmation()
        if !preserveRGBHistoryWork { cancelContextualCapabilities() }
        #if BLIND_FAMILIAR_PEOPLE
        if !preserveRGBHistoryWork && familiarPeople.enabled && familiarPeople.hasActiveWork { familiarPeople.cancel(announce: false) }
        #endif
        // Depth-only loss retires spatial work, not a still-valid RGB colour request.
        // Full camera/session invalidation still cancels colour and rotates its generation.
        if currencyActive || (!preserveRGBHistoryWork && (colorActive || (readingTool != nil && !preserveCapturedText))) || currencyRetake.isPending { cancelDescription() }
        perceptionGeneration = UUID(); recallInFlight = false; learningItem = nil
        if !preserveRGBHistoryWork { backgroundPerception.invalidate(); passiveObservationGeneration = UUID() }
        if let speech = recordedSpotSpeech { feedback.stopRequestedSpeech(speech.id); recordedSpotSpeech = nil }
        if let pending = pendingPassiveNotice {
            companion.release("object-goal:" + pending.key)
            pendingPassiveNotice = nil
            _ = feedback.stopInformation(announceCancellation: false)
        }
        observedObjects.invalidateGeometry()
        latestViewTexts = []; latestViewTextCapturedAt = -.infinity; latestViewTextObservation = nil
        roomRecall.cancelPendingWork(); itemAppearance.cancelPendingWork()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Tracking loss retires selected-owner evidence even on throttled frames.
        if case .normal = frame.camera.trackingState {} else { invalidateNativeLocalization(.trackingUnavailable) }
        // Tracking loss retires the issuer even when this frame is throttled below.
        if case .normal = frame.camera.trackingState {} else {
            journeys.breakTracking()
            nativeObservations.trackingLost()
            clearBoardingReading() // Retire transferred/passive travel even when no reader tool remains.
            // Retire old OCR even if depth was already unavailable and the hazard
            // category does not change. This runs before frame throttling.
            if readingTool != nil && !usesCapturedText { stopReadingTool(announce: false) }
        }
        if places.scanning, let scanSession = UUID(uuidString: observationFrameID) {
            places.observeRegistrationFrame(frame, sessionID: scanSession, now: ProcessInfo.processInfo.systemUptime)
        }
        guard running, !simulation, !places.scanning, frame.timestamp - lastProcessed >= 1.0 / 15 else { return }

    private var usesCapturedText: Bool { readingTool == .liveText || readingTool == .document }
