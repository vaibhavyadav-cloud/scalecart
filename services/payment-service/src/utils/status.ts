// Pure mapping, factored out so it's testable without a DB/Kafka connection.
export function paymentStatusFor(approved: boolean): "CAPTURED" | "FAILED" {
  return approved ? "CAPTURED" : "FAILED";
}

export function paymentTopicFor(approved: boolean): "payment.completed" | "payment.failed" {
  return approved ? "payment.completed" : "payment.failed";
}
