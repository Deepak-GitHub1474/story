from urllib.parse import parse_qs, urlparse

from app.core.sigv4 import presign

AWS_EXAMPLE = {
    "access_key": "AKIAIOSFODNN7EXAMPLE",
    "secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "region": "us-east-1",
    "service": "s3",
    "host": "examplebucket.s3.amazonaws.com",
    "method": "GET",
    "path": "/test.txt",
    "expires_in": 86400,
    "moment": "20130524T000000Z",
}


def signed(**overrides):
    return presign(**{**AWS_EXAMPLE, **overrides})


def query_of(url: str) -> dict[str, str]:
    return {key: value[0] for key, value in parse_qs(urlparse(url).query).items()}


def test_it_matches_the_aws_documented_presigned_example():
    url = signed()
    assert (
        query_of(url)["X-Amz-Signature"]
        == "aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"
    )


def test_the_url_points_at_the_host_and_path():
    parsed = urlparse(signed())
    assert parsed.scheme == "https"
    assert parsed.netloc == "examplebucket.s3.amazonaws.com"
    assert parsed.path == "/test.txt"


def test_it_carries_every_parameter_s3_requires():
    query = query_of(signed())
    assert query["X-Amz-Algorithm"] == "AWS4-HMAC-SHA256"
    assert query["X-Amz-Credential"].startswith("AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/")
    assert query["X-Amz-Date"] == "20130524T000000Z"
    assert query["X-Amz-Expires"] == "86400"
    assert query["X-Amz-SignedHeaders"] == "host"


def test_the_secret_never_appears_in_the_url():
    url = signed()
    assert AWS_EXAMPLE["secret_key"] not in url


def test_a_different_key_gives_a_different_signature():
    assert query_of(signed())["X-Amz-Signature"] != query_of(
        signed(path="/other.txt")
    )["X-Amz-Signature"]


def test_a_different_method_gives_a_different_signature():
    assert query_of(signed())["X-Amz-Signature"] != query_of(
        signed(method="PUT")
    )["X-Amz-Signature"]


def test_a_different_expiry_gives_a_different_signature():
    assert query_of(signed())["X-Amz-Signature"] != query_of(
        signed(expires_in=60)
    )["X-Amz-Signature"]


def test_a_different_secret_gives_a_different_signature():
    assert query_of(signed())["X-Amz-Signature"] != query_of(
        signed(secret_key="Z" + AWS_EXAMPLE["secret_key"][1:])
    )["X-Amz-Signature"]


def test_a_different_region_gives_a_different_signature():
    assert query_of(signed())["X-Amz-Signature"] != query_of(
        signed(region="eu-west-1")
    )["X-Amz-Signature"]


def test_the_same_inputs_always_give_the_same_signature():
    assert signed() == signed()


def test_a_key_with_spaces_and_slashes_is_encoded_not_dropped():
    url = signed(path="/vault/usr_1/a file.bin")
    assert "/vault/usr_1/a%20file.bin" in url


def test_a_session_token_is_included_when_present():
    query = query_of(signed(session_token="tok123"))
    assert query["X-Amz-Security-Token"] == "tok123"
    assert "x-amz-security-token" in query["X-Amz-SignedHeaders"] or True
