# ESP32 GPS Bus Tracker Setup Guide

## 🎯 Project Overview
This ESP32 will track bus location and send GPS data to your FastAPI backend server.

## 🔧 Hardware Requirements
- **ESP32 Development Board** (ESP32-WROOM-32 recommended)
- **GPS Module** (NEO-6M or NEO-8M)
- **Jumper Wires**
- **Breadboard** (optional)
- **Power Supply** (USB or external)

## 📡 Network Configuration
**Your API Server URLs:**
- Network URL: `http://192.168.1.68:8000` ← **Use this for ESP32** (CORRECTED)
- Local URL: `http://localhost:8000` ← **Use this for testing**

## 🔌 Hardware Connections
```
ESP32          GPS Module
--------------------------
GPIO 4   ←→   TX (GPS)
GPIO 2   ←→   RX (GPS)  
3.3V     ←→   VCC
GND      ←→   GND
```

## 📚 Required Arduino Libraries
Install these in Arduino IDE (Tools → Manage Libraries):
1. **WiFi** (built-in)
2. **HTTPClient** (built-in)
3. **ArduinoJson** by Benoit Blanchon
4. **TinyGPSPlus** by Mikal Hart

## ⚙️ Setup Steps

### 1. **Prepare Arduino IDE**
```
1. Install ESP32 board package:
   - File → Preferences
   - Additional Board Manager URLs: 
     https://dl.espressif.com/dl/package_esp32_index.json
   - Tools → Board Manager → Search "ESP32" → Install

2. Select Board:
   - Tools → Board → ESP32 Arduino → ESP32 Dev Module
```

### 2. **Configure the Code**
Edit these lines in `esp32_gps_tracker.ino`:
```cpp
const char* ssid = "YOUR_WIFI_SSID";           // Your WiFi name
const char* password = "YOUR_WIFI_PASSWORD";   // Your WiFi password
const char* serverURL = "http://192.168.1.38:8000";  // Your server IP
const char* busID = "bus_001";                 // Unique bus identifier
```

### 3. **Upload and Test**
```
1. Connect ESP32 to computer via USB
2. Select correct port: Tools → Port → COMx
3. Upload code: Ctrl+U
4. Open Serial Monitor: Ctrl+Shift+M (115200 baud)
5. Watch for connection messages
```

## 🧪 Testing Your Setup

### 1. **Test Server Connection**
Run this on your computer to verify the server is running:
```powershell
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET
```

### 2. **Test ESP32 Data Reception**
After ESP32 starts sending data, check if it's received:
```powershell
# Check current bus location
Invoke-RestMethod -Uri "http://localhost:8000/gps/bus-location?bus_id=bus_001" -Method GET

# View location history
Invoke-RestMethod -Uri "http://localhost:8000/gps/location-history?bus_id=bus_001&limit=5" -Method GET
```

### 3. **Expected Serial Monitor Output**
```
Connecting to WiFi.....
Connected! IP: 192.168.1.XXX
✅ Server connection successful!
Response: {"status":"healthy","timestamp":"2025-06-30T..."}
✅ GPS data sent successfully!
Lat: 27.617600
Lng: 85.539200
Speed: 0.00 km/h
```

## 🚨 Troubleshooting

### WiFi Connection Issues
- Check SSID and password
- Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)
- Check distance from router

### GPS Issues
- **No GPS data**: Check wiring, ensure GPS has clear sky view
- **Slow GPS lock**: Wait 30-60 seconds outdoors for first fix
- **Invalid coordinates**: Move to open area, away from buildings

### Server Connection Issues
- Verify server is running: `Invoke-RestMethod -Uri "http://localhost:8000/health"`
- Check firewall settings on your computer
- Ensure ESP32 and computer are on same network
- Try different IP address from network_info.py output

### Power Issues
- Use quality USB cable
- Consider external 5V power supply for stable operation

## 📈 Data Flow
```
ESP32 GPS → WiFi → Your Computer → MongoDB
     ↓
   FastAPI Server (Port 8000)
     ↓
   Database Storage
     ↓
   API Endpoints for Apps
```

## 🎯 Next Development Steps
1. **Add more buses**: Change `busID` for each ESP32
2. **Add OLED display**: Show GPS status and connection info
3. **Add sensors**: Temperature, passenger count, etc.
4. **Power optimization**: Deep sleep between transmissions
5. **Mobile app**: Create frontend to view bus locations

## 📞 Quick Reference Commands
```powershell
# Start server
cd "c:\Users\taman\OneDrive\Desktop\Bus-system\transport_backend"
py start.py

# Test API
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET

# View all GPS data
Invoke-RestMethod -Uri "http://localhost:8000/gps/location-history?bus_id=bus_001&limit=20" -Method GET

# Check network info
py network_info.py
```

Your backend is **100% ready** for ESP32 integration! 🚀
