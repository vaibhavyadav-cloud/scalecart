import { formatPrice } from "./api";

describe("formatPrice", () => {
  it("formats cents as a currency string", () => {
    expect(formatPrice(1999, "USD")).toBe("$19.99");
  });

  it("handles zero", () => {
    expect(formatPrice(0, "USD")).toBe("$0.00");
  });
});
