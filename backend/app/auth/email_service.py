import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def _build_html(code: str, action: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<body style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;background:#fefdfc;padding:40px 20px;margin:0;">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:14px;border:1px solid #e5e0da;overflow:hidden;">
    <div style="background:#e44232;padding:28px 24px;text-align:center;">
      <div style="font-size:36px;">&#10084;&#65039;</div>
      <h1 style="color:#fff;margin:8px 0 0;font-size:22px;font-weight:700;letter-spacing:-0.3px;">Family Planner</h1>
    </div>
    <div style="padding:32px 28px;">
      <p style="color:#25221e;font-size:16px;margin:0 0 6px;font-weight:600;">Bonjour,</p>
      <p style="color:#4a4642;font-size:15px;margin:0 0 28px;line-height:1.5;">
        Voici votre code pour <strong>{action}</strong>&nbsp;:
      </p>
      <div style="background:#fff6f0;border:2px dashed #e44232;border-radius:12px;padding:28px 16px;text-align:center;margin:0 0 28px;">
        <span style="font-size:40px;font-weight:800;letter-spacing:12px;color:#e44232;font-variant-numeric:tabular-nums;">{code}</span>
      </div>
      <p style="color:#7d7977;font-size:13px;margin:0;line-height:1.6;">
        Ce code expire dans <strong>15 minutes</strong>.<br>
        Si vous n&apos;&ecirc;tes pas &agrave; l&apos;origine de cette demande, ignorez simplement cet email.
      </p>
    </div>
    <div style="background:#f9f7f6;border-top:1px solid #e5e0da;padding:16px 28px;text-align:center;">
      <p style="color:#97938c;font-size:12px;margin:0;">Family Planner &mdash; Organisez votre famille avec soin</p>
    </div>
  </div>
</body>
</html>"""


def send_verification_email(to_email: str, code: str, purpose: str) -> bool:
    """Send a 6-digit verification code via Brevo SMTP relay (free, 300/day).

    Required env vars on Railway:
      BREVO_SMTP_USER  -- your Brevo account email
      BREVO_SMTP_KEY   -- Brevo SMTP key (Settings > SMTP & API > SMTP tab)
      BREVO_FROM_NAME  -- optional display name (default: Family Planner)
    """
    SMTP_USER = os.getenv("BREVO_SMTP_USER", "")
    SMTP_KEY = os.getenv("BREVO_SMTP_KEY", "")

    print(f"[EMAIL DEBUG] BREVO_SMTP_USER={'SET(' + SMTP_USER[:6] + '...)' if SMTP_USER else 'MISSING'}, "
          f"BREVO_SMTP_KEY={'SET(' + str(len(SMTP_KEY)) + ' chars)' if SMTP_KEY else 'MISSING'}", flush=True)

    if not SMTP_USER or not SMTP_KEY:
        print(f"[EMAIL SKIP -- set BREVO_SMTP_USER + BREVO_SMTP_KEY] Code for {to_email} ({purpose}): {code}", flush=True)
        return True

    FROM_NAME = os.getenv("BREVO_FROM_NAME", "Family Planner")

    if purpose == "password_reset":
        subject = "Reinitialisation de votre mot de passe"
        action = "reinitialiser votre mot de passe"
    else:
        subject = "Verification de votre nouvelle adresse email"
        action = "verifier votre nouvelle adresse email"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{FROM_NAME} <{SMTP_USER}>"
    msg["To"] = to_email
    msg.attach(MIMEText(_build_html(code, action), "html"))

    try:
        with smtplib.SMTP("smtp-relay.brevo.com", 587, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(SMTP_USER, SMTP_KEY)
            server.sendmail(SMTP_USER, to_email, msg.as_string())
        print(f"[EMAIL OK] Sent {purpose} code to {to_email}", flush=True)
        return True
    except Exception as e:
        print(f"[EMAIL ERROR] {type(e).__name__}: {e}", flush=True)
        return False
