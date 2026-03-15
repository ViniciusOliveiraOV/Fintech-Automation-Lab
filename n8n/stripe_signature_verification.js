const crypto = require("crypto");

function getHeader(headers, name) {
  if (!headers || typeof headers !== "object") return undefined;
  const lower = name.toLowerCase();
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase() === lower) return headers[key];
  }
  return undefined;
}

function parseStripeSignature(headerValue) {
  const parts = String(headerValue)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  const parsed = { t: null, v1: [] };
  for (const part of parts) {
    const idx = part.indexOf("=");
    if (idx === -1) continue;
    const key = part.slice(0, idx);
    const value = part.slice(idx + 1);
    if (key === "t") parsed.t = value;
    if (key === "v1") parsed.v1.push(value);
  }

  return parsed;
}

function isSignatureValid(expectedHex, providedHexList) {
  const expected = Buffer.from(expectedHex, "hex");
  for (const providedHex of providedHexList) {
    const provided = Buffer.from(providedHex, "hex");
    if (provided.length !== expected.length) continue;
    if (crypto.timingSafeEqual(expected, provided)) return true;
  }
  return false;
}

const input = $input.first().json;
const signatureHeader = getHeader(input.headers, "stripe-signature");
if (!signatureHeader) {
  throw new Error("Missing Stripe-Signature header.");
}

const secret = process.env.STRIPE_WEBHOOK_SECRET;
if (!secret) {
  throw new Error("Missing STRIPE_WEBHOOK_SECRET environment variable in n8n container.");
}

// Requires Webhook node option: Raw Body = On
const rawBody =
  typeof input.rawBody === "string"
    ? input.rawBody
    : JSON.stringify(input.body ?? input);

const parsedSig = parseStripeSignature(signatureHeader);
if (!parsedSig.t || parsedSig.v1.length === 0) {
  throw new Error("Invalid Stripe-Signature header format.");
}

const timestamp = Number(parsedSig.t);
if (!Number.isFinite(timestamp)) {
  throw new Error("Stripe signature timestamp is invalid.");
}

// Reject stale payloads older than 5 minutes.
const toleranceSeconds = 300;
const ageSeconds = Math.abs(Math.floor(Date.now() / 1000) - timestamp);
if (ageSeconds > toleranceSeconds) {
  throw new Error("Stripe signature timestamp is outside tolerance window.");
}

const signedPayload = `${parsedSig.t}.${rawBody}`;
const expectedSignature = crypto
  .createHmac("sha256", secret)
  .update(signedPayload, "utf8")
  .digest("hex");

if (!isSignatureValid(expectedSignature, parsedSig.v1)) {
  throw new Error("Stripe signature validation failed.");
}

const event = input.body && typeof input.body === "object" ? input.body : JSON.parse(rawBody);

return [{ json: event }];
