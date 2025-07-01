#!/usr/bin/env python3
"""
Simple start script for the GPS Bus Tracking backend
"""

import uvicorn
import os

if __name__ == "__main__":
    print("🚌 Starting GPS Bus Tracking Backend...")
    print("🌐 Server will be available at: http://localhost:8000")
    print("📚 API documentation at: http://localhost:8000/docs")
    
    # Start the server
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
