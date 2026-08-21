from fastapi import APIRouter, Depends, Response
from redis import Redis
from app.redis_client import get_redis

router = APIRouter()


# Liveness never touches Redis - only checks the process itself is running.
@router.get("/health/live")
def live():
    return {"status": "ok"}


# Readiness pings Redis; k8s pulls the pod out of Service endpoints (but
# does not restart it) until this passes again.
@router.get("/health/ready")
def ready(response: Response, r: Redis = Depends(get_redis)):
    try:
        r.ping()
        return {"status": "ready"}
    except Exception:
        response.status_code = 503
        return {"status": "not_ready"}
