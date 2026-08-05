from fastapi import APIRouter, Request, Response, status

from app.adapters.storage_local import LocalDiskAdapter
from app.core.deps import AppSettings
from app.ports.factory import build_storage

router = APIRouter(prefix="/storage", tags=["storage"])


def _local(settings) -> LocalDiskAdapter | None:
    adapter = build_storage(settings)
    return adapter if isinstance(adapter, LocalDiskAdapter) else None


@router.put("/{profile}/{key:path}", status_code=status.HTTP_200_OK)
async def upload(profile: str, key: str, request: Request, settings: AppSettings):
    adapter = _local(settings)
    if adapter is None:
        return Response(status_code=status.HTTP_404_NOT_FOUND)

    params = request.query_params
    if not adapter.verify(
        profile, key, "PUT", int(params.get("expires", 0)), params.get("signature", "")
    ):
        return Response(status_code=status.HTTP_403_FORBIDDEN)

    payload = await request.body()
    await adapter.write(profile=profile, key=key, payload=payload)
    return Response(status_code=status.HTTP_200_OK)


@router.get("/{profile}/{key:path}")
async def download(profile: str, key: str, request: Request, settings: AppSettings):
    adapter = _local(settings)
    if adapter is None:
        return Response(status_code=status.HTTP_404_NOT_FOUND)

    params = request.query_params
    if not adapter.verify(
        profile, key, "GET", int(params.get("expires", 0)), params.get("signature", "")
    ):
        return Response(status_code=status.HTTP_403_FORBIDDEN)

    payload = await adapter.read(profile=profile, key=key)
    if payload is None:
        return Response(status_code=status.HTTP_404_NOT_FOUND)

    return Response(content=payload, media_type="application/octet-stream")
