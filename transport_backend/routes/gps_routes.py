from flask import Blueprint, request, jsonify
from models.gps_model import insert_gps_data, get_latest_gps

gps_routes = Blueprint("gps_routes", __name__)

# POST endpoint to receive GPS data
@gps_routes.route('/api/gps', methods=['POST'])
def receive_gps():
    data = request.get_json()

    bus_id = data.get('busId')
    latitude = data.get('latitude')
    longitude = data.get('longitude')

    if not all([bus_id, latitude, longitude]):
        return jsonify({"error": "Missing data"}), 400

    insert_gps_data(bus_id, latitude, longitude)
    return jsonify({"message": "GPS data saved"}), 200


# GET endpoint to retrieve latest GPS data
@gps_routes.route('/api/gps', methods=['GET'])
def fetch_latest_gps():
    gps_list = get_latest_gps()
    
    for gps in gps_list:
        gps['_id'] = str(gps['_id'])  # Convert ObjectId to string

    return jsonify(gps_list), 200
