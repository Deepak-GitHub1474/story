from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.time import utc_now
from app.logging import get_logger

logger = get_logger("story.db.seed")

CATEGORIES = [
    ("grief", "Grief", "reflective", "Bereavement, loss, anniversaries.", 10),
    ("heartbreak", "Heartbreak", "reflective", "Breakups, divorce, endings.", 20),
    ("sacrifice", "Sacrifice", "reflective", "Duty, obligation, the road not taken.", 30),
    ("loneliness", "Loneliness", "reflective", "Being unseen, quiet company.", 40),
    ("mental-health", "Mental health", "supportive", "Anxiety, burnout, low periods.", 50),
    ("health", "Health", "supportive", "Chronic illness, diagnosis, recovery.", 60),
    ("caregiving", "Caregiving", "supportive", "Looking after someone, and its cost.", 70),
    ("family", "Family", "supportive", "Parents, estrangement, parenting.", 80),
    ("identity", "Identity", "supportive", "Belonging, faith, culture, migration.", 90),
    ("work", "Work", "practical", "Burnout, managers, workplace decisions.", 100),
    ("job-search", "Job search", "practical", "Layoffs, interviews, offers, gaps.", 110),
    ("money", "Money", "practical", "Debt, financial shame, first salary.", 120),
    ("study", "Study", "practical", "Exams, courses, first year away.", 130),
    ("starting-over", "Starting over", "open", "Ready for something new.", 140),
    ("everyday", "Everyday", "open", "Small wins and ordinary days.", 150),
]

INTERESTS = [
    ("grief", "Losing a parent", "grief"),
    ("bereavement", "Bereavement", "grief"),
    ("anniversaries", "Hard anniversaries", "grief"),
    ("breakups", "Breakups", "heartbreak"),
    ("divorce", "Divorce", "heartbreak"),
    ("unrequited", "Unrequited", "heartbreak"),
    ("duty", "Family duty", "sacrifice"),
    ("given-up-dreams", "Dreams given up", "sacrifice"),
    ("loneliness", "Feeling unseen", "loneliness"),
    ("quiet-company", "Quiet company", "loneliness"),
    ("anxiety", "Anxiety", "mental-health"),
    ("burnout", "Burnout", "mental-health"),
    ("low-periods", "Low periods", "mental-health"),
    ("chronic-illness", "Chronic illness", "health"),
    ("recovery", "Recovery", "health"),
    ("caring-for-a-parent", "Caring for a parent", "caregiving"),
    ("carer-burnout", "Carer burnout", "caregiving"),
    ("estrangement", "Estrangement", "family"),
    ("parenting", "Parenting", "family"),
    ("belonging", "Belonging", "identity"),
    ("migration", "Migration", "identity"),
    ("hostile-manager", "Hostile manager", "work"),
    ("imposter-syndrome", "Imposter syndrome", "work"),
    ("career-regret", "Career regret", "work"),
    ("layoffs", "Layoffs", "job-search"),
    ("interviews", "Interviews", "job-search"),
    ("employment-gaps", "Employment gaps", "job-search"),
    ("debt", "Debt", "money"),
    ("supporting-family", "Supporting family", "money"),
    ("exam-pressure", "Exam pressure", "study"),
    ("first-year-away", "First year away", "study"),
    ("ready-again", "Ready again", "starting-over"),
    ("after-a-long-time", "After a long time", "starting-over"),
    ("small-wins", "Small wins", "everyday"),
    ("gratitude", "Gratitude", "everyday"),
]


