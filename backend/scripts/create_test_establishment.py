import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.db_config import SessionLocal, Base, engine
from app.models.models import Establishment, User
from app.core.security import get_password_hash

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

def seed_db():
    db = SessionLocal()
    
    # 1. Check if establishment exists
    est = db.query(Establishment).filter(Establishment.code == "KINE-2026").first()
    if not est:
        est = Establishment(name="Clinique Kiné Paris", code="KINE-2026", contact_email="contact@kine-paris.fr")
        db.add(est)
        db.commit()
        db.refresh(est)
        print(f"✅ Created Establishment: {est.name} (Code: {est.code})")
    
    # 2. Check if super admin exists
    sa = db.query(User).filter(User.email == "ikram@superadmin.com").first()
    if not sa:
        sa = User(
            pseudo="Ikram (SuperAdmin)",
            email="ikram@superadmin.com",
            password_hash=get_password_hash("password123"),
            role="super_admin",
            establishment_id=est.establishment_id
        )
        db.add(sa)
        print(f"✅ Created Super Admin: {sa.email}")
        
    # 3. Create mock patients for the clinic
    patients_data = [
        ("Jean Dupont", "jean.dupont@email.com"),
        ("Marie Curie", "marie.curie@email.com"),
        ("Paul Lambert", "paul.lambert@email.com"),
        ("Alice Martin", "alice.martin@email.com"),
        ("Mohamed Benali", "mohamed.benali@email.com"),
        ("Sophie Durand", "sophie.durand@email.com"),
    ]
    
    for name, email in patients_data:
        p = db.query(User).filter(User.email == email).first()
        if not p:
            new_p = User(
                pseudo=name,
                email=email,
                password_hash=get_password_hash("password123"),
                role="user",
                establishment_id=est.establishment_id,
                profile_json={"taille": 175, "poids": 70, "age": 30}
            )
            db.add(new_p)
            print(f"✅ Created Patient: {email}")
    
    # 4. Check if local admin exists
    admin = db.query(User).filter(User.email == "doc@kine-paris.fr").first()
    if not admin:
        admin = User(
            pseudo="Dr. Dupont",
            email="doc@kine-paris.fr",
            password_hash=get_password_hash("password123"),
            role="admin",
            establishment_id=est.establishment_id
        )
        db.add(admin)
        print(f"✅ Created Local Admin: {admin.email}")
        
    db.commit()
    print("🚀 Seeding finished successfully.")
    db.close()

if __name__ == "__main__":
    seed_db()
