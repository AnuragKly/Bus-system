# 🚀 GPS Bus Tracking System - Complete Setup Guide

## 📋 **Quick Start Checklist**

When you reload this repository, follow these steps in order:

### **Step 1: Start MongoDB Database**
```bash
cd "c:\VS code\Bus Repository\Bus-system\transport_backend"
docker compose up -d
```

### **Step 2: Start Backend Server**
```bash
# Option A: Using batch file (recommended)
start_nepal_server.bat

# Option B: Using Python directly
py -3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### **Step 3: Verify System is Running**
```bash
# Test backend health
py -3 test_api.py

# Test Nepal timezone storage
py -3 test_nepal_fix.py
```

### **Step 4: Deploy ESP32**
1. Open `esp32_gps_tracker.ino` in Arduino IDE
2. Update WiFi credentials in the code
3. Upload to ESP32
4. Open Serial Monitor to see GPS data transmission

---

## 🔧 **Detailed Setup Process**

### **🐳 Docker MongoDB Setup**

#### **Start MongoDB Container:**
```bash
cd transport_backend
docker compose up -d
```

#### **Verify MongoDB is Running:**
```bash
docker ps
# Should show: transport_mongodb container running on port 27017
```

#### **Check MongoDB Data:**
```bash
docker exec transport_mongodb mongosh transport_system --eval "db.locations.countDocuments()"
```

### **🌐 Backend Server Setup**

#### **Install Dependencies:**
```bash
cd transport_backend
pip install -r requirements.txt
```

#### **Start Server:**
```bash
# Recommended: Use the batch file
start_nepal_server.bat

# Alternative: Direct Python command
py -3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### **Verify Server is Running:**
- Open browser: http://localhost:8000/docs
- Should see FastAPI Swagger documentation

### **📡 ESP32 GPS Tracker Setup**

#### **Hardware Requirements:**
- ESP32 development board
- GPS module (connects to GPIO16/17)
- USB cable for programming
- Power supply (5V/3.3V)

#### **Software Setup:**
1. **Arduino IDE Setup:**
   - Install ESP32 board package
   - Install required libraries:
     - WiFi (built-in)
     - HTTPClient (built-in)
     - ArduinoJson
     - SoftwareSerial (built-in)

2. **Code Configuration:**
   ```cpp
   // Update these in esp32_gps_tracker.ino
   const char* ssid = "YOUR_WIFI_NAME";
   const char* password = "YOUR_WIFI_PASSWORD";
   const char* serverURL = "http://YOUR_SERVER_IP:8000";
   ```

3. **Upload and Monitor:**
   - Connect ESP32 via USB
   - Select correct board and port
   - Upload code
   - Open Serial Monitor (115200 baud)

---

## 📊 **Data Flow Verification**

### **Check Real-time Data:**

#### **1. Server Logs:**
Watch the server terminal for:
```
INFO: 192.168.1.XXX:XXXXX - "POST /gps/data HTTP/1.1" 200 OK
```

#### **2. API Endpoints:**
```bash
# Get latest bus location
curl http://localhost:8000/gps/bus-location?bus_id=bus_001

# Get location history
curl http://localhost:8000/gps/location-history?bus_id=bus_001&limit=10
```

#### **3. MongoDB Data:**
```bash
# Check latest data
docker exec transport_mongodb mongosh transport_system --eval "
  db.locations.findOne({}, {sort: {_id: -1}})
"
```

---

## 🧪 **Testing & Verification**

### **Run Comprehensive Tests:**
```bash
cd transport_backend

# Test backend API
py -3 test_api.py

# Test Nepal timezone implementation
py -3 test_nepal_fix.py

# Check network connectivity
py -3 network_info.py
```

### **Generate Demo Data:**
```bash
# Create sample GPS data for testing
py -3 generate_demo_data.py
```

---

## 🏔️ **Nepal Timezone Implementation**

### **Key Features:**
- ✅ MongoDB stores both UTC (for queries) and Nepal time (for display)
- ✅ API returns Nepal Standard Time (NST, UTC+5:45)
- ✅ ESP32 data automatically converted to Nepal time
- ✅ All timestamps show local Nepal time to users

### **Verification:**
```bash
# Check that timestamps show Nepal time
curl http://localhost:8000/gps/bus-location?bus_id=bus_001
# Should show: "last_updated": "2025-06-30T17:45:23+05:45"
```

---

## 🐛 **Troubleshooting**

### **Common Issues:**

#### **1. Docker not starting:**
```bash
# Check Docker Desktop is running
docker --version
docker ps

# Start Docker Desktop if not running
# Then retry: docker compose up -d
```

#### **2. Server port conflict:**
```bash
# Check what's using port 8000
netstat -ano | findstr :8000

# Kill conflicting process or change port in docker-compose.yml
```

#### **3. ESP32 not sending data:**
- Check Serial Monitor for error messages
- Verify WiFi credentials
- Ensure GPS has satellite lock (may take 1-2 minutes outdoors)
- Check server IP address in ESP32 code

#### **4. No GPS data in MongoDB:**
```bash
# Check if ESP32 is reaching the server
# Look for POST requests in server logs

# Check database connection
py -3 -c "
import pymongo
client = pymongo.MongoClient('mongodb://localhost:27017/')
print(client.list_database_names())
"
```

---

## 🚀 **Project Defense Ready**

### **Demonstration Flow:**
1. **Show System Architecture:** ESP32 → FastAPI → MongoDB
2. **Live GPS Tracking:** Real-time location updates every 5 seconds
3. **Nepal Timezone:** All timestamps in Nepal Standard Time
4. **Data Storage:** MongoDB with dual timezone storage
5. **API Endpoints:** RESTful API with comprehensive documentation
6. **Real-time Updates:** WebSocket support for live tracking

### **Key Metrics:**
- **Data Frequency:** GPS data every 5 seconds
- **Storage Capacity:** MongoDB supports millions of records
- **Response Time:** API responses under 100ms
- **Timezone Accuracy:** Nepal Standard Time (UTC+5:45)
- **Data Integrity:** Both UTC and Nepal timestamps stored

---

## 📱 **System URLs**

- **API Documentation:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/health
- **Live Location:** http://localhost:8000/gps/bus-location?bus_id=bus_001
- **Location History:** http://localhost:8000/gps/location-history?bus_id=bus_001

---

## 🔄 **Restart Sequence**

**When system is completely stopped:**
1. Start Docker Desktop
2. `docker compose up -d` (MongoDB)
3. `start_nepal_server.bat` (Backend)
4. Power on ESP32 (Hardware)
5. `py -3 test_api.py` (Verify)

**System is now ready for GPS tracking with Nepal timezone support!** 🇳🇵
