import { paymentStatusFor, paymentTopicFor } from "./status";

describe("payment status mapping", () => {
  it("maps approved -> CAPTURED / payment.completed", () => {
    expect(paymentStatusFor(true)).toBe("CAPTURED");
    expect(paymentTopicFor(true)).toBe("payment.completed");
  });

  it("maps declined -> FAILED / payment.failed", () => {
    expect(paymentStatusFor(false)).toBe("FAILED");
    expect(paymentTopicFor(false)).toBe("payment.failed");
  });
});
