import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "3D Human Motion Comparison API"
    
    # Database
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: str = os.getenv("DB_PORT", "5432")
    DB_NAME: str = os.getenv("DB_NAME", "motion_compare_db")
    DB_USER: str = os.getenv("DB_USER", "postgres")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "ikram")
    
    # Security
    # In production, use a strong generated secret key!
    SECRET_KEY: str = os.getenv("SECRET_KEY", "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440")) # 24 hours
    
    # Google OAuth - iOS/macOS client (does not require client_secret)
    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID", "551021597507-eh1r6gr4lagin2mtt4a0becp52gfr32d.apps.googleusercontent.com")
    # Accepted audience list: includes both iOS/macOS and Web client IDs
    GOOGLE_ACCEPTED_CLIENT_IDS: list = [
        "551021597507-eh1r6gr4lagin2mtt4a0becp52gfr32d.apps.googleusercontent.com",
        "551021597507-fs6bmdqdnu0at2onk0mvjav6s8up5usi.apps.googleusercontent.com",
    ]

settings = Settings()
