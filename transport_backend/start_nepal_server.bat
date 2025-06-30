@echo off
echo 🇳🇵 Starting Nepal Time Backend Server (UPDATED)
echo =============================================
echo.
echo 🔧 NEW FEATURES:
echo    • Stores both UTC and Nepal time in MongoDB
echo    • API returns Nepal Standard Time (NST)
echo    • Timezone-aware storage and retrieval
echo    • Preserves Nepal time for project defense
echo.
echo 🌐 Server will be available at: http://localhost:8000
echo 📚 Documentation at: http://localhost:8000/docs
echo.
cd /d "c:\VS code\Bus Repository\Bus-system\transport_backend"
py -3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
