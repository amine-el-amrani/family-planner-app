import json
import urllib.request


def send_expo_push(push_token: str, title: str, body: str, data: dict = None) -> None:
    """Send an Expo push notification. Silently fails — never raises."""
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
