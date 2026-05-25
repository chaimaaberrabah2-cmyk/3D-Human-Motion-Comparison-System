import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database.setup import SessionLocal, Base, engine
from app.database.models import Establishment, User
from app.security import get_password_hash

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

def seed_db():
    db = SessionLocal()
    
    # 1. Seed Clinic Establishment
    est_kine = db.query(Establishment).filter(Establishment.code == "KINE-2026").first()
    if not est_kine:
        est_kine = Establishment(name="Clinique Kiné Paris", code="KINE-2026", contact_email="contact@kine-paris.fr")
        db.add(est_kine)
        db.commit()
        db.refresh(est_kine)
        print(f"✅ Created Clinic Establishment: {est_kine.name} (Code: {est_kine.code})")
    
    # 2. Seed Gym Establishment
    est_gym = db.query(Establishment).filter(Establishment.code == "GYM-2026").first()
    if not est_gym:
        est_gym = Establishment(name="FitLife Club Paris", code="GYM-2026", contact_email="contact@fitlife-paris.fr")
        db.add(est_gym)
        db.commit()
        db.refresh(est_gym)
        print(f"✅ Created Gym Establishment: {est_gym.name} (Code: {est_gym.code})")

    # 3. Check if super admin exists
    sa = db.query(User).filter(User.email == "ikram@superadmin.com").first()
    if not sa:
        sa = User(
            pseudo="Ikram (SuperAdmin)",
            email="ikram@superadmin.com",
            password_hash=get_password_hash("password123"),
            role="super_admin",
            establishment_id=est_gym.establishment_id
        )
        db.add(sa)
        print(f"✅ Created Super Admin: {sa.email}")
        
    # 4. Create mock patients for the clinic
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
                establishment_id=est_kine.establishment_id,
                profile_json={"taille": 175, "poids": 70, "age": 30}
            )
            db.add(new_p)
            print(f"✅ Created Patient (Clinic): {email}")
            
    # 5. Create mock adherents (members) for the gym
    adherents_data = [
        ("Thomas Bernard", "thomas.bernard@email.com"),
        ("Julie Petit", "julie.petit@email.com"),
        ("Nicolas Roux", "nicolas.roux@email.com"),
        ("Emma Dubois", "emma.dubois@email.com"),
        ("Karim Belkacem", "karim.belkacem@email.com"),
        ("Sarah Morel", "sarah.morel@email.com"),
    ]
    
    for name, email in adherents_data:
        p = db.query(User).filter(User.email == email).first()
        if not p:
            new_p = User(
                pseudo=name,
                email=email,
                password_hash=get_password_hash("password123"),
                role="user",
                establishment_id=est_gym.establishment_id,
                profile_json={"taille": 180, "poids": 78, "age": 27}
            )
            db.add(new_p)
            print(f"✅ Created Adhérent (Gym): {email}")
    
    # 6. Check if clinic local admin exists
    admin_kine = db.query(User).filter(User.email == "doc@kine-paris.fr").first()
    if not admin_kine:
        admin_kine = User(
            pseudo="Dr. Dupont",
            email="doc@kine-paris.fr",
            password_hash=get_password_hash("password123"),
            role="admin",
            establishment_id=est_kine.establishment_id
        )
        db.add(admin_kine)
        print(f"✅ Created Clinic Admin: {admin_kine.email}")
        
    # 7. Check if gym local admin exists
    admin_gym = db.query(User).filter(User.email == "coach@fitlife-paris.fr").first()
    if not admin_gym:
        admin_gym = User(
            pseudo="Coach Marc",
            email="coach@fitlife-paris.fr",
            password_hash=get_password_hash("password123"),
            role="admin",
            establishment_id=est_gym.establishment_id
        )
        db.add(admin_gym)
        print(f"✅ Created Gym Admin: {admin_gym.email}")
        
    db.commit()
    print("🚀 Seeding finished successfully.")
    db.close()

if __name__ == "__main__":
    seed_db()
