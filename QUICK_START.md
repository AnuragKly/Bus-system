# 🚀 QUICK START REFERENCE CARD

## **When You Reload This Repository**

### **1. Start Database (MongoDB)**
```bash
cd "c:\VS code\Bus Repository\Bus-system\transport_backend"
docker compose up -d
```

### **2. Start Backend Server**
```bash
start_nepal_server.bat
```

### **3. Verify System**
```bash
py -3 test_api.py
```

### **4. Deploy ESP32**
- Open `esp32_gps_tracker.ino` in Arduino IDE
- Update WiFi credentials
- Upload to ESP32
- Monitor Serial output

---

## **System URLs**
- **API Docs**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health
- **Live Location**: http://localhost:8000/gps/bus-location?bus_id=bus_001

---

## **Key Files**
- **Backend**: `transport_backend/app/main.py`
- **ESP32 Code**: `esp32_gps_tracker.ino`
- **Nepal Time**: `transport_backend/app/utils/nepal_time.py`
- **Database**: MongoDB in Docker container
- **Tests**: `transport_backend/test_nepal_fix.py`

---

## **Troubleshooting**
1. **Docker not working**: Start Docker Desktop
2. **Port 8000 busy**: `netstat -ano | findstr :8000`
3. **ESP32 no data**: Check Serial Monitor for errors
4. **No GPS fix**: Move ESP32 outdoors, wait 2 minutes

---

## **Project Features**
✅ **Nepal Standard Time** (UTC+5:45) throughout system  
✅ **Real-time GPS** tracking every 5 seconds  
✅ **MongoDB storage** with dual timezone format  
✅ **FastAPI backend** with full documentation  
✅ **ESP32 integration** with WiFi and GPS  
✅ **Docker deployment** for easy setup  

**Status: READY FOR PROJECT DEFENSE** 🇳🇵
