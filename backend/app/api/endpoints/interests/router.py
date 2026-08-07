from fastapi import APIRouter, status

from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(tags=["interests"])


@router.get("/interests", status_code=status.HTTP_200_OK)
async def list_interests(mongo: MongoDatabase):
    cursor = (
        mongo["interests"]
        .find({}, {"_id": 1, "name": 1, "category_id": 1})
        .sort([("category_order", 1), ("sort_order", 1), ("_id", 1)])
    )
    items = [
        {"slug": doc["_id"], "name": doc["name"], "category_id": doc["category_id"]}
        async for doc in cursor
    ]
    return ok_response("Interests loaded.", data={"items": items})


@router.get("/communities/categories", status_code=status.HTTP_200_OK)
async def list_categories(mongo: MongoDatabase):
    cursor = (
        mongo["community_categories"]
        .find({"status": "active"}, {"_id": 1, "name": 1, "tone": 1, "description": 1, "icon": 1})
        .sort("sort_order", 1)
    )
    items = [
        {
            "slug": doc["_id"],
            "name": doc["name"],
            "tone": doc["tone"],
            "description": doc["description"],
            "icon": doc["icon"],
        }
        async for doc in cursor
    ]
    return ok_response("Categories loaded.", data={"items": items})
