import struct

JPEG_SOI = b"\xff\xd8"
JPEG_EOI = b"\xff\xd9"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

SUPPORTED = {"image/jpeg", "image/png"}
DEFAULT_LIMIT = 8 * 1024 * 1024

STANDALONE_MARKERS = frozenset({0xD8, 0xD9, 0x01} | set(range(0xD0, 0xD8)))
STRIPPED_MARKERS = frozenset(set(range(0xE0, 0xF0)) | {0xFE})
KEPT_APP0 = 0xE0

PNG_KEEP = frozenset(
    {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS", b"gAMA", b"cHRM", b"sRGB", b"iCCP"}
)


class UnsupportedImage(Exception):
    pass


class ImageTooBig(Exception):
    pass


def _scrub_jpeg(data: bytes) -> bytes:
    if not data.startswith(JPEG_SOI):
        raise UnsupportedImage

    out = bytearray(JPEG_SOI)
    index = 2
    end = len(data)

    while index < end - 1:
        if data[index] != 0xFF:
            raise UnsupportedImage

        marker = data[index + 1]
        if marker == 0xFF:
            index += 1
            continue

        if marker in STANDALONE_MARKERS:
            index += 2
            continue

        if index + 4 > end:
            raise UnsupportedImage

        length = struct.unpack(">H", data[index + 2 : index + 4])[0]
        if length < 2:
            raise UnsupportedImage

        segment_end = index + 2 + length
        if segment_end > end:
            raise UnsupportedImage

        is_stripped = marker in STRIPPED_MARKERS and marker != KEPT_APP0
        if not is_stripped:
            out += data[index:segment_end]

        if marker == 0xDA:
            out += data[segment_end:]
            return bytes(out)

        index = segment_end

    out += JPEG_EOI
    return bytes(out)


def _scrub_png(data: bytes) -> bytes:
    if not data.startswith(PNG_MAGIC):
        raise UnsupportedImage

    out = bytearray(PNG_MAGIC)
    index = len(PNG_MAGIC)
    end = len(data)

    while index + 8 <= end:
        length = struct.unpack(">I", data[index : index + 4])[0]
        kind = data[index + 4 : index + 8]
        chunk_end = index + 12 + length
        if chunk_end > end:
            raise UnsupportedImage

        if kind in PNG_KEEP:
            out += data[index:chunk_end]

        index = chunk_end
        if kind == b"IEND":
            break

    return bytes(out)


def scrub(data: bytes, *, kind: str, limit: int = DEFAULT_LIMIT) -> bytes:
    if kind not in SUPPORTED:
        raise UnsupportedImage

    if len(data) > limit:
        raise ImageTooBig

    if kind == "image/jpeg":
        return _scrub_jpeg(data)
    return _scrub_png(data)
