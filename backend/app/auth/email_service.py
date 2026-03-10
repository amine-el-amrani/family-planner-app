import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def send_verification_email(to_email: str, code: str, purpose: str) -> bool:
    """Send a 6-digit verification code by email via Gmail SMTP."""
    GMAIL_USER = os.getenv("GMAIL_USER", "")
    GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD", "")
    if not GMAIL_USER or not GMAIL_APP_PASSWORD:
        # Dev fallback: print the code so you can test without SMTP configured
        print(f"[EMAIL SKIP] Code for {to_email} ({purpose}): {code}")
        return True

    if purpose == "password_reset":
        subject = "Réinitialisation de votre mot de passe"
        action = "réinitialiser votre mot de passe"
    else:
        subject = "Vérification de votre nouvelle adresse email"
        action = "vérifier votre nouvelle adresse email"

    html = f"""<!DOCTYPE html>
<html>
<body style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;background:#fefdfc;padding:40px 20px;margin:0;">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:14px;border:1px solid #e5e0da;overflow:hidden;">
    <div style="background:#e44232;padding:28px 24px;text-align:center;">
      <div style="font-size:36px;">❤️</div>
      <h1 style="color:#fff;margin:8px 0 0;font-size:22px;font-weight:700;letter-spacing:-0.3px;">Family Planner</h1>
    </div>
    <div style="padding:32px 28px;">
      <p style="color:#25221e;font-size:16px;margin:0 0 6px;font-weight:600;">Bonjour,</p>
      <p style="color:#4a4642;font-size:15px;margin:0 0 28px;line-height:1.5;">
        Voici votre code pour <strong>{action}</strong> :
      </p>
      <div style="background:#fff6f0;border:2px dashed #e44232;border-radius:12px;padding:28px 16px;text-align:center;margin:0 0 28px;">
        <span style="font-size:40px;font-weight:800;letter-spacing:12px;color:#e44232;font-variant-numeric:tabular-nums;">{code}</span>
      </div>
      <p style="color:#7d7977;font-size:13px;margin:0;line-height:1.6;">
        Ce code expire dans <strong>15 minutes</strong>.<br>
        Si vous n&apos;êtes pas à l&apos;origine de cette demande, ignorez simplement cet email.
      </p>
    </div>
    <div style="background:#f9f7f6;border-top:1px solid #e5e0da;padding:16px 28px;text-align:center;">
      <p style="color:#97938c;font-size:12px;margin:0;">Family Planner — Organisez votre famille avec soin</p>
    </div>
  </div>
</body>
</html>"""

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"Family Planner <{GMAIL_USER}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_APP_PASSWORD)
            server.sendmail(GMAIL_USER, to_email, msg.as_string())
        print(f"[EMAIL OK] Sent {purpose} code to {to_email}")
        return True
    except Exception as e:
        print(f"[EMAIL ERROR] {e}")
        return False
