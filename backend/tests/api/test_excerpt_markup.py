import pytest

from app.api.endpoints.stories.utils import build_excerpt, strip_markup


@pytest.fixture(autouse=True)
def clean_state():
    yield


def test_a_bold_turn_reads_as_plain_words():
    assert strip_markup("**The day I left**") == "The day I left"


def test_an_italic_memory_keeps_its_words():
    assert strip_markup("she said *come home* once") == "she said come home once"


def test_a_list_loses_only_its_dashes():
    assert strip_markup("- a coat\n- the keys") == "a coat\nthe keys"


def test_the_card_never_shows_an_asterisk():
    body = "**Leaving**\n\nI packed:\n- a coat\n- *her letter*\n\nThen I went."
    excerpt = build_excerpt(body)
    assert "*" not in excerpt
    assert "Leaving" in excerpt
    assert "her letter" in excerpt


def test_plain_writing_is_untouched():
    body = "I left at nineteen. Nobody stopped me."
    assert build_excerpt(body) == body
