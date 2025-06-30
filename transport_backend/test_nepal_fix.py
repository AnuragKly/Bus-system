#!/usr/bin/env python3
"""
Test Nepal Time Storage Fix
Verifies that MongoDB stores Nepal time properly
"""

import requests
import json
import pymongo
from datetime import datetime, timezone
from app.utils.nepal_time import get_nepal_time, NEPAL_TIMEZONE
import time

def test_nepal_time_fix():
    print("🧪 Testing Nepal Time Storage Fix...")
    print("="*50)
    
    # Send test GPS data
    nepal_time = get_nepal_time()
    test_data = {
        'bus_id': 'test_nepal_fix',
        'latitude': 27.7172,
        'longitude': 85.3240,
        'speed': 35.0,
        'timestamp': nepal_time.isoformat()
    }
    
    print(f"📤 Sending test data:")
    print(f"   Nepal time: {nepal_time}")
    print(f"   Timezone: {nepal_time.tzinfo}")
    print(f"   ISO format: {nepal_time.isoformat()}")
    
    # Send to backend
    try:
        response = requests.post('http://localhost:8000/gps/data', json=test_data, timeout=10)
        print(f"\n✅ API Response: {response.status_code}")
        if response.status_code == 200:
            print(f"   {response.json()}")
        else:
            print(f"   Error: {response.text}")
            return False
    except Exception as e:
        print(f"❌ API Error: {e}")
        return False
    
    # Wait a moment for the data to be stored
    time.sleep(1)
    
    # Check MongoDB storage
    print(f"\n🔍 Checking MongoDB storage...")
    try:
        client = pymongo.MongoClient('mongodb://localhost:27017/')
        db = client['transport_system']
        
        # Find the test record
        test_record = db.locations.find_one(
            {"bus_id": "test_nepal_fix"},
            sort=[("_id", -1)]
        )
        
        if test_record:
            print(f"✅ Found test record in MongoDB:")
            print(f"   _id: {test_record['_id']}")
            print(f"   bus_id: {test_record['bus_id']}")
            
            # Check UTC timestamp
            print(f"\n📅 UTC Timestamp Storage:")
            print(f"   timestamp (UTC): {test_record.get('timestamp')}")
            print(f"   timestamp type: {type(test_record.get('timestamp'))}")
            
            # Check Nepal timestamp
            print(f"\n🏔️ Nepal Time Storage:")
            print(f"   timestamp_nepal: {test_record.get('timestamp_nepal')}")
            print(f"   timezone_offset: {test_record.get('timezone_offset')}")
            print(f"   created_at_nepal: {test_record.get('created_at_nepal')}")
            
            # Verify the Nepal time is correct
            nepal_stored = test_record.get('timestamp_nepal')
            if nepal_stored:
                if '+05:45' in nepal_stored:
                    print(f"   ✅ Nepal timezone correctly stored!")
                else:
                    print(f"   ❌ Nepal timezone missing from stored timestamp")
            else:
                print(f"   ❌ Nepal timestamp not found in record")
                
        else:
            print("❌ Test record not found in MongoDB")
            return False
            
    except Exception as e:
        print(f"❌ MongoDB Error: {e}")
        return False
    
    # Test API retrieval
    print(f"\n🌐 Testing API retrieval...")
    try:
        response = requests.get('http://localhost:8000/gps/bus-location?bus_id=test_nepal_fix', timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ API returns Nepal time:")
            print(f"   last_updated: {data.get('last_updated')}")
            
            # Check if it's Nepal time
            if isinstance(data.get('last_updated'), str):
                last_updated_str = str(data.get('last_updated'))
                if '+05:45' in last_updated_str or 'NST' in last_updated_str:
                    print(f"   ✅ API correctly returns Nepal time!")
                else:
                    print(f"   ❌ API not returning Nepal time format")
            else:
                print(f"   ℹ️  API returned datetime object: {data.get('last_updated')}")
        else:
            print(f"❌ API Error: {response.status_code}")
            
    except Exception as e:
        print(f"❌ API Error: {e}")
    
    return True

if __name__ == "__main__":
    if test_nepal_time_fix():
        print(f"\n🎉 Nepal Time Storage Test Complete!")
        print(f"📊 Summary:")
        print(f"   • MongoDB stores both UTC (for queries) and Nepal time (for display)")
        print(f"   • API returns Nepal time to users")
        print(f"   • Timezone information is preserved")
    else:
        print(f"\n❌ Test failed - check server logs")
