from datetime import timedelta
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests

from app.db.db_config import get_db
from app.models.models import User
from app.schemas.user import UserCreate, UserLogin, UserGoogleAuth, Token, User as UserSchema, UserUpdate, UserPasswordUpdate, UserResetPassword, UserProfileUpdate
from app.core.security import get_password_hash, verify_password, create_access_token
from app.core.config import settings

router = APIRouter()

@router.post("/register", response_model=Token)
def register(
    *,
    db: Session = Depends(get_db),
    user_in: UserCreate,
) -> Any:
    """
    Crée un nouvel utilisateur.
    """
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(
            status_code=400,
            detail="TThe user with this user name already exists in the system.",
        )
    user = User(
        email=user_in.email,
        pseudo=user_in.pseudo,
        password_hash=get_password_hash(user_in.password)
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

