"""
Push notification helpers.

Supports two formats stored in user.push_token:
  - "ExponentPushToken[xxx]"  → Expo (legacy React Native)
  - '{"endpoint":...}'        → Web Push / VAPID (Flutter PWA)

VAPID keys are loaded from env vars:
  VAPID_PRIVATE_KEY  — base64url-encoded raw 32-byte EC private key (recommended)
  VAPID_PUBLIC_KEY   — base64url-encoded uncompressed public key (65 bytes, starts with 04)

Or auto-generated and saved to vapid_keys.json on first run (development only).
After first run, copy the printed VAPID_PRIVATE_KEY + VAPID_PUBLIC_KEY to Railway Variables.
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

    env_pub = os.environ.get("VAPID_PUBLIC_KEY", "").strip()

    # 1. Preferred format: VAPID_PRIVATE_KEY = base64url raw key (single line, no headers)
    env_key = os.environ.get("VAPID_PRIVATE_KEY", "").strip()
    if env_key and env_pub:
        _keys_cache = {"private_key": env_key, "public_b64": env_pub}
        return _keys_cache

    # 2. Legacy: VAPID_PRIVATE_PEM (multiline PEM — kept for backward compat)
    env_pem = os.environ.get("VAPID_PRIVATE_PEM", "")
    if env_pem and env_pub:
        # Convert any escaped \n back to real newlines (Railway may escape them)
        env_pem = env_pem.replace('\\n', '\n').strip()
        _keys_cache = {"private_key": env_pem, "public_b64": env_pub}
        return _keys_cache

    # 3. Load from file (development)
    if os.path.exists(_KEYS_FILE):
        with open(_KEYS_FILE) as f:
            _keys_cache = json.load(f)
        return _keys_cache

    # 4. Generate new P-256 key pair (first run — development only)
    try:
        import base64
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.backends import default_backend

        private_key = ec.generate_private_key(ec.SECP256R1(), default_backend())

        # Private key: raw 32-byte scalar → base64url (what py_vapid from_raw() expects)
        d = private_key.private_numbers().private_value
        priv_b64 = base64.urlsafe_b64encode(d.to_bytes(32, 'big')).decode().rstrip('=')

        # Public key: uncompressed 65 bytes (04 || x || y) → base64url
        pub_nums = private_key.public_key().public_numbers()
        pub_bytes = b'\x04' + pub_nums.x.to_bytes(32, 'big') + pub_nums.y.to_bytes(32, 'big')
        pub_b64 = base64.urlsafe_b64encode(pub_bytes).decode().rstrip('=')

        _keys_cache = {"private_key": priv_b64, "public_b64": pub_b64}
        os.makedirs(os.path.dirname(_KEYS_FILE) or ".", exist_ok=True)
        with open(_KEYS_FILE, 'w') as f:
            json.dump(_keys_cache, f)

        print(f"\n{'='*60}")
        print("VAPID keys generated! Set these in Railway Variables:")
        print(f"VAPID_PRIVATE_KEY={priv_b64}")
        print(f"VAPID_PUBLIC_KEY={pub_b64}")
        print('=' * 60 + '\n')
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
        private_key = keys.get("private_key")
        if not private_key:
            return
        sub = json.loads(subscription_json)
        webpush(
            subscription_info=sub,
            data=json.dumps({"title": title, "body": body, "url": url}),
            vapid_private_key=private_key,
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
