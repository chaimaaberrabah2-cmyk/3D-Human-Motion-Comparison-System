from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database.setup import get_db
from app.database.models import Performance, Movement, User, Establishment

router = APIRouter()


@router.get("/")
def get_performances(user_id: int, db: Session = Depends(get_db)):
    """Return all completed performances for a given user."""
    perfs = (
        db.query(Performance)
        .filter(Performance.user_id == user_id)
        .order_by(Performance.created_at.desc())
        .all()
    )

    result = []
    for p in perfs:
        movement_name = p.movement.name if p.movement else "Unknown"
        result.append({
            "performance_id": p.performance_id,
            "exercise": movement_name,
            "score": p.score,
            "duration": p.duration,
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "feedback": p.feedback_txt,
            "session_path": p.results_3d.get("session_path") if p.results_3d else None,
        })

    return result


@router.get("/progress")
def get_progress(user_id: int, exercise: Optional[str] = None, db: Session = Depends(get_db)):
    """
    Return time-series progress for a user.
    Optionally filter by exercise name.
    Returns list of {date, score, exercise} sorted oldest → newest.
    """
    query = (
        db.query(Performance)
        .filter(Performance.user_id == user_id)
        .order_by(Performance.created_at.asc())
    )
    if exercise:
        movement = db.query(Movement).filter(Movement.name == exercise).first()
        if movement:
            query = query.filter(Performance.movement_id == movement.movement_id)

    perfs = query.all()
    return [
        {
            "date": p.created_at.isoformat() if p.created_at else None,
            "score": p.score,
            "exercise": p.movement.name if p.movement else "Unknown",
        }
        for p in perfs
    ]


@router.get("/establishment/{establishment_id}/stats")
def get_establishment_stats(establishment_id: int, db: Session = Depends(get_db)):
    """
    Dashboard stats for a gym establishment.
    Returns total sessions, unique users, avg score, breakdown per exercise.
    """
    est = db.query(Establishment).filter(
        Establishment.establishment_id == establishment_id
    ).first()
    if not est:
        raise HTTPException(status_code=404, detail="Establishment not found")

    # All users belonging to this establishment
    user_ids = [u.user_id for u in db.query(User).filter(
        User.establishment_id == establishment_id
    ).all()]

    if not user_ids:
        return {
            "establishment_id": establishment_id,
            "establishment_name": est.name,
            "total_sessions": 0,
            "unique_users": 0,
            "avg_score": None,
            "by_exercise": [],
        }

    perfs = db.query(Performance).filter(Performance.user_id.in_(user_ids)).all()

    total_sessions = len(perfs)
    unique_users = len({p.user_id for p in perfs})
    scores = [p.score for p in perfs if p.score is not None]
    avg_score = round(sum(scores) / len(scores), 1) if scores else None

    # Group by exercise
    by_exercise: dict = {}
    for p in perfs:
        name = p.movement.name if p.movement else "Unknown"
        if name not in by_exercise:
            by_exercise[name] = {"exercise": name, "sessions": 0, "scores": []}
        by_exercise[name]["sessions"] += 1
        if p.score is not None:
            by_exercise[name]["scores"].append(p.score)

    breakdown = []
    for ex, data in by_exercise.items():
        ex_scores = data["scores"]
        breakdown.append({
            "exercise": ex,
            "sessions": data["sessions"],
            "avg_score": round(sum(ex_scores) / len(ex_scores), 1) if ex_scores else None,
        })
    breakdown.sort(key=lambda x: x["sessions"], reverse=True)

    return {
        "establishment_id": establishment_id,
        "establishment_name": est.name,
        "total_sessions": total_sessions,
        "unique_users": unique_users,
        "avg_score": avg_score,
        "by_exercise": breakdown,
    }
