import Foundation

extension ArchiveDocument {
    public mutating func applyHealthKit(_ batch: HealthKitBatch) {
        var watch = data["watchData"]?.objectValue ?? [:]
        var sleepChanged = false
        var quantitiesChanged = false
        for layer in Set(batch.records.keys).union(batch.deletedIDs.keys).sorted() {
            let incoming = batch.records[layer] ?? []
            let deleted = Set((batch.deletedIDs[layer] ?? []).map { $0.lowercased() })
            // Empty/denied queries must not rewrite even the shape of legacy data.
            guard !incoming.isEmpty || !deleted.isEmpty else { continue }
            let isSample = layer == "heartRate" || layer == "heartRateVariability"
            var parent = isSample ? (watch["samples"]?.objectValue ?? [:]) : watch
            let old = parent[layer]?.arrayValue ?? []
            var next = old.filter { record in
                !(record["provider"].stringValue == "healthKit" && deleted.contains(record["id"].stringValue.lowercased()))
            }
            var positions: [String: Int] = [:]
            for (index, record) in next.enumerated() where record["provider"].stringValue == "healthKit" {
                let key = record["id"].stringValue.lowercased()
                if positions[key] == nil { positions[key] = index }
            }
            for record in incoming {
                guard case .object(let fields) = record,
                      record["provider"].stringValue == "healthKit", !record["id"].stringValue.isEmpty,
                      !deleted.contains(record["id"].stringValue.lowercased()) else { continue }
                let key = record["id"].stringValue.lowercased()
                if let index = positions[key] {
                    // Preserve extension fields when a producer corrects known fields.
                    next[index] = .object(next[index].objectValue.merging(fields) { _, new in new })
                } else {
                    positions[key] = next.count
                    next.append(record)
                }
            }
            guard next != old else { continue }
            parent[layer] = .array(next)
            if isSample { watch["samples"] = .object(parent) } else { watch = parent }
            sleepChanged = sleepChanged || layer == "sleepSessions"
            quantitiesChanged = quantitiesChanged || layer == "quantitySamples"
        }
        // Explicitly authorized high-frequency retention is separate from query
        // reconciliation. Never apply it to quantities (their old daily totals
        // still depend on raw UUIDs), sleep, workouts or other providers.
        if var samples = watch["samples"]?.objectValue {
            for layer in ["heartRate", "heartRateVariability"] {
                if let records = samples[layer]?.arrayValue {
                    samples[layer] = .array(Self.retainedHeartSamples(records, syncedAt: batch.syncedAt))
                }
            }
            watch["samples"] = .object(samples)
        }
        if !watch.isEmpty || data["watchData"] != nil { data["watchData"] = .object(watch) }
        if sleepChanged { reconcileSleep() }
        if quantitiesChanged { reconcileQuantitySummaries() }
        // Candidate anchors travel with the value transaction. The UI must persist
        // the whole candidate atomically before considering these anchors committed.
        if !batch.anchors.isEmpty {
            var native = data["nativeIOS"]?.objectValue ?? [:]
            var anchors = native["healthKitAnchors"]?.objectValue ?? [:]
            for (key, value) in batch.anchors { anchors[key] = .string(value) }
            native["healthKitAnchors"] = .object(anchors)
            native["healthKitSyncedAt"] = .string(ISO8601DateFormatter().string(from: batch.syncedAt))
            data["nativeIOS"] = .object(native)
        }
    }

