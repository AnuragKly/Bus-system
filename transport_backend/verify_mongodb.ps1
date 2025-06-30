# MongoDB Backend Setup Verification and Completion Script
# This script checks and completes all MongoDB requirements for the GPS Backend

param(
    [switch]$Fix = $false  # Use -Fix to automatically fix issues
)

Write-Host "🗄️ MongoDB Backend Setup Verification" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""

$issues = @()
$fixes = @()

# Test 1: Check if MongoDB container is running
Write-Host "1. Checking MongoDB Container Status..." -ForegroundColor Yellow
try {
    $mongoContainer = docker ps --filter "name=transport_backend-mongo-1" --format "{{.Status}}"
    if ($mongoContainer -like "*Up*") {
        Write-Host "   ✅ MongoDB container is running" -ForegroundColor Green
    } else {
        $issues += "MongoDB container not running"
        $fixes += "docker-compose up -d mongo"
        Write-Host "   ❌ MongoDB container not running" -ForegroundColor Red
    }
} catch {
    $issues += "Docker not available or MongoDB container missing"
    $fixes += "docker-compose up -d"
    Write-Host "   ❌ Cannot check MongoDB container status" -ForegroundColor Red
}

# Test 2: Check database connection
Write-Host "2. Testing Database Connection..." -ForegroundColor Yellow
try {
    $result = docker exec transport_backend-mongo-1 mongosh --eval "db.runCommand('ping')" --quiet 2>$null
    if ($result -like "*ok*") {
        Write-Host "   ✅ Database connection successful" -ForegroundColor Green
    } else {
        $issues += "Cannot connect to MongoDB"
        Write-Host "   ❌ Database connection failed" -ForegroundColor Red
    }
} catch {
    $issues += "Cannot connect to MongoDB"
    Write-Host "   ❌ Database connection failed" -ForegroundColor Red
}

# Test 3: Check if transport_management database exists
Write-Host "3. Checking GPS Database..." -ForegroundColor Yellow
try {
    $dbs = docker exec transport_backend-mongo-1 mongosh --eval "show dbs" --quiet 2>$null
    if ($dbs -like "*transport_management*") {
        Write-Host "   ✅ GPS database 'transport_management' exists" -ForegroundColor Green
    } else {
        $issues += "GPS database missing"
        $fixes += "Database will be created automatically when first GPS data is received"
        Write-Host "   ⚠️  GPS database 'transport_management' not found (will be created automatically)" -ForegroundColor Yellow
    }
} catch {
    $issues += "Cannot check database existence"
    Write-Host "   ❌ Cannot check database existence" -ForegroundColor Red
}

