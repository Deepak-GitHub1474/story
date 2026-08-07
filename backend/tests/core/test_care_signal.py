from app.core.care import sounds_at_risk


def test_plain_despair_is_not_treated_as_a_crisis():
    assert not sounds_at_risk("I miss her every single hour and I cannot sleep.")
    assert not sounds_at_risk("This year broke me and I am exhausted by all of it.")
    assert not sounds_at_risk("I am dying to see that film again.")


def test_saying_everyone_would_be_better_off_is_caught():
    assert sounds_at_risk("Since she died I think everyone would be better off without me.")


def test_not_wanting_to_wake_up_is_caught():
    assert sounds_at_risk("Most nights I hope I do not wake up in the morning.")


def test_wanting_to_end_it_is_caught():
    assert sounds_at_risk("I want to end my life and I have thought about how.")
    assert sounds_at_risk("some days i just want to kill myself")


def test_case_and_spacing_do_not_get_around_it():
    assert sounds_at_risk("EVERYONE   would  be BETTER off WITHOUT me")


def test_an_empty_story_is_not_a_crisis():
    assert not sounds_at_risk("")
