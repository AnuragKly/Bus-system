from flask import Flask
from config import Config
from models.gps_model import mongo
from routes.gps_routes import gps_routes

app = Flask(__name__)
app.config.from_object(Config)

mongo.init_app(app)  # Connect Flask to MongoDB
app.register_blueprint(gps_routes)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)