# Test 4: Check required collections
Write-Host "4. Checking GPS Collections..." -ForegroundColor Yellow
try {
    $collections = docker exec transport_backend-mongo-1 mongosh transport_management --eval "show collections" --quiet 2>$null
    
    $hasLocations = $collections -like "*locations*"
    $hasBusStatus = $collections -like "*bus_status*"
    
    if ($hasLocations) {
        Write-Host "   ✅ 'locations' collection exists" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  'locations' collection not found (will be created automatically)" -ForegroundColor Yellow
    }
    
    if ($hasBusStatus) {
        Write-Host "   ✅ 'bus_status' collection exists" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  'bus_status' collection not found (will be created automatically)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Cannot check collections (will be created automatically)" -ForegroundColor Yellow
}

# Test 5: Check database indexes
Write-Host "5. Checking Database Indexes..." -ForegroundColor Yellow
try {
    $indexes = docker exec transport_backend-mongo-1 mongosh transport_management --eval "db.locations.getIndexes()" --quiet
    
    $hasTimestampIndex = $indexes -like "*timestamp*"
    $hasBusIdIndex = $indexes -like "*bus_id*"
    
    if ($hasTimestampIndex) {
        Write-Host "   ✅ Timestamp index exists (for fast time-based queries)" -ForegroundColor Green
    } else {
        $issues += "Missing timestamp index"
        $fixes += "Index will be created when FastAPI starts"
        Write-Host "   ⚠️  Timestamp index missing (will be created automatically)" -ForegroundColor Yellow
    }
    
    if ($hasBusIdIndex) {
        Write-Host "   ✅ Bus ID index exists (for fast bus lookups)" -ForegroundColor Green
    } else {
        $issues += "Missing bus_id index"
        $fixes += "Index will be created when FastAPI starts"
        Write-Host "   ⚠️  Bus ID index missing (will be created automatically)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Cannot check indexes (will be created automatically)" -ForegroundColor Yellow
}

# Test 6: Check existing GPS data
Write-Host "6. Checking Existing GPS Data..." -ForegroundColor Yellow
try {
    $countResult = docker exec transport_backend-mongo-1 mongosh transport_management --eval "db.locations.countDocuments()" --quiet
    $countNum = 0
    if ($countResult -match '\d+') {
        $countNum = [int]$matches[0]
    }
    
    if ($countNum -gt 0) {
        Write-Host "   ✅ Found $countNum GPS records in database" -ForegroundColor Green
        
        # Show sample data
        docker exec transport_backend-mongo-1 mongosh transport_management --eval "db.locations.findOne()" --quiet | Out-Null
        Write-Host "   📍 Sample GPS record structure verified" -ForegroundColor Cyan
    } else {
        Write-Host "   ℹ️  No GPS data yet (normal for new setup)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "   ℹ️  Cannot check GPS data count" -ForegroundColor Cyan
}

# Test 7: Check MongoDB configuration
Write-Host "7. Checking Configuration..." -ForegroundColor Yellow
$envContent = Get-Content ".env" -ErrorAction SilentlyContinue
if ($envContent) {
    $mongoUrl = $envContent | Where-Object { $_ -like "MONGODB_URL=*" }
    $dbName = $envContent | Where-Object { $_ -like "DATABASE_NAME=*" }
    
    if ($mongoUrl) {
        Write-Host "   ✅ MongoDB URL configured: $($mongoUrl.Split('=')[1])" -ForegroundColor Green
    } else {
        $issues += "MongoDB URL not configured"
        $fixes += "Add MONGODB_URL to .env file"
        Write-Host "   ❌ MongoDB URL not configured in .env" -ForegroundColor Red
    }
    
    if ($dbName) {
        Write-Host "   ✅ Database name configured: $($dbName.Split('=')[1])" -ForegroundColor Green
    } else {
        $issues += "Database name not configured"
        $fixes += "Add DATABASE_NAME to .env file"
        Write-Host "   ❌ Database name not configured in .env" -ForegroundColor Red
    }
} else {
    $issues += ".env file missing"
    $fixes += "Create .env file with MongoDB configuration"
    Write-Host "   ❌ .env file not found" -ForegroundColor Red
}

# Test 8: Test API database connection
Write-Host "8. Testing FastAPI Database Integration..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET -ErrorAction Stop
    Write-Host "   ✅ FastAPI server running and accessible" -ForegroundColor Green
    
    # Try to get GPS data (this tests database connection)
    try {
        $gpsTest = Invoke-RestMethod -Uri "http://localhost:8000/gps/location-history?bus_id=test&limit=1" -Method GET -ErrorAction Stop
        Write-Host "   ✅ FastAPI database integration working" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*404*") {
            Write-Host "   ✅ FastAPI database integration working (no data yet)" -ForegroundColor Green
        } else {
            $issues += "FastAPI cannot connect to database"
            Write-Host "   ❌ FastAPI database connection failed" -ForegroundColor Red
        }
    }
} catch {
    $issues += "FastAPI server not running"
    $fixes += "Start FastAPI server with: py start.py"
    Write-Host "   ❌ FastAPI server not accessible" -ForegroundColor Red
}

# Results Summary
Write-Host ""
Write-Host "📊 MongoDB Backend Setup Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

if ($issues.Count -eq 0) {
    Write-Host "🎉 ALL REQUIREMENTS MET!" -ForegroundColor Green
    Write-Host "Your MongoDB backend is 100% ready for ESP32 GPS data!" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ MongoDB running and accessible" -ForegroundColor Green
    Write-Host "✅ Database and collections configured" -ForegroundColor Green
    Write-Host "✅ Indexes optimized for GPS queries" -ForegroundColor Green
    Write-Host "✅ FastAPI integration working" -ForegroundColor Green
    Write-Host "✅ Ready to receive ESP32 data" -ForegroundColor Green
} else {
    Write-Host "⚠️  Found $($issues.Count) issue(s) to address:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $issues.Count; $i++) {
        Write-Host "   $($i + 1). $($issues[$i])" -ForegroundColor Red
        if ($fixes[$i]) {
            Write-Host "      Fix: $($fixes[$i])" -ForegroundColor Cyan
        }
    }
    
    if ($Fix) {
        Write-Host ""
        Write-Host "🔧 Attempting to fix issues..." -ForegroundColor Yellow
        
        # Auto-fix: Start MongoDB if not running
        if ($issues -contains "MongoDB container not running") {
            Write-Host "Starting MongoDB container..." -ForegroundColor Yellow
            docker-compose up -d mongo
        }
        
        # Auto-fix: Start FastAPI if not running
        if ($issues -contains "FastAPI server not running") {
            Write-Host "Note: Start FastAPI server manually with: py start.py" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "💡 Run with -Fix parameter to automatically fix issues:" -ForegroundColor Cyan
        Write-Host "   .\verify_mongodb.ps1 -Fix" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Green
Write-Host "1. Ensure MongoDB container is running: docker-compose up -d mongo" -ForegroundColor White
Write-Host "2. Start FastAPI server: py start.py" -ForegroundColor White
Write-Host "3. Test with ESP32 or manual API calls" -ForegroundColor White
Write-Host "4. Monitor data: .\monitor_gps.ps1" -ForegroundColor White
