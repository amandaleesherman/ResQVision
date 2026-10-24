//
//  GeminiHTTP.swift
//  EmergencyFirst
//
//  Shared HTTP helper for Gemini calls. The endpoint intermittently stalls
//  (connection accepted, then 0 bytes, never responds) regardless of request
//  content. For a time-critical emergency app we retry with a short per-attempt
//  timeout so one hung request doesn't block the result.
//

import Foundation

nonisolated enum GeminiHTTP {
    /// Sends `request`, retrying on timeout/transient failure up to `attempts`
    /// times. Returns the response body on the first 2xx. Throws if every
    /// attempt fails.
    static func send(_ request: URLRequest, attempts: Int) async throws -> Data {
        var lastError: Error = GuidanceError.analysisFailed

        for attempt in 1...max(1, attempts) {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    lastError = GuidanceError.analysisFailed
                    continue
                }
                if (200..<300).contains(http.statusCode) {
                    return data
                }
                // 4xx (bad request / blocked) won't improve on retry — stop.
                if (400..<500).contains(http.statusCode) {
                    throw GuidanceError.analysisFailed
                }
                // 5xx: transient; fall through to retry.
                lastError = GuidanceError.analysisFailed
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Timeouts and connection drops land here — retry.
                lastError = error
            }

            // Tiny backoff before the next try (skip after the last).
            if attempt < attempts {
                try? await Task.sleep(for: .milliseconds(300))
            }
        }

        throw lastError
    }
}
