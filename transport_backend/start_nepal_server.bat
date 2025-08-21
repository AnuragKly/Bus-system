@echo off
echo 🇳🇵 Starting Nepal Time Backend Server (UPDATED)
echo =============================================
echo.
echo 🔧 NEW FEATURES:
echo    • Stores both UTC and Nepal time in MongoDB
echo    • API returns Nepal Standard Time (NST)
echo    • Timezone-aware storage and retrieval
echo    • Preserves Nepal time in project defense
echo.
echo 🌐 Server will be available at: http://localhost:8000
echo 📚 Documentation at: http://localhost:8000/docs
echo.
cd /d "c:\Users\taman\OneDrive\Desktop\Bus-system\transport_backend"
call .venv\Scripts\activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
