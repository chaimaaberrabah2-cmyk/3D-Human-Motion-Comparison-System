from datetime import timedelta
from typing import Any, Optional, Dict, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests

from app.database.setup import get_db
from app.database.models import User
from app.database.schemas import UserCreate, UserLogin, UserGoogleAuth, Token, User as UserSchema, UserUpdate, UserPasswordUpdate, UserResetPassword, UserProfileUpdate
from pydantic import BaseModel, EmailStr
from app.security import get_password_hash, verify_password, create_access_token
from app.config import settings
from app.database.schemas import Establishment as EstablishmentSchema, EstablishmentCreate
from app.database.models import User, Establishment

router = APIRouter()

# No local class definition needed, using EstablishmentCreate from schemas

@router.post("/establishments", response_model=Dict[str, Any])
def create_establishment(
    est_in: EstablishmentCreate,
    db: Session = Depends(get_db),
):
    """
    Crée un nouvel établissement (Clinique/Cabinet).
    Normalement réservé au Super Admin.
    """
    db_est = db.query(Establishment).filter(Establishment.code == est_in.code).first()
    if db_est:
        raise HTTPException(status_code=400, detail="Un établissement avec ce code existe déjà.")
    
    new_est = Establishment(
        name=est_in.name,
        code=est_in.code,
        contact_email=est_in.contact_email
    )
    db.add(new_est)
    db.commit()
    db.refresh(new_est)
    return {"message": "Établissement créé avec succès", "establishment": new_est}

@router.get("/establishments", response_model=List[EstablishmentSchema])
def get_establishments(db: Session = Depends(get_db)):
    """Liste tous les établissements."""
    return db.query(Establishment).all()

