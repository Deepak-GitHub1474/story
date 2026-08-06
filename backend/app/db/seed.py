from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.time import utc_now
from app.logging import get_logger

logger = get_logger("story.db.seed")

CATEGORIES = [
    ("joy", "Joy", "joyful", "Laughing until it hurts. Good days out loud.", 10),
    ("love", "Love", "joyful", "Falling, staying, being chosen.", 20),
    ("friendship", "Friendship", "joyful", "The people who show up.", 30),
    ("wins", "Wins", "joyful", "Something went right and you want to say it.", 40),
    ("beginnings", "Beginnings", "joyful", "First days, new cities, second chances.", 50),
    ("everyday", "Everyday", "joyful", "Small wins and ordinary good days.", 60),
    ("wonder", "Wonder", "open", "Travel, music, food, being surprised.", 70),
    ("starting-over", "Starting Over", "open", "Ready for something new.", 80),
    ("making", "Making", "open", "Building, writing, playing, creating.", 90),
    ("work", "Work", "practical", "Careers, managers, workplace decisions.", 100),
    ("job-search", "Job search", "practical", "Layoffs, interviews, offers, gaps.", 110),
    ("money", "Money", "practical", "Debt, first salary, sending money home.", 120),
    ("study", "Study", "practical", "Exams, courses, first year away.", 130),
    ("family", "Family", "supportive", "Parents, parenting, chosen family.", 140),
    ("identity", "Identity", "supportive", "Belonging, faith, culture, migration.", 150),
    ("health", "Health", "supportive", "Chronic illness, diagnosis, recovery.", 160),
    ("mental-health", "Mental health", "supportive", "Anxiety, burnout, low periods.", 170),
    ("caregiving", "Caregiving", "supportive", "Looking after someone, and its cost.", 180),
    ("loneliness", "Loneliness", "reflective", "Being unseen, quiet company.", 190),
    ("heartbreak", "Heartbreak", "reflective", "Breakups, divorce, endings.", 200),
    ("sacrifice", "Sacrifice", "reflective", "Duty, obligation, the road not taken.", 210),
    ("grief", "Grief", "reflective", "Bereavement, loss, anniversaries.", 220),
]

INTERESTS = [
    ("laughing-again", "Laughing again", "joy"),
    ("good-days", "Good days", "joy"),
    ("celebrations", "Celebrations", "joy"),
    ("falling-in-love", "Falling in love", "love"),
    ("staying-in-love", "Staying in love", "love"),
    ("open-to-someone", "Open to someone new", "love"),
    ("old-friends", "Old friends", "friendship"),
    ("new-friends", "Making friends", "friendship"),
    ("chosen-people", "The people who show up", "friendship"),
    ("small-wins", "Small wins", "wins"),
    ("proud-of-myself", "Proud of myself", "wins"),
    ("finally-happened", "It finally happened", "wins"),
    ("first-days", "First days", "beginnings"),
    ("new-city", "A new city", "beginnings"),
    ("second-chances", "Second chances", "beginnings"),
    ("gratitude", "Gratitude", "everyday"),
    ("ordinary-good", "Ordinary good days", "everyday"),
    ("travel", "Travel", "wonder"),
    ("music", "Music", "wonder"),
    ("food", "Food", "wonder"),
    ("ready-again", "Ready again", "starting-over"),
    ("after-a-long-time", "After a long time", "starting-over"),
    ("building-something", "Building something", "making"),
    ("writing", "Writing", "making"),
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
    ("parenting", "Parenting", "family"),
    ("estrangement", "Estrangement", "family"),
    ("belonging", "Belonging", "identity"),
    ("migration", "Migration", "identity"),
    ("chronic-illness", "Chronic illness", "health"),
    ("recovery", "Recovery", "health"),
    ("anxiety", "Anxiety", "mental-health"),
    ("burnout", "Burnout", "mental-health"),
    ("low-periods", "Low periods", "mental-health"),
    ("caring-for-a-parent", "Caring for a parent", "caregiving"),
    ("carer-burnout", "Carer burnout", "caregiving"),
    ("loneliness", "Feeling unseen", "loneliness"),
    ("quiet-company", "Quiet company", "loneliness"),
    ("breakups", "Breakups", "heartbreak"),
    ("divorce", "Divorce", "heartbreak"),
    ("unrequited", "Unrequited", "heartbreak"),
    ("duty", "Family duty", "sacrifice"),
    ("given-up-dreams", "Dreams given up", "sacrifice"),
    ("grief", "Losing someone", "grief"),
    ("bereavement", "Bereavement", "grief"),
    ("anniversaries", "Hard anniversaries", "grief"),
]


