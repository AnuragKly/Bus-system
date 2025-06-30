from pydantic_settings import BaseSettings
from pydantic import ConfigDict

class Settings(BaseSettings):
    model_config = ConfigDict(
        env_file=".env",
        extra="ignore"  # Ignore extra fields from environment
    )
    
    mongodb_url: str = "mongodb://localhost:27017/?directConnection=true"
    database_name: str = "transport_management"

settings = Settings()