import hashlib
import hmac
from datetime import UTC, datetime
from urllib.parse import quote

ALGORITHM = "AWS4-HMAC-SHA256"
UNSIGNED_PAYLOAD = "UNSIGNED-PAYLOAD"


def _quote_path(path: str) -> str:
    return quote(path, safe="/~")


def _quote_param(value: str) -> str:
    return quote(str(value), safe="~")


def _sign(key: bytes, message: str) -> bytes:
    return hmac.new(key, message.encode(), hashlib.sha256).digest()


def _signing_key(secret_key: str, stamp: str, region: str, service: str) -> bytes:
    key = _sign(f"AWS4{secret_key}".encode(), stamp)
    key = _sign(key, region)
    key = _sign(key, service)
    return _sign(key, "aws4_request")


def presign(
    *,
    access_key: str,
    secret_key: str,
    region: str,
    service: str,
    host: str,
    method: str,
    path: str,
    expires_in: int,
    moment: str | None = None,
    session_token: str | None = None,
    scheme: str = "https",
    extra_params: dict[str, str] | None = None,
) -> str:
    timestamp = moment or datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    stamp = timestamp[:8]
    scope = f"{stamp}/{region}/{service}/aws4_request"

    params = {
        "X-Amz-Algorithm": ALGORITHM,
        "X-Amz-Credential": f"{access_key}/{scope}",
        "X-Amz-Date": timestamp,
        "X-Amz-Expires": str(expires_in),
        "X-Amz-SignedHeaders": "host",
    }
    if session_token:
        params["X-Amz-Security-Token"] = session_token
    if extra_params:
        params.update(extra_params)

    canonical_query = "&".join(
        f"{_quote_param(key)}={_quote_param(params[key])}" for key in sorted(params)
    )
    canonical_request = "\n".join(
        [
            method,
            _quote_path(path),
            canonical_query,
            f"host:{host}\n",
            "host",
            UNSIGNED_PAYLOAD,
        ]
    )
    string_to_sign = "\n".join(
        [
            ALGORITHM,
            timestamp,
            scope,
            hashlib.sha256(canonical_request.encode()).hexdigest(),
        ]
    )
    signature = hmac.new(
        _signing_key(secret_key, stamp, region, service),
        string_to_sign.encode(),
        hashlib.sha256,
    ).hexdigest()

    return f"{scheme}://{host}{_quote_path(path)}?{canonical_query}&X-Amz-Signature={signature}"
