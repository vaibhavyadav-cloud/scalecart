// Pure helper kept separate from bcrypt so it's unit-testable without
// spinning up a database - CI runs this in the "test" step, before the
// image is even built. See docs/11-github-actions-cicd.md.
export function isStrongPassword(password: string): boolean {
  const hasMinLength = password.length >= 8;
  const hasNumber = /\d/.test(password);
  const hasLetter = /[a-zA-Z]/.test(password);
  return hasMinLength && hasNumber && hasLetter;
}
