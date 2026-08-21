// Stand-in for a real payment gateway (Stripe/Razorpay/etc). Deterministic
// and side-effect-free on purpose - real credentials/PCI-scope don't belong
// in a portfolio project. Swapping this for a real SDK call is the only
// change needed to go from "demo" to "real integration".
export async function chargeCard(amountCents: number): Promise<{ approved: boolean }> {
  // Simulate network latency of a real gateway call.
  await new Promise((r) => setTimeout(r, 50));
  // Fail ~2% of charges to make the FAILED path exercised in demos/tests.
  const approved = Math.random() > 0.02 && amountCents > 0;
  return { approved };
}
