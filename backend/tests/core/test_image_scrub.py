import struct

from app.core.images import ImageTooBig, UnsupportedImage, scrub

JPEG_SOI = b"\xff\xd8"
JPEG_EOI = b"\xff\xd9"


def jpeg_with(*segments: bytes) -> bytes:
    return JPEG_SOI + b"".join(segments) + JPEG_EOI


def segment(marker: int, payload: bytes) -> bytes:
    return bytes([0xFF, marker]) + struct.pack(">H", len(payload) + 2) + payload


def png_with(*chunks: bytes) -> bytes:
    return b"\x89PNG\r\n\x1a\n" + b"".join(chunks)


def chunk(kind: bytes, payload: bytes = b"") -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + b"\x00\x00\x00\x00"


def test_a_jpeg_loses_its_exif():
    exif = segment(0xE1, b"Exif\x00\x00" + b"GPS 51.5074 N, camera serial 12345")
    image = jpeg_with(exif, segment(0xDB, b"quantisation"), segment(0xDA, b"pixels"))

    cleaned = scrub(image, kind="image/jpeg")

    assert b"GPS" not in cleaned
    assert b"camera serial" not in cleaned


def test_a_jpeg_keeps_the_parts_that_draw_the_picture():
    image = jpeg_with(
        segment(0xE1, b"Exif\x00\x00location"),
        segment(0xDB, b"quantisation-table"),
        segment(0xDA, b"actual-pixels"),
    )

    cleaned = scrub(image, kind="image/jpeg")

    assert b"quantisation-table" in cleaned
    assert b"actual-pixels" in cleaned
    assert cleaned.startswith(JPEG_SOI)


def test_a_jpeg_loses_every_comment_and_photoshop_block():
    image = jpeg_with(
        segment(0xED, b"Photoshop 3.0 with the author name"),
        segment(0xFE, b"a comment naming the town"),
        segment(0xDA, b"pixels"),
    )

    cleaned = scrub(image, kind="image/jpeg")

    assert b"Photoshop" not in cleaned
    assert b"naming the town" not in cleaned


def test_a_png_loses_its_text_chunks():
    image = png_with(
        chunk(b"IHDR", b"header"),
        chunk(b"tEXt", b"Author\x00Deepak from Leeds"),
        chunk(b"IDAT", b"pixels"),
        chunk(b"IEND"),
    )

    cleaned = scrub(image, kind="image/png")

    assert b"Deepak from Leeds" not in cleaned
    assert b"pixels" in cleaned


def test_a_png_keeps_what_it_needs_to_render():
    image = png_with(chunk(b"IHDR", b"header"), chunk(b"IDAT", b"pixels"), chunk(b"IEND"))

    cleaned = scrub(image, kind="image/png")

    assert cleaned == image


def test_something_that_is_not_an_image_is_refused():
    try:
        scrub(b"%PDF-1.4 this is a document", kind="image/jpeg")
    except UnsupportedImage:
        return
    raise AssertionError("a PDF pretending to be a JPEG should be refused")


def test_a_kind_we_do_not_take_is_refused():
    try:
        scrub(b"GIF89a", kind="image/gif")
    except UnsupportedImage:
        return
    raise AssertionError("gif should be refused")


def test_an_enormous_image_is_refused():
    try:
        scrub(jpeg_with(segment(0xDA, b"x" * 100)), kind="image/jpeg", limit=64)
    except ImageTooBig:
        return
    raise AssertionError("an oversized image should be refused")
