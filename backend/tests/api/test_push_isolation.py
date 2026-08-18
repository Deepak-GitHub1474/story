from app.config import get_settings
from app.ports.factory import build_push


def test_the_suite_can_never_send_a_real_push():
    push = build_push(get_settings())

    assert push.is_available is False, (
        "a developer .env with PUSH_PROVIDER=fcm must not make the suite "
        f"fire real notifications at Google, but it built {type(push).__name__}"
    )
