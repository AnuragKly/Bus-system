# Real-Time GPS Data Monitor
# Run this script to watch GPS data coming from ESP32 in real-time

param(
    [string]$BusId = "bus_001",
    [int]$RefreshSeconds = 3
)

Write-Host "🚌 Real-Time GPS Data Monitor" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host "Monitoring Bus ID: $BusId" -ForegroundColor Cyan
Write-Host "Refresh Rate: Every $RefreshSeconds seconds" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

$counter = 0

while ($true) {
    $counter++
    
    # Clear screen every 20 iterations to keep it clean
    if ($counter % 20 -eq 0) {
        Clear-Host
        Write-Host "🚌 Real-Time GPS Data Monitor" -ForegroundColor Green
        Write-Host "=============================" -ForegroundColor Green
        Write-Host "Monitoring Bus ID: $BusId" -ForegroundColor Cyan
        Write-Host ""
    }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] Checking GPS data..." -ForegroundColor Yellow
    
    try {
        # Get current location
        $location = Invoke-RestMethod -Uri "http://localhost:8000/gps/bus-location?bus_id=$BusId" -Method GET -ErrorAction Stop
        
        Write-Host "✅ GPS Data Found:" -ForegroundColor Green
        Write-Host "   Bus ID: $($location.bus_id)" -ForegroundColor White
        Write-Host "   Latitude: $($location.latitude)" -ForegroundColor White
        Write-Host "   Longitude: $($location.longitude)" -ForegroundColor White
        Write-Host "   Speed: $($location.speed) km/h" -ForegroundColor White
        Write-Host "   Last Update: $($location.timestamp)" -ForegroundColor White
        Write-Host "   Data Age: $($location.location_age_seconds) seconds" -ForegroundColor $(if ($location.location_age_seconds -lt 10) { "Green" } else { "Yellow" })
        
        # Get total record count
        try {
            $history = Invoke-RestMethod -Uri "http://localhost:8000/gps/location-history?bus_id=$BusId&limit=1" -Method GET -ErrorAction Stop
            Write-Host "   Total Records: $($history.total_locations)" -ForegroundColor Cyan
        } catch {
            Write-Host "   Total Records: Unable to fetch" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ No GPS data available for bus $BusId" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Possible reasons:" -ForegroundColor Yellow
        Write-Host "   - ESP32 not connected" -ForegroundColor Yellow
        Write-Host "   - GPS not locked" -ForegroundColor Yellow
        Write-Host "   - Server not running" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Start-Sleep -Seconds $RefreshSeconds
}

# Usage Examples:
# .\monitor_gps.ps1                          # Monitor bus_001 every 3 seconds
# .\monitor_gps.ps1 -BusId bus_002          # Monitor bus_002 every 3 seconds  
# .\monitor_gps.ps1 -RefreshSeconds 1       # Monitor every 1 second
# .\monitor_gps.ps1 -BusId bus_003 -RefreshSeconds 5  # Monitor bus_003 every 5 seconds
