"""
Network Information for GPS API Server
"""
import socket
import subprocess

def get_local_ip():
    """Get the local IP address"""
    try:
        # Connect to a remote address to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "Unable to determine"

def get_network_info():
    """Get network information using ipconfig"""
    try:
        result = subprocess.run(['ipconfig'], capture_output=True, text=True, shell=True)
        lines = result.stdout.split('\n')
        
        current_adapter = ""
        ip_addresses = []
        
        for line in lines:
            line = line.strip()
            if 'adapter' in line.lower() and ':' in line:
                current_adapter = line
            elif 'IPv4 Address' in line and '192.168' in line or '10.' in line or '172.' in line:
                ip = line.split(':')[-1].strip()
                ip_addresses.append((current_adapter, ip))
        
        return ip_addresses
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    print("🌐 Network Information for GPS API Server")
    print("=" * 50)
    
    # Get local IP
    local_ip = get_local_ip()
    print(f"📍 Detected Local IP: {local_ip}")
    
    # Get all network adapters
    print("\n🔌 Available Network Interfaces:")
    network_info = get_network_info()
    
    if isinstance(network_info, list):
        for adapter, ip in network_info:
            print(f"   {adapter}")
            print(f"   └─ IP: {ip}")
            print()
    else:
        print(f"   {network_info}")
    
    print("📡 Your GPS API Server URLs:")
    print(f"   Local:    http://localhost:8000")
    print(f"   Local:    http://127.0.0.1:8000")
    print(f"   Network:  http://{local_ip}:8000")
    print()
    print("💡 Use the Network URL for:")
    print("   • ESP32 devices")
    print("   • Mobile apps")
    print("   • Other computers on your network")
    print()
    print("🔧 Use Local URLs for:")
    print("   • Testing on this computer")
    print("   • Web browser access")
    print("   • Development tools")
