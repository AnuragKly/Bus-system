"""
Robust GPS API Server Starter with Port Checking
"""
import socket
import subprocess
import sys
import os

def is_port_in_use(port):
    """Check if a port is already in use"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def kill_process_on_port(port):
    """Kill process using the specified port"""
    try:
        # Find process using the port
        result = subprocess.run(
            ['netstat', '-ano'], 
            capture_output=True, 
            text=True, 
            shell=True
        )
        
        for line in result.stdout.split('\n'):
            if f':{port}' in line and 'LISTENING' in line:
                # Extract PID (last column)
                pid = line.strip().split()[-1]
                print(f"Found process {pid} using port {port}")
                
                # Kill the process
                subprocess.run(['taskkill', '/PID', pid, '/F'], shell=True)
                print(f"✅ Killed process {pid}")
                return True
        return False
    except Exception as e:
        print(f"❌ Error killing process: {e}")
        return False

def start_server():
    """Start the FastAPI server"""
    print("🚌 GPS Tracking API Server")
    print("=" * 40)
    
    port = 8000
    
    # Check if port is in use
    if is_port_in_use(port):
        print(f"⚠️  Port {port} is already in use!")
        print("Attempting to free the port...")
        
        if kill_process_on_port(port):
            print("Port freed successfully!")
        else:
            print("❌ Could not free the port. Trying alternative port...")
            port = 8001
    
    try:
        # Add current directory to path
        current_dir = os.path.dirname(os.path.abspath(__file__))
        sys.path.insert(0, current_dir)
        
        import uvicorn
        
        print(f"Starting server on http://0.0.0.0:{port}")
        print("Press Ctrl+C to stop the server")
        print("=" * 40)
        
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=port,
            reload=False,
            log_level="info"
        )
        
    except ImportError as e:
        print(f"❌ Missing package: {e}")
        print("\nPlease install the required packages:")
        print("py -3 -m pip install fastapi uvicorn motor pymongo pydantic pydantic-settings python-dotenv requests --user")
        
    except Exception as e:
        print(f"❌ Error starting server: {e}")
        
    finally:
        input("\nPress Enter to exit...")

if __name__ == "__main__":
    start_server()