COMMUNITIES = [
    ("quiet-grief", "Quiet Grief", "grief", "For the loss you carry without saying."),
    ("first-year-without", "The First Year", "grief", "Anniversaries, empty chairs, firsts."),
    ("after-the-ending", "After The Ending", "heartbreak", "Breakups and what follows."),
    ("still-not-over-it", "Still Not Over It", "heartbreak", "Old heartbreak that has not left."),
    ("the-road-not-taken", "The Road Not Taken", "sacrifice", "What you gave up, and for whom."),
    ("duty-first", "Duty First", "sacrifice", "Family obligation and its cost."),
    ("unseen", "Unseen", "loneliness", "Not in crisis. Just unnoticed."),
    ("quiet-company", "Quiet Company", "loneliness", "Low-stakes company for quiet days."),
    ("running-on-empty", "Running On Empty", "mental-health", "Burnout, anxiety, flat days."),
    ("bad-brain-days", "Bad Brain Days", "mental-health", "Peer support, never advice."),
    ("long-haul", "Long Haul", "health", "Chronic illness and living around it."),
    ("the-diagnosis", "The Diagnosis", "health", "The week everything changed."),
    ("carer-hours", "Carer Hours", "caregiving", "Looking after someone, honestly."),
    ("invisible-work", "Invisible Work", "caregiving", "The labour nobody counts."),
    ("complicated-parents", "Complicated Parents", "family", "Parents, distance, estrangement."),
    ("raising-them", "Raising Them", "family", "Parenting, unedited."),
    ("between-places", "Between Places", "identity", "Migration, belonging, neither-here."),
    ("becoming", "Becoming", "identity", "Faith, coming out, changing shape."),
    ("bad-manager", "Bad Manager", "work", "The one making work unbearable."),
    ("imposter-hours", "Imposter Hours", "work", "Senior enough that saying it is risky."),
    ("nine-month-gap", "The Nine Month Gap", "job-search", "Explaining a gap, honestly."),
    ("offer-or-not", "Offer Or Not", "job-search", "Numbers, offers, and walking away."),
    ("after-the-layoff", "After The Layoff", "job-search", "The week after, and the month after."),
    ("quiet-debt", "Quiet Debt", "money", "Money you cannot talk about."),
    ("first-salary", "First Salary", "money", "Earning, sending home, and guilt."),
    ("exam-season", "Exam Season", "study", "Pressure, failure, and recovery."),
    ("first-year-away", "First Year Away", "study", "Homesick and pretending otherwise."),
    ("ready-again", "Ready Again", "starting-over", "Wanting something new, out loud."),
    (
        "second-first-date",
        "Second First Date",
        "starting-over",
        "Beginning again, after a long time.",
    ),
    ("small-wins", "Small Wins", "everyday", "Ordinary days worth saying out loud."),
    ("still-here", "Still Here", "everyday", "Gratitude without performance."),
]


async def seed_reference_data(db: AsyncIOMotorDatabase) -> dict[str, int]:
    now = utc_now()

    for slug, name, tone, description, sort_order in CATEGORIES:
        await db["community_categories"].update_one(
            {"_id": slug},
            {
                "$set": {
                    "name": name,
                    "tone": tone,
                    "description": description,
                    "sort_order": sort_order,
                    "status": "active",
                    "icon": slug,
                    "accent_token": "accent",
                    "updated_at": now,
                },
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )

    for slug, name, category_id in INTERESTS:
        await db["interests"].update_one(
            {"_id": slug},
            {
                "$set": {"name": name, "category_id": category_id, "updated_at": now},
                "$setOnInsert": {"created_at": now, "embedding": None},
            },
            upsert=True,
        )

    for slug, name, category_id, description in COMMUNITIES:
        await db["communities"].update_one(
            {"_id": slug},
            {
                "$set": {
                    "slug": slug,
                    "name": name,
                    "category_id": category_id,
                    "description": description,
                    "icon": category_id,
                    "accent_token": "accent",
                    "is_curated": True,
                    "status": "active",
                    "updated_at": now,
                },
                "$setOnInsert": {
                    "created_at": now,
                    "counts": {"members": 0, "stories": 0},
                    "rules": [],
                    "interests": [],
                    "member_directory": False,
                },
            },
            upsert=True,
        )

    counts = {
        "community_categories": len(CATEGORIES),
        "interests": len(INTERESTS),
        "communities": len(COMMUNITIES),
    }
    logger.info("seed_complete", count=sum(counts.values()))
    return counts
