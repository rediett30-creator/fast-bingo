import hashlib
import hmac
import json
import time
from urllib.parse import parse_qsl

class InitDataValidationError(Exception):
    pass

def validate_init_data(init_data: str, bot_token: str, max_age_seconds: int = 86400) -> dict:
    parsed = dict(parse_qsl(init_data, strict_parsing=True))
    received_hash = parsed.pop("hash", None)
    if not received_hash:
        raise InitDataValidationError("Missing hash")

    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(parsed.items()))

    secret_key = hmac.new(b"WebAppData", bot_token.encode(), hashlib.sha256).digest()
    computed_hash = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()

    if not hmac.compare_digest(computed_hash, received_hash):
        raise InitDataValidationError("Invalid hash")

    if time.time() - int(parsed.get("auth_date", 0)) > max_age_seconds:
        raise InitDataValidationError("Stale init data")

    return parsed  