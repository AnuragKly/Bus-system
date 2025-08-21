
# 🚌 GPS Bus Tracking System

A complete solution for real-time bus tracking using ESP32, GPS, FastAPI backend, MongoDB, and real-time traffic-aware ETA.

---

## 🚀 Quick Start

### 1. **Backend Setup (FastAPI + MongoDB + Real-Time Traffic)**

#### a. **Clone the Repository**
```bash
git clone https://github.com/yourusername/bus-system.git
cd bus-system/transport_backend
```

#### b. **Create & Activate Python Virtual Environment**
```powershell
python -m venv .venv
.\.venv\Scripts\activate
```

#### c. **Install Dependencies**
```powershell
pip install -r requirements.txt
```

#### d. **Start MongoDB (Docker)**
```powershell
docker compose up -d
```

#### e. **Set Up Environment Variables**
- Create a `.env` file in `transport_backend/` with:
  ```env
  OPENROUTESERVICE_API_KEY=your_actual_api_key_here
  ```
- Enable `python.terminal.useEnvFile` in VS Code settings to load `.env` automatically.

#### f. **Run the Backend Server**
```powershell
py -3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### g. **Expose Backend to Internet (ngrok)**
1. [Download ngrok](https://ngrok.com/download)
2. Start ngrok to tunnel your backend:
   ```powershell
   ngrok http 8000
   ```
3. Use the HTTPS forwarding URL from ngrok in your ESP32 or app for remote access.

#### h. **Test the API**
```powershell
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET
```

---

### 2. **ESP32 GPS Tracker Setup (WiFi Provisioning Supported)**

#### a. **Hardware Needed**
- ESP32 Dev Board
- GPS Module (NEO-6M/8M)
- Jumper wires, breadboard (optional)

#### b. **Wiring**
```
ESP32      GPS Module
--------------------------
GPIO 4 <-> TX (GPS)
GPIO 2 <-> RX (GPS)
3.3V   <-> VCC
GND    <-> GND
```

#### c. **Arduino IDE Setup**
- Install ESP32 board support (see [ESP32_SETUP_GUIDE.md](ESP32_SETUP_GUIDE.md))
- Install libraries: WiFi, HTTPClient, ArduinoJson, TinyGPSPlus, (optional: WiFiManager)

#### d. **WiFi Provisioning (No Code Change Needed for New Networks!)**
- **Recommended:** Use [WiFiManager](https://github.com/tzapu/WiFiManager) in your ESP32 code.
  - On first boot or if WiFi fails, ESP32 creates its own AP (e.g., `ESP32-Setup`).
  - User connects to this AP, enters WiFi SSID/password via captive portal or app.
  - ESP32 saves credentials and connects automatically next time.
- **Alternative:** Implement a custom HTTP endpoint on ESP32 to receive WiFi credentials from your app.

#### e. **Configure & Upload Code**
- Edit `esp32_gps_tracker.ino` for your server URL and bus ID:
  ```cpp
  const char* serverURL = "http://YOUR_PC_IP:8000"; // Or use ngrok HTTPS URL
  const char* busID = "bus_001";
  ```
- Upload to ESP32 via Arduino IDE

#### f. **Monitor Output**
- Open Serial Monitor (115200 baud) to check connection and GPS data sending

---

## 🌐 **How It Works**

1. **ESP32** reads GPS data and sends it via WiFi to your FastAPI backend (WiFi credentials can be set by user at runtime).
2. **Backend** receives and stores data in **MongoDB**.
3. **API Endpoints** allow you to view bus locations, history, and ETA (with real-time traffic impact).

---

## 🛣️ **Real-Time Traffic-Aware ETA**
- The backend uses OpenRouteService to fetch live traffic data and adjusts ETA accordingly.
- Set your API key in `.env` as described above.
- The `/gps/estimate-arrival` endpoint returns ETA considering current traffic conditions.

---

## 🛠️ **Troubleshooting**

- **ESP32 can't connect:** Check WiFi credentials, ensure ESP32 and PC are on the same network, or use WiFi provisioning.
- **No GPS data:** Ensure GPS module wiring and clear sky view.
- **Server not receiving data:** Check firewall, server IP, and port.
- **Remote access:** Use [ngrok](https://ngrok.com/) or deploy backend to a cloud server for remote access.

---

## 📈 **Data Flow**

```
ESP32 GPS → WiFi → FastAPI Server (ngrok optional) → MongoDB → Frontend
```

---

## 📄 **More Info**

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md): Detailed backend/server setup
- [ESP32_SETUP_GUIDE.md](ESP32_SETUP_GUIDE.md): Detailed ESP32 setup

---

## 📞 **Common Commands**

```powershell
# Start backend server
cd transport_backend
py -3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Start ngrok tunnel
ngrok http 8000

# Test API health
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET

# Check GPS data
Invoke-RestMethod -Uri "http://localhost:8000/gps/location-history?bus_id=bus_001&limit=5" -Method GET
```

---

**Happy Tracking!**