@router.post("/register", response_model=Token)
def register(
    *,
    db: Session = Depends(get_db),
    user_in: UserCreate,
) -> Any:
    """
    Crée un nouvel utilisateur.
    Vérifie que le code de l'établissement existe.
    """
    # 1. Check Establishment
    establishment = db.query(Establishment).filter(Establishment.code == user_in.establishment_code).first()
    if not establishment:
        raise HTTPException(
            status_code=400,
            detail="Le code d'établissement est invalide ou n'existe pas.",
        )
        
    # 2. Check if user exists
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(
            status_code=400,
            detail="The user with this email already exists in the system.",
        )
        
    # 3. Create User
    user = User(
        email=user_in.email,
        pseudo=user_in.pseudo,
        password_hash=get_password_hash(user_in.password),
        establishment_id=establishment.establishment_id,
        role='user' # Default is 'user' (patient)
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return {
        "access_token": create_access_token(
            user.user_id, expires_delta=access_token_expires
        ),
        "token_type": "bearer",
        "user": user
    }


@router.post("/login", response_model=Token)
def login(
    db: Session = Depends(get_db),
    user_in: UserLogin = None,
) -> Any:
    """
    Authentification classique par email / mot de passe.
    """
    user = db.query(User).filter(User.email == user_in.email).first()
    if not user or not verify_password(user_in.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return {
        "access_token": create_access_token(
            user.user_id, expires_delta=access_token_expires
        ),
        "token_type": "bearer",
        "user": user
    }


@router.post("/google", response_model=Token)
def google_auth(
    auth_in: UserGoogleAuth,
    db: Session = Depends(get_db),
) -> Any:
    """
    Authentification via Google Sign-In.
    """
    try:
        # Verify the token with Google — try each accepted client ID
        idinfo = None
        last_error = None
        for client_id in settings.GOOGLE_ACCEPTED_CLIENT_IDS:
            try:
                idinfo = id_token.verify_oauth2_token(
                    auth_in.id_token,
                    requests.Request(),
                    client_id,
                    clock_skew_in_seconds=10,
                )
                break  # Success — stop trying
            except ValueError as e:
                last_error = e
        
        if idinfo is None:
            raise ValueError(str(last_error))
        
        email = idinfo['email']
        pseudo = idinfo.get('name', email.split('@')[0])
        
        # Check if user exists
        user = db.query(User).filter(User.email == email).first()
        
        if not user:
            # Create a new user for Google Sign-In
            user = User(
                email=email,
                pseudo=pseudo,
                # For google auth, we don't have a real password
                password_hash=get_password_hash("GOOGLE_SSO_USER_NO_PASSWORD")
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            
        access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        return {
            "access_token": create_access_token(
                user.user_id, expires_delta=access_token_expires
            ),
            "token_type": "bearer",
            "user": user
        }
    except ValueError as e:
        # Invalid token
        raise HTTPException(
            status_code=401,
            detail=f"Invalid Google token: {str(e)}",
        )

@router.put("/update", response_model=UserSchema)
def update_user(
    *,
    db: Session = Depends(get_db),
    user_in: UserUpdate,
) -> Any:
    """
    Update user personal information.
    """
    user = db.query(User).filter(User.email == user_in.old_email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable.")
    
    # Check if new email is taken by another user
    if user_in.new_email != user_in.old_email:
        existing_user = db.query(User).filter(User.email == user_in.new_email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="L'email est déjà utilisé par un autre compte.")
            
    user.email = user_in.new_email
    user.pseudo = user_in.pseudo
    db.commit()
    db.refresh(user)
    return user

@router.post("/establishments/{establishment_id}/admin", response_model=Dict[str, Any])
def create_establishment_admin(
    establishment_id: int,
    admin_in: UserCreate, # Reusing UserCreate but we'll ignore establishment_code from it if needed, or just use it.
    db: Session = Depends(get_db),
):
    """
    Crée un compte administrateur pour un établissement spécifique.
    Réservé au Super Admin.
    """
    # 1. Check Establishment
    est = db.query(Establishment).filter(Establishment.establishment_id == establishment_id).first()
    if not est:
        raise HTTPException(status_code=404, detail="Établissement introuvable.")
        
    # 2. Check if user exists
    user = db.query(User).filter(User.email == admin_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé.")
        
    # 3. Create Admin User
    new_admin = User(
        email=admin_in.email,
        pseudo=admin_in.pseudo,
        password_hash=get_password_hash(admin_in.password),
        establishment_id=establishment_id,
        role='admin' # Force role to admin
    )
    db.add(new_admin)
    db.commit()
    db.refresh(new_admin)
    
    return {"message": "Compte Administrateur créé avec succès.", "user": new_admin}

@router.get("/establishments/{establishment_id}/users", response_model=List[UserSchema])
def get_establishment_users(
    establishment_id: int,
    db: Session = Depends(get_db),
):
    """
    Récupère la liste des utilisateurs (patients) d'un établissement spécifique.
    """
    users = db.query(User).filter(User.establishment_id == establishment_id).all()
    return users

@router.put("/update_password")
def update_password(
    *,
    db: Session = Depends(get_db),
    password_in: UserPasswordUpdate,
) -> Any:
    """
    Update user password.
    """
    user = db.query(User).filter(User.email == password_in.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable.")
    
    if not verify_password(password_in.old_password, user.password_hash):
        raise HTTPException(status_code=400, detail="L'ancien mot de passe est incorrect.")
        
    user.password_hash = get_password_hash(password_in.new_password)
    db.commit()
    return {"message": "Mot de passe mis à jour avec succès"}

@router.post("/reset-password")
def reset_password(
    *,
    db: Session = Depends(get_db),
    reset_in: UserResetPassword,
) -> Any:
    """
    Reset user password (mock OTP flow).
    """
    user = db.query(User).filter(User.email == reset_in.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable.")
    user.password_hash = get_password_hash(reset_in.new_password)
    db.commit()
    return {"message": "Mot de passe réinitialisé avec succès"}


@router.put("/profile")
def update_profile(
    *,
    db: Session = Depends(get_db),
    profile_in: UserProfileUpdate,
) -> Any:
    """
    Update user body measurements stored in profile_json.
    """
    user = db.query(User).filter(User.email == profile_in.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable.")

    # Merge with existing profile data so we don't lose other fields
    existing = user.profile_json or {}
    updated = {
        **existing,
        "height": profile_in.height,
        "weight": profile_in.weight,
        "age": profile_in.age,
        "gender": profile_in.gender,
    }
    # Remove None values to avoid overwriting existing with null
    updated = {k: v for k, v in updated.items() if v is not None}

    user.profile_json = updated
    db.commit()
    db.refresh(user)
    return {"message": "Profile updated successfully", "profile": user.profile_json}

