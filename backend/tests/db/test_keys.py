import inspect

from app.db import keys


def test_every_key_starts_with_the_single_namespace_prefix():
    assert keys.refresh_token("abc").startswith("ST:")


def test_refresh_token_key_embeds_the_hash():
    assert keys.refresh_token("abc") == "ST:RT:abc"


def test_refresh_family_key_embeds_the_family_id():
    assert keys.refresh_family("fam_1") == "ST:RT_FAMILY:fam_1"


def test_revoked_refresh_key_is_distinct_from_the_live_key():
    assert keys.revoked_refresh("abc") != keys.refresh_token("abc")


def test_access_denylist_key_embeds_the_jti():
    assert keys.access_denylist("jti_1") == "ST:JWT_DENY:jti_1"


def test_user_sessions_key_embeds_the_user_id():
    assert keys.user_sessions("usr_1") == "ST:USER_SESSIONS:usr_1"


def test_rate_limit_key_separates_scope_from_identity():
    assert keys.rate_limit("signin", "1.2.3.0") == "ST:RL:signin:1.2.3.0"


def test_all_key_builders_are_functions_not_inline_strings():
    builders = [
        name
        for name, value in vars(keys).items()
        if inspect.isfunction(value) and not name.startswith("_")
    ]
    assert len(builders) >= 6


def test_all_key_builders_produce_the_namespace():
    for name, value in vars(keys).items():
        if not inspect.isfunction(value) or name.startswith("_"):
            continue
        args = ["x"] * len(inspect.signature(value).parameters)
        assert value(*args).startswith("ST:"), name
