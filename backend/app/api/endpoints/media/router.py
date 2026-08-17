import base64
import re

from fastapi import APIRouter, Depends, Response, status

from app.api.endpoints.media.cleanup import MEDIA, url_for
from app.api.endpoints.media.models import UploadImageRequest
from app.config import get_settings
from app.core.deps import CurrentClaims, rate_limit_dep
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.images import ImageTooBig, UnsupportedImage, scrub
from app.core.time import utc_now
from app.db.mongo import MongoDatabase
from app.ports.factory import build_storage
from app.responses import ok_response

router = APIRouter(tags=["media"])

PROFILE = "media"
MEDIA_ID = re.compile(r"^med_[0-9A-HJKMNP-TV-Z]{26}$")


def _key(media_id: str) -> str:
    return f"media/{media_id}"


@router.post(
    "/media/images",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("media_upload", 60, 3600))],
)
async def upload_image(
    body: UploadImageRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    storage = build_storage(get_settings())

    try:
        raw = base64.b64decode(body.data, validate=True)
    except Exception:
        raise api_error(ErrorCode.VALIDATION_FAILED, field="data") from None

    try:
        cleaned = scrub(raw, kind=body.kind)
    except UnsupportedImage:
        raise api_error(ErrorCode.UNSUPPORTED_IMAGE, field="data") from None
    except ImageTooBig:
        raise api_error(ErrorCode.IMAGE_TOO_BIG, field="data") from None

    media_id = new_id("med")
    await mongo[MEDIA].insert_one({"_id": media_id, "created_at": utc_now()})
    await storage.write(profile=PROFILE, key=_key(media_id), payload=cleaned)

    return ok_response(
        "Picture stored, with its hidden details removed.",
        data={"media_id": media_id, "url": url_for(media_id), "kind": body.kind},
    )


@router.get("/media/{media_id}", status_code=status.HTTP_200_OK)
async def read_image(media_id: str):
    if not MEDIA_ID.match(media_id):
        raise api_error(ErrorCode.MEDIA_NOT_FOUND)

    storage = build_storage(get_settings())
    payload = await storage.read(profile=PROFILE, key=_key(media_id))
    if payload is None:
        raise api_error(ErrorCode.MEDIA_NOT_FOUND)

    kind = "image/png" if payload.startswith(b"\x89PNG") else "image/jpeg"
    return Response(
        content=payload,
        media_type=kind,
        headers={
            "cache-control": "private, max-age=86400",
            "x-content-type-options": "nosniff",
            "content-security-policy": "default-src 'none'; sandbox",
        },
    )
