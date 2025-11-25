import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { save } from "@tauri-apps/plugin-dialog";

interface DeviceInfo {
  name: string;
  vendor_id: string;
  product_id: string;
}

interface GlucoseSample {
  id: number;
  epoch: number;
  timestamp: string;
  "mg/dL": number;
  "mmol/L": number;
}

function App() {
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const [samples, setSamples] = useState<GlucoseSample[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedDevice, setSelectedDevice] = useState<number>(0);
  const [message, setMessage] = useState<string | null>(null);

  const scanDevices = async () => {
    setLoading(true);
    setError(null);
    setMessage(null);
    try {
      const foundDevices = await invoke<DeviceInfo[]>("scan_devices");
      setDevices(foundDevices);
      if (foundDevices.length === 0) {
        setError("Aucun appareil AccuChek trouvé. Assurez-vous que l'appareil est connecté et en mode transfert de données.");
      } else {
        setMessage(`${foundDevices.length} appareil(s) trouvé(s)`);
      }
    } catch (err) {
      setError(`Erreur lors de la recherche: ${err}`);
    } finally {
      setLoading(false);
    }
  };

  const downloadData = async () => {
    setLoading(true);
    setError(null);
    setMessage(null);
    try {
      const data = await invoke<GlucoseSample[]>("download_data", {
        deviceIndex: selectedDevice,
      });
      setSamples(data);
      setMessage(`${data.length} mesure(s) téléchargée(s)`);
    } catch (err) {
      setError(`Erreur lors du téléchargement: ${err}`);
    } finally {
      setLoading(false);
    }
  };

  const exportData = async (format: "json" | "csv") => {
    if (samples.length === 0) {
      setError("Aucune donnée à exporter");
      return;
    }

    try {
      const defaultFilename = `accuchek_data_${new Date().toISOString().split("T")[0]}.${format}`;
      const filePath = await save({
        defaultPath: defaultFilename,
        filters: [
          {
            name: format.toUpperCase(),
            extensions: [format],
          },
        ],
      });

      if (filePath) {
        setMessage(null);
        if (format === "json") {
          const result = await invoke<string>("export_json", {
            samples,
            filename: filePath,
          });
          setMessage(result);
        } else {
          const result = await invoke<string>("export_csv", {
            samples,
            filename: filePath,
          });
          setMessage(result);
        }
      }
    } catch (err) {
      setError(`Erreur lors de l'export: ${err}`);
    }
  };

  return (
    <div className="container">
      <header>
        <h1>AccuChek Data Manager</h1>
        <p>Gérez et exportez vos données de glycémie</p>
      </header>

      <div className="card">
        <h2>1. Rechercher les appareils</h2>
        <button onClick={scanDevices} disabled={loading}>
          {loading ? "Recherche..." : "Rechercher"}
        </button>

        {devices.length > 0 && (
          <div className="device-list">
            <h3>Appareils trouvés:</h3>
            {devices.map((device, index) => (
              <div key={index} className="device-item">
                <input
                  type="radio"
                  name="device"
                  id={`device-${index}`}
                  checked={selectedDevice === index}
                  onChange={() => setSelectedDevice(index)}
                />
                <label htmlFor={`device-${index}`}>
                  <strong>{device.name}</strong>
                  <br />
                  <small>
                    Vendor: {device.vendor_id} | Product: {device.product_id}
                  </small>
                </label>
              </div>
            ))}
          </div>
        )}
      </div>

      {devices.length > 0 && (
        <div className="card">
          <h2>2. Télécharger les données</h2>
          <button onClick={downloadData} disabled={loading}>
            {loading ? "Téléchargement..." : "Télécharger"}
          </button>
        </div>
      )}

      {samples.length > 0 && (
        <>
          <div className="card">
            <h2>3. Prévisualisation des données</h2>
            <div className="samples-table">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Date/Heure</th>
                    <th>mg/dL</th>
                    <th>mmol/L</th>
                  </tr>
                </thead>
                <tbody>
                  {samples.slice(0, 10).map((sample) => (
                    <tr key={sample.id}>
                      <td>{sample.id}</td>
                      <td>{sample.timestamp}</td>
                      <td>{sample["mg/dL"]}</td>
                      <td>{sample["mmol/L"].toFixed(1)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {samples.length > 10 && (
                <p className="table-note">
                  Affichage de 10 sur {samples.length} mesures
                </p>
              )}
            </div>
          </div>

          <div className="card">
            <h2>4. Exporter les données</h2>
            <div className="export-buttons">
              <button onClick={() => exportData("json")} className="export-btn">
                Exporter en JSON
              </button>
              <button onClick={() => exportData("csv")} className="export-btn">
                Exporter en CSV
              </button>
            </div>
          </div>
        </>
      )}

      {error && <div className="error">{error}</div>}
      {message && <div className="success">{message}</div>}
    </div>
  );
}

export default App;
