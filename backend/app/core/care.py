import re

WHITESPACE = re.compile(r"\s+")

PHRASES = (
    "better off without me",
    "better off if i was gone",
    "better off if i were gone",
    "do not wake up",
    "dont wake up",
    "not wake up",
    "end my life",
    "kill myself",
    "killing myself",
    "take my own life",
    "want to die",
    "wish i was dead",
    "wish i were dead",
    "no reason to live",
    "nothing left to live for",
    "cannot go on any more",
    "cannot go on anymore",
    "goodbye everyone",
)


def sounds_at_risk(body: str) -> bool:
    if not body:
        return False

    flattened = WHITESPACE.sub(" ", body.lower())
    return any(phrase in flattened for phrase in PHRASES)
