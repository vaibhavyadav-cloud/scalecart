import express from "express";
import helmet from "helmet";
import pinoHttp from "pino-http";
import { logger } from "./logger";
import { healthRouter } from "./routes/health";
import { authRouter } from "./routes/auth";
import { errorHandler } from "./middleware/errorHandler";
import { httpRequestDuration } from "./metrics";

const app = express();
const PORT = process.env.PORT || 4001;

app.use(helmet());
app.use(express.json());
app.use(pinoHttp({ logger }));

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on("finish", () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

app.use(healthRouter);
app.use(authRouter);

app.use(errorHandler);

const server = app.listen(PORT, () => {
  logger.info(`auth-service listening on port ${PORT}`);
});

// Graceful shutdown: on SIGTERM (what k8s sends before killing a pod during
// a rollout or scale-down), stop accepting new connections and let
// in-flight requests finish before exiting. Paired with preStop hook +
// terminationGracePeriodSeconds in the Deployment manifest.
process.on("SIGTERM", () => {
  logger.info("SIGTERM received, shutting down gracefully");
  server.close(() => {
    logger.info("server closed");
    process.exit(0);
  });
});
