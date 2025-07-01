/*
ESP32 GPS Tracker for Bus System - COMPLETE WORKING VERSION
Integrates proven GPS code with WiFi and server communication

Hardware Connections:
- GPS Module: TX->GPIO16, RX->GPIO17 (UART2)
- Power: 3.3V or 5V (depending on GPS module)
- GND: GND

Required Libraries:
- WiFi (built-in)
- HTTPClient (built-in)
- ArduinoJson
- TinyGPS++
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <TinyGPS++.h>

// WiFi credentials - UPDATE THESE
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// API server configuration - UPDATE THIS IP
const char* serverURL = "http://192.168.1.38:8000";  // Your server IP from network_info.py
const char* busID = "bus_001";  // Unique bus identifier

// GPS configuration - Using your working pin setup
#define RXD2 16    // GPS TX → ESP32 GPIO16
#define TXD2 17    // GPS RX → ESP32 GPIO17
#define GPS_BAUD 9600

TinyGPSPlus gps;

// Timing variables
unsigned long lastGPSCheck = 0;
unsigned long lastDataSend = 0;
const unsigned long gpsCheckInterval = 1000;    // Check GPS every 1 second
const unsigned long sendInterval = 5000;        // Send to server every 5 seconds

// Status tracking
bool wifiConnected = false;
bool serverTested = false;
int successfulSends = 0;
int failedSends = 0;

void setup() {
  Serial.begin(115200);
  Serial.println(F("🚌 ESP32 GPS Bus Tracker - Starting..."));
  Serial.println(F("========================================="));
  
  // Initialize GPS - Using your working configuration
  Serial2.begin(GPS_BAUD, SERIAL_8N1, RXD2, TXD2);
  Serial.println(F("📡 GPS initialized on UART2 (RX:16, TX:17) @9600"));
  
  // Connect to WiFi
  connectToWiFi();
  
  // Test server connection
  if (wifiConnected) {
    testServerConnection();
  }
  
  Serial.println(F("🚀 Setup complete! Starting GPS tracking..."));
  Serial.println(F("========================================="));
}

void loop() {
  // Feed TinyGPS++ with every byte we receive (your working GPS code)
  while (Serial2.available()) {
    gps.encode(Serial2.read());
  }
  
  // Check GPS status every second
  if (millis() - lastGPSCheck >= gpsCheckInterval) {
    lastGPSCheck = millis();
    displayGPSStatus();
  }
  
  // Send data to server every 5 seconds if GPS has valid fix
  if (gps.location.isValid() && wifiConnected && 
      (millis() - lastDataSend >= sendInterval)) {
    sendGPSDataToServer();
    lastDataSend = millis();
  }
  
  // Check WiFi connection periodically
  if (millis() % 30000 == 0) {  // Every 30 seconds
    checkWiFiConnection();
  }
}

void connectToWiFi() {
  Serial.print(F("📶 Connecting to WiFi: "));
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.println();
    Serial.println(F("✅ WiFi connected successfully!"));
    Serial.print(F("📱 ESP32 IP address: "));
    Serial.println(WiFi.localIP());
    Serial.print(F("📶 Signal strength: "));
    Serial.print(WiFi.RSSI());
    Serial.println(F(" dBm"));
  } else {
    wifiConnected = false;
    Serial.println();
    Serial.println(F("❌ WiFi connection failed!"));
    Serial.println(F("   Check SSID and password"));
  }
}

void checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println(F("⚠️  WiFi disconnected! Reconnecting..."));
    wifiConnected = false;
    connectToWiFi();
  }
}

void testServerConnection() {
  Serial.println(F("🔗 Testing server connection..."));
  
  HTTPClient http;
  http.begin(String(serverURL) + "/health");
  http.setTimeout(5000);  // 5 second timeout
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println(F("✅ Server connection successful!"));
    Serial.print(F("📡 Server response: "));
    Serial.println(response);
    serverTested = true;
  } else {
    Serial.println(F("❌ Server connection failed!"));
    Serial.print(F("🔍 Error code: "));
    Serial.println(httpResponseCode);
    Serial.println(F("   Check server IP and network connection"));
    Serial.print(F("   Trying to reach: "));
    Serial.println(String(serverURL) + "/health");
    serverTested = false;
  }
  
  http.end();
}

void displayGPSStatus() {
  if (gps.location.isValid()) {
    // Display GPS data (your working format)
    Serial.println(F("📍 GPS Data:"));
    Serial.print(F("   LAT : ")); Serial.println(gps.location.lat(), 6);
    Serial.print(F("   LON : ")); Serial.println(gps.location.lng(), 6);
    Serial.print(F("   SPD : ")); Serial.print(gps.speed.kmph()); Serial.println(F(" km/h"));
    Serial.print(F("   ALT : ")); Serial.print(gps.altitude.meters()); Serial.println(F(" m"));
    Serial.print(F("   HDOP: ")); Serial.println(gps.hdop.hdop());
    Serial.print(F("   SAT : ")); Serial.println(gps.satellites.value());
    Serial.print(F("   NST : "));  // Nepal Standard Time
    
    // Convert UTC to Nepal Standard Time (+5:45)
    int year = gps.date.year();
    int month = gps.date.month();
    int day = gps.date.day();
    int hour = gps.time.hour();
    int minute = gps.time.minute();
    int second = gps.time.second();
    
    // Add Nepal timezone offset
    minute += 45;
    if (minute >= 60) {
      minute -= 60;
      hour += 1;
    }
    hour += 5;
    if (hour >= 24) {
      hour -= 24;
      day += 1;
      // Simple day overflow handling
      if (day > 31) {
        day = 1;
        month += 1;
        if (month > 12) {
          month = 1;
          year += 1;
        }
      }
    }
    
    Serial.printf("%04d/%02d/%02d %02d:%02d:%02d (Nepal Time)\n",
                  year, month, day, hour, minute, second);
  } else {
    Serial.println(F("🔍 No GPS fix yet..."));
    
    // Show GPS module status
    if (gps.charsProcessed() < 10) {
      Serial.println(F("   ⚠️  No data from GPS module - check wiring"));
    } else {
      Serial.print(F("   📡 GPS chars processed: "));
      Serial.println(gps.charsProcessed());
      Serial.println(F("   🕒 Waiting for satellite lock..."));
    }
  }
}

void sendGPSDataToServer() {
  if (!wifiConnected) {
    Serial.println(F("❌ Cannot send - WiFi not connected"));
    return;
  }
  
  Serial.println(F("📤 Sending GPS data to server..."));
  
  HTTPClient http;
  http.begin(String(serverURL) + "/gps/data");
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);  // 10 second timeout
  
  // Create JSON payload using ArduinoJson
  DynamicJsonDocument doc(1024);
  doc["bus_id"] = busID;
  doc["latitude"] = gps.location.lat();
  doc["longitude"] = gps.location.lng();
  doc["speed"] = gps.speed.kmph();
  
  // Add timestamp if available (Convert UTC to Nepal Standard Time: UTC + 5:45)
  if (gps.date.isValid() && gps.time.isValid()) {
    // Get UTC time from GPS
    int year = gps.date.year();
    int month = gps.date.month();
    int day = gps.date.day();
    int hour = gps.time.hour();
    int minute = gps.time.minute();
    int second = gps.time.second();
    
    // Add Nepal Standard Time offset: +5 hours 45 minutes
    minute += 45;
    if (minute >= 60) {
      minute -= 60;
      hour += 1;
    }
    hour += 5;
    if (hour >= 24) {
      hour -= 24;
      day += 1;
      // Simple day overflow handling (good enough for GPS tracking)
      if (day > 31) {
        day = 1;
        month += 1;
        if (month > 12) {
          month = 1;
          year += 1;
        }
      }
    }
    
    char timestamp[32];
    sprintf(timestamp, "%04d-%02d-%02dT%02d:%02d:%02d+05:45",
            year, month, day, hour, minute, second);
    doc["timestamp"] = timestamp;
  }
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  // Send POST request
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    successfulSends++;
    Serial.println(F("✅ GPS data sent successfully!"));
    Serial.print(F("📊 Server response: "));
    Serial.println(response);
    Serial.print(F("📈 Successful sends: "));
    Serial.print(successfulSends);
    Serial.print(F(" | Failed: "));
    Serial.println(failedSends);
  } else {
    failedSends++;
    Serial.println(F("❌ Failed to send GPS data"));
    Serial.print(F("🔍 Error code: "));
    Serial.println(httpResponseCode);
    Serial.print(F("📉 Successful sends: "));
    Serial.print(successfulSends);
    Serial.print(F(" | Failed: "));
    Serial.println(failedSends);
    
    // Try to reconnect if too many failures
    if (failedSends > 3) {
      Serial.println(F("🔄 Too many failures - testing server connection..."));
      testServerConnection();
      failedSends = 0;  // Reset counter
    }
  }
  
  http.end();
  Serial.println();  // Add spacing
}

/*
=======================================================================
SETUP INSTRUCTIONS:
=======================================================================

1. HARDWARE CONNECTIONS:
   GPS Module    ESP32
   -----------   -----
   VCC       →   3.3V or 5V
   GND       →   GND  
   TX        →   GPIO16 (RX2)
   RX        →   GPIO17 (TX2)

2. ARDUINO IDE SETUP:
   - Install ESP32 board package
   - Install ArduinoJson library
   - Install TinyGPS++ library
   - Select "ESP32 Dev Module" as board

3. CONFIGURATION:
   - Update WiFi credentials (ssid, password)
   - Update server IP (get from network_info.py)
   - Update bus ID if needed

4. TESTING:
   - Upload code to ESP32
   - Open Serial Monitor (115200 baud)
   - Place GPS module near window/outdoors
   - Wait for GPS lock (30-60 seconds)
   - Watch for successful data transmission

5. EXPECTED OUTPUT:
   🚌 ESP32 GPS Bus Tracker - Starting...
   📡 GPS initialized on UART2 (RX:16, TX:17) @9600
   ✅ WiFi connected successfully!
   📱 ESP32 IP address: 192.168.1.XXX
   ✅ Server connection successful!
   📍 GPS Data:
      LAT : 27.717200
      LON : 85.324000
      SPD : 0.0 km/h
   ✅ GPS data sent successfully!

=======================================================================
TROUBLESHOOTING:
=======================================================================

GPS Issues:
- No GPS data: Check wiring, ensure clear sky view
- Slow GPS lock: Wait outdoors, GPS needs time for first fix

WiFi Issues:
- Connection failed: Check SSID/password, ensure 2.4GHz network
- Frequent disconnects: Check signal strength, move closer to router

Server Issues:
- Connection failed: Verify server IP, ensure server is running
- Data not received: Check firewall, ensure server accessible

=======================================================================
*/