    private static func retainedHeartSamples(_ records: [JSONValue], syncedAt: Date) -> [JSONValue] {
        let cutoff = syncedAt.addingTimeInterval(-30 * 24 * 60 * 60)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        func parsedDate(_ value: JSONValue) -> Date? {
            guard case .string(let string) = value else { return nil }
            return fractional.date(from: string) ?? plain.date(from: string)
        }
        let eligible = records.enumerated().compactMap { index, record -> (index: Int, date: Date, id: String)? in
            guard record["provider"].stringValue == "healthKit" else { return nil }
            let date = parsedDate(record["timestamp"]) ?? parsedDate(record["startedAt"])
                ?? parsedDate(record["startDate"]) ?? parsedDate(record["endedAt"])
            if let date, date < cutoff { return nil }
            // Undated extension/old-format rows cannot be age-classified. Keep
            // them subject to the same hard count bound (after dated samples).
            return (index, date ?? .distantPast, record["id"].stringValue.lowercased())
        }.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            if $0.id != $1.id { return $0.id < $1.id }
            return $0.index < $1.index
        }
        let keep = Set(eligible.prefix(2500).map(\.index))
        return records.enumerated().compactMap { index, record in
            record["provider"].stringValue != "healthKit" || keep.contains(index) ? record : nil
        }
    }

    private mutating func reconcileQuantitySummaries() {
        var watch = data["watchData"]?.objectValue ?? [:]
        let samples = watch["quantitySamples"]?.arrayValue ?? []
        let metricFields = ["steps": "steps", "distance": "distanceMeters", "activeCalories": "activeCalories",
                            "basalCalories": "basalCalories", "floors": "floors"]
        // date -> metric -> source -> samples. Only one source wins per metric;
        // never sum Garmin, Apple Watch and phone totals for the same observation.
        var groups: [String: [String: [String: [JSONValue]]]] = [:]
        for sample in samples {
            let metric = sample["metric"].stringValue
            let date = sample["date"].stringValue
            guard sample["provider"].stringValue == "healthKit", metricFields[metric] != nil,
                  Self.validDateKey(date), let value = sample["value"].finiteNumber, value >= 0 else { continue }
            groups[date, default: [:]][metric, default: [:]][Self.sourceKey(sample), default: []].append(sample)
        }
        let previous = watch["dailySummaries"]?.arrayValue ?? []
        let derived = previous.filter { $0["nativeIOS"]["derivedQuantitySummary"].boolValue }
        var summaries = previous.filter { !$0["nativeIOS"]["derivedQuantitySummary"].boolValue }
        let dates = Set(groups.keys).union(derived.map { $0["date"].stringValue })
        let generatedKeys: Set<String> = ["id", "date", "provider", "source", "sourceId", "metricSources",
            "steps", "distanceMeters", "activeCalories", "basalCalories", "totalCalories", "floors", "fieldAvailability", "nativeIOS"]
        for date in dates.sorted() {
            var summary = derived.first { $0["date"].stringValue == date }?.objectValue ?? [:]
            for key in ["steps", "distanceMeters", "activeCalories", "basalCalories", "totalCalories", "floors"] {
                summary.removeValue(forKey: key)
            }
            var sources = summary["metricSources"]?.objectValue ?? [:]
            var availability = summary["fieldAvailability"]?.objectValue ?? [:]
            for metric in metricFields.keys { sources.removeValue(forKey: metric) }
            for key in ["steps", "distance", "activeCalories", "basalCalories", "totalCalories", "floors"] { availability.removeValue(forKey: key) }
            var observed = false
            for metric in (groups[date] ?? [:]).keys.sorted() {
                guard let bySource = groups[date]?[metric],
                      let winner = Self.preferredSource(Array(bySource.values)), let first = winner.first,
                      let field = metricFields[metric] else { continue }
                // UUIDs are already deduplicated; distinct samples from this one
                // producer are additive. Overlapping *other* producers are ignored.
                let total = winner.reduce(0) { $0 + ($1["value"].finiteNumber ?? 0) }
                guard total.isFinite else { continue }
                summary[field] = .number(total)
                availability[metric] = .bool(true)
                sources[metric] = .object(["source": first["source"], "sourceId": first["sourceId"], "provider": first["provider"]])
                observed = true
            }
            if let active = summary["activeCalories"]?.finiteNumber, let basal = summary["basalCalories"]?.finiteNumber,
               (active + basal).isFinite {
                summary["totalCalories"] = .number(active + basal)
                availability["totalCalories"] = .bool(true)
            }
            // A deleted derived row can disappear only if it has no extension data.
            // Preserve unknown fields even on a now-empty derived summary.
            let hasExtensions = !Set(summary.keys).subtracting(generatedKeys).isEmpty
                || !sources.isEmpty || !availability.isEmpty
                || !(summary["nativeIOS"]?.objectValue ?? [:]).filter({ $0.key != "derivedQuantitySummary" }).isEmpty
            guard observed || hasExtensions else { continue }
            summary["id"] = .string("native-ios-quantity-\(date)")
            summary["date"] = .string(date)
            summary["provider"] = .string("healthKit")
            summary["source"] = .string("HealthKit")
            summary["sourceId"] = .string("native-ios-quantity-summary")
            summary["metricSources"] = .object(sources)
            summary["fieldAvailability"] = .object(availability)
            var native = summary["nativeIOS"]?.objectValue ?? [:]
            native["derivedQuantitySummary"] = .bool(true)
            summary["nativeIOS"] = .object(native)
            summaries.append(.object(summary))
        }
        watch["dailySummaries"] = .array(summaries)
        data["watchData"] = .object(watch)
    }

    static let sleepMetadataKeys = ["sleep", "sleepSource", "sleepProvider", "sleepOrigin", "sleepSessionIds", "sleepSyncedAt"]

    mutating func reconcileSleep() {
        let sleep = Self.sleepByDate(data["watchData"]?["sleepSessions"].arrayValue ?? [])
        var entries = rawEntries
        let dates = Set(sleep.keys).union(entries.filter { $0["nativeIOS"]["sleepManaged"].boolValue }.map { $0["date"].stringValue })
        for date in dates.sorted() {
            let index = entries.firstIndex { $0["date"].stringValue == date }
            var raw = index.map { entries[$0] } ?? .object(["date": .string(date)])
            var fields = Self.recordedFields(index.map { entries[$0] })
            var native = raw["nativeIOS"].objectValue
            if let selected = sleep[date] {
                if !raw["nativeIOS"]["sleepManaged"].boolValue {
                    var fallback = native["sleepFallback"]?.objectValue ?? [:]
                    for key in Self.sleepMetadataKeys { fallback.removeValue(forKey: key) }
                    fallback["recorded"] = .bool(false)
                    // Legacy synced values are projections, not manual fallbacks.
                    // Legacy watch records themselves stay in watchData unchanged.
                    if raw["sleepSource"].stringValue != "sync" && raw["sleepSource"].stringValue != "healthKit" {
                        fallback["recorded"] = .bool(fields["sleep"]?.boolValue ?? false)
                        for key in Self.sleepMetadataKeys {
                            if let value = raw.objectValue[key] { fallback[key] = value }
                        }
                    }
                    native["sleepFallback"] = .object(fallback)
                }
                native["sleepManaged"] = .bool(true)
                raw["sleep"] = .number(selected.hours)
                raw["sleepSource"] = .string("sync")
                raw["sleepProvider"] = .string(selected.provider)
                raw["sleepOrigin"] = .string(selected.source)
                raw["sleepSessionIds"] = .array(selected.ids.sorted().map { .string($0) })
                fields["sleep"] = .bool(true)
            } else {
                let fallback = native["sleepFallback"]?.objectValue ?? [:]
                var object = raw.objectValue
                for key in Self.sleepMetadataKeys {
                    object.removeValue(forKey: key)
                    if let value = fallback[key] { object[key] = value }
                }
                raw = .object(object)
                fields["sleep"] = .bool(fallback["recorded"]?.boolValue ?? false)
                native.removeValue(forKey: "sleepManaged")
                var extensions = fallback
                for key in Self.sleepMetadataKeys + ["recorded"] { extensions.removeValue(forKey: key) }
                if extensions.isEmpty { native.removeValue(forKey: "sleepFallback") }
                else { native["sleepFallback"] = .object(extensions) }
            }
            var object = raw.objectValue
            object["recordedFields"] = .object(fields)
            if native.isEmpty { object.removeValue(forKey: "nativeIOS") } else { object["nativeIOS"] = .object(native) }
            let knownEmptyKeys: Set<String> = ["date", "habits", "water", "sleep", "recordedFields"]
            let noMetrics = !["habits", "water", "sleep"].contains { fields[$0]?.boolValue == true }
            let disposable = noMetrics && Set(object.keys).isSubset(of: knownEmptyKeys) && object["habits"]?.objectValue.isEmpty != false
            if let index {
                if disposable { entries.remove(at: index) } else { entries[index] = .object(object) }
            } else if !disposable { entries.append(.object(object)) }
        }
        // Do not add entries to an empty imported shape without actual sleep.
        if !dates.isEmpty { rawEntries = entries.sorted { $0["date"].stringValue < $1["date"].stringValue } }
    }

    struct SleepSelection {
        var hours: Double
        var provider: String
        var source: String
        var ids: Set<String>
    }

    private struct SleepInterval {
        var start: Date
        var end: Date
        var asleep: Bool
        var raw: JSONValue
    }

    private struct SleepCandidate {
        var intervals: [DateInterval] = []
        var durationOnlyHours: Double = 0
        var ids: Set<String> = []
        var representative: JSONValue
    }

    static func sleepByDate(_ records: [JSONValue]) -> [String: SleepSelection] {
        var episodes: [String: [SleepInterval]] = [:]
        var candidates: [String: [String: SleepCandidate]] = [:]
        var seenIDs = Set<String>()
        for raw in records {
            guard case .object = raw else { continue }
            let id = raw["id"].stringValue
            if !id.isEmpty && !seenIDs.insert(raw["provider"].stringValue + "|" + id.lowercased()).inserted { continue }
            let source = sourceKey(raw)
            if let start = timestamp(raw["startedAt"]) ?? timestamp(raw["startTime"]) ?? timestamp(raw["startDate"]),
               let end = timestamp(raw["endedAt"]) ?? timestamp(raw["endTime"]) ?? timestamp(raw["endDate"]), end > start {
                // HealthKit stages do not share a session UUID. Explicit sessionId
                // wins; otherwise source-contiguous stages form a wake episode.
                let group = source + "|" + raw["sessionId"].stringValue
                episodes[group, default: []].append(SleepInterval(start: start, end: end, asleep: isAsleep(raw), raw: raw))
            } else if validDateKey(raw["date"].stringValue), isAsleep(raw),
                      let minutes = raw["durationMinutes"].finiteNumber, minutes > 0, minutes <= 1440 {
                let date = raw["date"].stringValue
                var candidate = candidates[date]?[source] ?? SleepCandidate(representative: raw)
                candidate.durationOnlyHours += minutes / 60
                if !id.isEmpty { candidate.ids.insert(id) }
                candidates[date, default: [:]][source] = candidate
            }
        }
        for intervals in episodes.values {
            let sorted = intervals.sorted { $0.start < $1.start }
            var episode: [SleepInterval] = []
            var latestEnd: Date?
            func flush() {
                guard let wake = episode.max(by: { $0.end < $1.end }), episode.contains(where: \.asleep) else { return }
                var calendar = Calendar(identifier: .gregorian)
                let zone = wake.raw["timezone"].stringValue.isEmpty ? wake.raw["timeZone"].stringValue : wake.raw["timezone"].stringValue
                calendar.timeZone = TimeZone(identifier: zone) ?? .current
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: wake.end)) else { return }
                let date = dateKey(previousDay, calendar: calendar)
                let source = sourceKey(wake.raw)
                var candidate = candidates[date]?[source] ?? SleepCandidate(representative: wake.raw)
                candidate.intervals += episode.filter(\.asleep).map { DateInterval(start: $0.start, end: $0.end) }
                candidate.ids.formUnion(episode.map { $0.raw["id"].stringValue }.filter { !$0.isEmpty })
                candidates[date, default: [:]][source] = candidate
            }
            for interval in sorted {
                if let end = latestEnd, interval.start.timeIntervalSince(end) > 90 * 60 {
                    flush()
                    episode = []
                    latestEnd = nil
                }
                episode.append(interval)
                latestEnd = max(latestEnd ?? interval.end, interval.end)
            }
            flush()
        }
        var result: [String: SleepSelection] = [:]
        for (date, bySource) in candidates {
            let sorted = bySource.values.sorted { sourceRank($0.representative) < sourceRank($1.representative) }
            guard let selected = sorted.first else { continue }
            // Prefer real intervals over same-producer legacy duration summaries.
            let hours = selected.intervals.isEmpty ? selected.durationOnlyHours : unionSeconds(selected.intervals) / 3600
            guard hours > 0, hours.isFinite else { continue }
            result[date] = SleepSelection(hours: hours, provider: selected.representative["provider"].stringValue,
                source: selected.representative["source"].stringValue, ids: selected.ids)
        }
        return result
    }

    private static func isAsleep(_ raw: JSONValue) -> Bool {
        if case .bool(let asleep) = raw["isAsleep"] { return asleep }
        let stage = [raw["stage"], raw["sleepStage"], raw["sleepStageValue"], raw["category"], raw["value"]].first { $0 != .null }
        if case .number(let category)? = stage { return [1.0, 3, 4, 5].contains(category) }
        let name = stage?.stringValue.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "") ?? ""
        // A legacy session with no stage describes sleep. A future/unknown stage
        // does not; do not silently turn unsupported HealthKit categories asleep.
        return stage == nil || name.hasPrefix("asleep") || ["sleep", "core", "deep", "rem", "light", "1", "3", "4", "5"].contains(name)
    }

    private static func timestamp(_ raw: JSONValue) -> Date? {
        guard case .string(let string) = raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func unionSeconds(_ intervals: [DateInterval]) -> Double {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: Double = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end { current = DateInterval(start: current.start, end: max(current.end, interval.end)) }
            else { total += current.duration; current = interval }
        }
        return total + current.duration
    }

    private static func sourceKey(_ record: JSONValue) -> String {
        [record["provider"].stringValue, record["sourceId"].stringValue, record["source"].stringValue].joined(separator: "|")
    }

    private static func sourceRank(_ record: JSONValue) -> String {
        let description = [record["source"].stringValue, record["sourceId"].stringValue,
            record["device"]["name"].stringValue, record["device"]["manufacturer"].stringValue,
            record["device"]["model"].stringValue, record["sourceRevision"]["productType"].stringValue].joined(separator: " ").lowercased()
        let rank = description.contains("garmin") ? "0" : (description.contains("apple") && description.contains("watch")) ? "1" : "2"
        let provider = record["provider"].stringValue == "healthKit" ? "0" : "1"
        return rank + provider + sourceKey(record)
    }

    private static func preferredSource(_ groups: [[JSONValue]]) -> [JSONValue]? {
        groups.filter { !$0.isEmpty }.sorted { sourceRank($0[0]) < sourceRank($1[0]) }.first
    }
}
