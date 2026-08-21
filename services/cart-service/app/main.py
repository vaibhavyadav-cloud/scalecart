import logging
from fastapi import FastAPI
from pythonjsonlogger import jsonlogger
from prometheus_fastapi_instrumentator import Instrumentator
from app.routers import health, cart

# Structured JSON logging, same rationale as the Node/Go services -
# uniform log shape across every language in this platform so one Fluent
# Bit config / Grafana Loki query works for all of them.
handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
logging.basicConfig(level=logging.INFO, handlers=[handler])

app = FastAPI(title="ScaleCart Cart Service")

app.include_router(health.router)
app.include_router(cart.router)

# Exposes GET /metrics in Prometheus format automatically.
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
