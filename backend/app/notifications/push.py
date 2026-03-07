"""
Push notification helpers.

Supports two formats stored in user.push_token:
  - "ExponentPushToken[xxx]"  → Expo (legacy React Native)
  - '{"endpoint":...}'        → Web Push / VAPID (Flutter PWA)

VAPID keys are loaded from env vars VAPID_PRIVATE_PEM + VAPID_PUBLIC_KEY,
or auto-generated and saved to vapid_keys.json on first run (development).
After first run, copy the printed keys to environment variables for production.
"""
import json
import os
import urllib.request
from typing import Optional

# ── VAPID key management ───────────────────────────────────────────────────

_KEYS_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "vapid_keys.json",
)
_keys_cache: Optional[dict] = None


def _get_keys() -> dict:
    global _keys_cache
    if _keys_cache:
        return _keys_cache

    # 1. Prefer environment variables (production)
    env_pem = os.environ.get("VAPID_PRIVATE_PEM")
    env_pub = os.environ.get("VAPID_PUBLIC_KEY")
    if env_pem and env_pub:
        _keys_cache = {"private_pem": env_pem, "public_b64": env_pub}
        return _keys_cache

    # 2. Load from file (development)
    if os.path.exists(_KEYS_FILE):
        with open(_KEYS_FILE) as f:
            _keys_cache = json.load(f)
        return _keys_cache

    # 3. Generate new P-256 key pair (first run)
    try:
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.primitives.serialization import (
            Encoding, PrivateFormat, NoEncryption,
        )

        private_key = ec.generate_private_key(ec.SECP256R1())
        private_pem = private_key.private_bytes(
            Encoding.PEM, PrivateFormat.TraditionalOpenSSL, NoEncryption()
        ).decode()

        import base64
        pub = private_key.public_key().public_numbers()
        pub_bytes = b'\x04' + pub.x.to_bytes(32, 'big') + pub.y.to_bytes(32, 'big')
        pub_b64 = base64.urlsafe_b64encode(pub_bytes).decode().rstrip('=')

        _keys_cache = {"private_pem": private_pem, "public_b64": pub_b64}
        os.makedirs(os.path.dirname(_KEYS_FILE), exist_ok=True)
        with open(_KEYS_FILE, 'w') as f:
            json.dump(_keys_cache, f)

        print("=" * 60)
        print("VAPID keys generated. Copy to environment variables:")
        print(f"VAPID_PUBLIC_KEY={pub_b64}")
        print(f"VAPID_PRIVATE_PEM=<contents of vapid_keys.json>")
        print("=" * 60)
        return _keys_cache

    except Exception as e:
        print(f"VAPID key generation failed: {e}")
        return {}


def get_vapid_public_key() -> str:
    return _get_keys().get("public_b64", "")


# ── Push senders ───────────────────────────────────────────────────────────

def send_expo_push(push_token: str, title: str, body: str, data: dict = None) -> None:
    """Send an Expo push notification. Silently fails."""
    if not push_token or not push_token.startswith("ExponentPushToken["):
        return
    payload: dict = {"to": push_token, "sound": "default", "title": title, "body": body}
    if data:
        payload["data"] = data
    try:
        req = urllib.request.Request(
            "https://exp.host/--/exponent-push-notification/send",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass


def _send_webpush(subscription_json: str, title: str, body: str, url: str = "/") -> None:
    """Send a Web Push notification via VAPID."""
    try:
        from pywebpush import webpush, WebPushException
        keys = _get_keys()
        if not keys.get("private_pem"):
            return
        sub = json.loads(subscription_json)
        webpush(
            subscription_info=sub,
            data=json.dumps({"title": title, "body": body, "url": url}),
            vapid_private_key=keys["private_pem"],
            vapid_claims={"sub": "mailto:admin@familyplanner.app"},
        )
    except Exception as e:
        # 410 Gone = subscription expired — silently ignore
        status = getattr(getattr(e, 'response', None), 'status_code', None)
        if status != 410:
            print(f"WebPush error ({status or type(e).__name__}): {e}")


def send_push(push_token: str, title: str, body: str, url: str = "/") -> None:
    """
    Universal push sender. Handles both Expo tokens and Web Push subscriptions.
    Silently fails — safe to call anywhere.
    """
    if not push_token:
        return
    if push_token.startswith("ExponentPushToken["):
        send_expo_push(push_token, title, body)
    elif push_token.startswith("{"):
        _send_webpush(push_token, title, body, url)
