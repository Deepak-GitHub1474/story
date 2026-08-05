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

    counts = {"community_categories": len(CATEGORIES), "interests": len(INTERESTS)}
    logger.info("seed_complete", count=sum(counts.values()))
    return counts
