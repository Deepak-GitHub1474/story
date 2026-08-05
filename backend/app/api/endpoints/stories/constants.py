STORIES = "stories"
COMMENTS = "comments"
REACTIONS = "reactions"
USERS = "users"

BODY_MAX = 20000
TITLE_MAX = 120
COMMENT_MAX = 2000
EXCERPT_LENGTH = 240
WORDS_PER_MINUTE = 220
FEED_DEFAULT_LIMIT = 20
FEED_MAX_LIMIT = 50
EDIT_WINDOW_HOURS = 24
INLINE_REPLIES = 3
COMMUNITY_FANOUT_CAP = 200
COMMENT_EDIT_WINDOW_MINUTES = 15

FEED_PROJECTION = {
    "_id": 1,
    "community": 1,
    "author_id": 1,
    "author_snapshot": 1,
    "title": 1,
    "excerpt": 1,
    "visibility": 1,
    "slug": 1,
    "counts": 1,
    "reading_minutes": 1,
    "published_at": 1,
    "created_at": 1,
    "updated_at": 1,
}
