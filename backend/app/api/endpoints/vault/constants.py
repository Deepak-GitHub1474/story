VAULT_ITEMS = "vault_items"
PASSCODES = "user_passcodes"
USER_KEYS = "user_keys"

VAULT_PROFILE = "vault"

LIST_LIMIT = 100
LABEL_HASH_LENGTH = 64

LIST_PROJECTION = {
    "_id": 1,
    "kind": 1,
    "size_bytes": 1,
    "chunk_count": 1,
    "encrypted_metadata": 1,
    "thumb_encrypted": 1,
    "visibility": 1,
    "status": 1,
    "scan_state": 1,
    "key_state": 1,
    "created_at": 1,
    "wrapped_dek": 1,
    "salt_item": 1,
    "crypto_version": 1,
}
