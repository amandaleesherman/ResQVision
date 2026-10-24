//
//  EmergencyContact.swift
//  EmergencyFirst
//
//  Central place for the emergency phone number the app dials.
//
//  DEMO NOTE: for the hackathon demo this is set to a personal test number so
//  the call flow can be shown live WITHOUT dialing real emergency services.
//  Before any real use, set `dialNumber` back to "911" (and update the
//  on-screen label below).
//

nonisolated enum EmergencyContact {
    /// The number the "Call" buttons dial. "911" for production use.
    static let dialNumber = "4844703384"

    /// How the number is shown on buttons/labels.
    static let displayName = "Call 911"
}
