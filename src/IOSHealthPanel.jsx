import { useEffect, useState } from "react";
import { registerPlugin } from "@capacitor/core";

const ArchiveNative = registerPlugin("ArchiveNative");

export default function IOSHealthPanel({ SettingsSection, SettingsRow }) {
  const [capabilities, setCapabilities] = useState(null);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(true);

  useEffect(() => {
    let active = true;
    ArchiveNative.getCapabilities()
      .then((result) => {
        if (!active) return;
        setCapabilities(result);
      })
      .catch(() => {
        if (!active) return;
        setStatus("The native iPhone health bridge could not be reached.");
      })
      .finally(() => {
        if (active) setBusy(false);
      });
    return () => {
      active = false;
    };
  }, []);

  const reviewHealthAccess = async () => {
    setBusy(true);
    setStatus("");
    try {
      const result = await ArchiveNative.presentHealthAccessPrimer();
      if (result?.status === "reviewed") {
        setStatus("Health access was reviewed. Archive will keep each Apple Health choice under your control.");
      } else if (result?.status === "unavailable") {
        setStatus("Apple Health is not available on this device.");
      }
    } catch (error) {
      setStatus(String(error?.message ?? "Archive could not open the native HealthKit access sheet."));
    } finally {
      setBusy(false);
    }
  };

  const healthKitAvailable = capabilities?.healthKitAvailable === true;

  return (
    <div className="settings-stack ios-health-panel">
      <div className={`health-connection-summary ${healthKitAvailable ? "available" : "waiting"}`}>
        <span className="health-connection-orb" aria-hidden="true"><i /></span>
        <div>
          <small>Apple Health</small>
          <strong>{busy && !capabilities ? "Checking this iPhone..." : healthKitAvailable ? "Native access available" : "Not available"}</strong>
          <span>Presented with SwiftUI and handled by HealthKit.</span>
        </div>
        <span className="health-sync-method">iPhone</span>
      </div>

      <SettingsSection title="HealthKit foundation" meta={healthKitAvailable ? "Ready" : "Check"}>
        <SettingsRow
          label="Native boundary"
          value="SwiftUI"
          detail="Archive stays in React while iOS-specific permission and health framework work stays native."
        />
        <SettingsRow
          label="Data access"
          value="Read only"
          detail="The access sheet can review sleep, activity, workout, heart-rate, HRV, distance, energy, and floors permissions."
        />
        <SettingsRow
          label="Import status"
          value="Foundation"
          detail="This iteration prepares native authorization. HealthKit record reconciliation will be connected to Archive in a dedicated follow-up."
        />
        <div className="settings-option-list">
          <button
            type="button"
            className="settings-option"
            onClick={reviewHealthAccess}
            disabled={busy || !healthKitAvailable}
          >
            <span>
              <strong>{busy ? "Preparing..." : "Review Apple Health access"}</strong>
              <small>Open Archive's native explanation before iOS presents its system permission choices.</small>
            </span>
            <b>Review</b>
          </button>
        </div>
      </SettingsSection>

      {status && <div className="ai-disclosure ios-health-status" role="status">{status}</div>}
      <div className="ai-disclosure">
        Archive does not upload HealthKit data. Permission review is optional, and iOS keeps individual read choices in the Health app's privacy controls.
      </div>
    </div>
  );
}
