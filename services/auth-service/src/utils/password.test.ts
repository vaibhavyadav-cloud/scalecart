import { isStrongPassword } from "./password";

describe("isStrongPassword", () => {
  it("rejects passwords shorter than 8 chars", () => {
    expect(isStrongPassword("ab1")).toBe(false);
  });

  it("rejects passwords with no digit", () => {
    expect(isStrongPassword("abcdefgh")).toBe(false);
  });

  it("accepts a valid password", () => {
    expect(isStrongPassword("abcd1234")).toBe(true);
  });
});
