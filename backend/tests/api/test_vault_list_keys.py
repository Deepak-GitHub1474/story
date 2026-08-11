from app.api.endpoints.vault.controllers import serialize_item


def a_stored_item():
    return {
        "_id": "vit_1",
        "user_id": "usr_1",
        "kind": "image",
        "size_bytes": 2400000,
        "chunk_count": 3,
        "encrypted_metadata": "bWV0YQ==",
        "visibility": "normal",
        "status": "ready",
        "wrapped_dek": "d3JhcHBlZA==",
        "salt_item": "c2FsdA==",
        "created_at": None,
    }


def test_listing_carries_the_keys_the_owner_needs_to_open_a_file():
    listed = serialize_item(a_stored_item())

    assert listed["wrapped_dek"] is not None, (
        "without this the app cannot decrypt and reports the file as broken"
    )
    assert listed["salt_item"] is not None


def test_the_keys_travel_wrapped_never_bare():
    listed = serialize_item(a_stored_item())

    assert listed["wrapped_dek"] == "d3JhcHBlZA=="
    assert "dek" not in listed
    assert "umk" not in listed
    assert "passcode_key" not in listed


def test_nothing_readable_about_the_file_is_exposed():
    listed = serialize_item(a_stored_item())

    assert "filename" not in listed
    assert "plaintext" not in listed
    assert listed["encrypted_metadata"] == "bWV0YQ=="
