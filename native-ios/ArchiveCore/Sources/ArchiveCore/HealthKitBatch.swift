import Foundation

/// Canonical layers: dailySummaries, sleepSessions, workouts, heartRate,
/// heartRateVariability, quantitySamples. Heart samples live under watchData.samples;
/// other layers live directly under watchData. An empty layer is never a deletion.
public struct HealthKitBatch: Equatable, Sendable {
    public var records: [String: [JSONValue]]
    public var deletedIDs: [String: [String]]
    public var anchors: [String: String]
    public var syncedAt: Date

    public init(records: [String: [JSONValue]] = [:], deletedIDs: [String: [String]] = [:],
                anchors: [String: String] = [:], syncedAt: Date = Date()) {
        self.records = records
        self.deletedIDs = deletedIDs
        self.anchors = anchors
        self.syncedAt = syncedAt
    }
}
