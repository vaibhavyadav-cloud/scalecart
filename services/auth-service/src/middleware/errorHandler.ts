import { NextFunction, Request, Response } from "express";
import { logger } from "../logger";

export class ApiError extends Error {
  constructor(public statusCode: number, message: string) {
    super(message);
  }
}

// Centralized error handler - every route forwards errors here via next(err)
// instead of hand-rolling try/catch responses, so the JSON error shape is
// consistent for every consumer of this API.
export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({ error: err.message });
  }
  logger.error({ err, path: req.path }, "unhandled error");
  return res.status(500).json({ error: "internal_server_error" });
}
