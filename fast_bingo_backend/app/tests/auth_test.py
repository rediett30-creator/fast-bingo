import hmac, hashlib, time, json, urllib.parse
import httpx

BOT_TOKEN = "YOUR_TELEGRAM_BOT_TOKEN"  
BACKEND_URL = "http://localhost:8000"

def fake_init_data(telegram_id: int, first_name: str, username: str) -> str:
    user = {"id": telegram_id, "first_name": first_name, "username": username}
    fields = {"user": json.dumps(user), "auth_date": str(int(time.time()))}
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(fields.items()))
    secret_key = hmac.new(b"WebAppData", BOT_TOKEN.encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()
    return urllib.parse.urlencode(fields)

if __name__ == "__main__":
    init_data = fake_init_data(123456789, "Miko", "miko_dev")
    resp = httpx.post(f"{BACKEND_URL}/auth/telegram", json={"init_data": init_data})
    print(resp.status_code, resp.json())