COMMUNITIES = [
    ("good-day", "Good Day", "joy", "Something went right. Say it here."),
    ("laughing-again", "Laughing Again", "joy", "The funny thing that happened to you."),
    ("celebrations", "Celebrations", "joy", "Birthdays, results, weddings, small parties."),
    ("falling", "Falling", "love", "The beginning of something."),
    ("still-choosing", "Still Choosing", "love", "Long love, honestly told."),
    ("open-to-someone", "Open To Someone", "love", "Ready to meet someone new."),
    ("the-ones-who-show-up", "The Ones Who Show Up", "friendship", "Friends who turned up."),
    ("making-friends", "Making Friends", "friendship", "Starting again, socially."),
    ("small-wins", "Small Wins", "wins", "Ordinary days worth saying out loud."),
    ("finally-happened", "Finally Happened", "wins", "The thing you waited years for."),
    ("proud-of-myself", "Proud Of Myself", "wins", "No false modesty here."),
    ("first-days", "First Days", "beginnings", "New job, new city, new life."),
    ("second-chances", "Second Chances", "beginnings", "Beginning again, after a long time."),
    ("still-here", "Still Here", "everyday", "Gratitude without performance."),
    ("out-there", "Out There", "wonder", "Travel, and being surprised by a place."),
    ("on-repeat", "On Repeat", "wonder", "The song that got you through."),
    ("at-the-table", "At The Table", "wonder", "Food, and who you ate it with."),
    ("making-something", "Making Something", "making", "Building, writing, playing, creating."),
    ("ready-again", "Ready Again", "starting-over", "Wanting something new, out loud."),
    ("bad-manager", "Bad Manager", "work", "The one making work unbearable."),
    ("imposter-hours", "Imposter Hours", "work", "Senior enough that saying it is risky."),
    ("after-the-layoff", "After The Layoff", "job-search", "The week after, and the month after."),
    ("offer-or-not", "Offer Or Not", "job-search", "Numbers, offers, and walking away."),
    ("nine-month-gap", "The Nine Month Gap", "job-search", "Explaining a gap, honestly."),
    ("quiet-debt", "Quiet Debt", "money", "Money you cannot talk about."),
    ("first-salary", "First Salary", "money", "Earning, sending home, and guilt."),
    ("exam-season", "Exam Season", "study", "Pressure, failure, and recovery."),
    ("first-year-away", "First Year Away", "study", "Homesick and pretending otherwise."),
    ("raising-them", "Raising Them", "family", "Parenting, unedited."),
    ("complicated-parents", "Complicated Parents", "family", "Parents, distance, estrangement."),
    ("between-places", "Between Places", "identity", "Migration, belonging, neither-here."),
    ("becoming", "Becoming", "identity", "Faith, coming out, changing shape."),
    ("long-haul", "Long Haul", "health", "Chronic illness and living around it."),
    ("the-diagnosis", "The Diagnosis", "health", "The week everything changed."),
    ("running-on-empty", "Running On Empty", "mental-health", "Burnout, anxiety, flat days."),
    ("bad-brain-days", "Bad Brain Days", "mental-health", "Peer support, never advice."),
    ("carer-hours", "Carer Hours", "caregiving", "Looking after someone, honestly."),
    ("invisible-work", "Invisible Work", "caregiving", "The labour nobody counts."),
    ("quiet-company", "Quiet Company", "loneliness", "Low-stakes company for quiet days."),
    ("unseen", "Unseen", "loneliness", "Not in crisis. Just unnoticed."),
    ("after-the-ending", "After The Ending", "heartbreak", "Breakups and what follows."),
    ("still-not-over-it", "Still Not Over It", "heartbreak", "Old heartbreak that has not left."),
    ("the-road-not-taken", "The Road Not Taken", "sacrifice", "What you gave up, and for whom."),
    ("duty-first", "Duty First", "sacrifice", "Family obligation and its cost."),
    ("quiet-grief", "Quiet Grief", "grief", "For the loss you carry without saying."),
    ("first-year-without", "The First Year", "grief", "Anniversaries, empty chairs, firsts."),
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

    category_order = {slug: order for slug, _, _, _, order in CATEGORIES}

    await db["communities"].update_many(
        {"is_curated": True, "_id": {"$nin": [slug for slug, _, _, _ in COMMUNITIES]}},
        {"$set": {"status": "retired", "updated_at": now}},
    )
    await db["interests"].delete_many(
        {"_id": {"$nin": [slug for slug, _, _ in INTERESTS]}}
    )
    await db["community_categories"].delete_many(
        {"_id": {"$nin": [slug for slug, _, _, _, _ in CATEGORIES]}}
    )

    for slug, name, category_id, description in COMMUNITIES:
        await db["communities"].update_one(
            {"_id": slug},
            {
                "$set": {
                    "slug": slug,
                    "name": name,
                    "category_id": category_id,
                    "category_order": category_order.get(category_id, 999),
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
