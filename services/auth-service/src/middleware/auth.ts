import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { ApiError } from "./errorHandler";

export interface AuthedRequest extends Request {
  user?: { id: string; email: string; role: string };
}

const JWT_SECRET = process.env.JWT_SECRET || "dev-secret-change-me";

// Verifies the bearer token issued by POST /auth/login.
// Other services (order-service, payment-service) verify the same JWT
// independently using the shared JWT_SECRET / public key - no central
// session store, which is what lets each service scale statelessly.
export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return next(new ApiError(401, "missing_bearer_token"));
  }
  try {
    const token = header.slice("Bearer ".length);
    const payload = jwt.verify(token, JWT_SECRET) as AuthedRequest["user"];
    req.user = payload;
    next();
  } catch {
    next(new ApiError(401, "invalid_token"));
  }
}
