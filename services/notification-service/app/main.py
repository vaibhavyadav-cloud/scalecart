import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator
from pythonjsonlogger import jsonlogger

from app.consumer import consume_forever
from app.redis_client import get_redis

handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
logging.basicConfig(level=logging.INFO, handlers=[handler])


@asynccontextmanager
async def lifespan(app: FastAPI):
    # The Kafka consumer runs as a background asyncio task alongside the
    # HTTP server in the same process/pod - this service has no meaningful
    # HTTP API of its own, /health/* exists purely so k8s can probe it.
    task = asyncio.create_task(consume_forever())
    yield
    task.cancel()


app = FastAPI(title="ScaleCart Notification Service", lifespan=lifespan)


@app.get("/health/live")
def live():
    return {"status": "ok"}


@app.get("/health/ready")
def ready():
    try:
        get_redis().ping()
        return {"status": "ready"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "not_ready"})


Instrumentator().instrument(app).expose(app, endpoint="/metrics")
