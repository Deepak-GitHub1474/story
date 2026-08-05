import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "packages" / "design-tokens" / "tokens.json"
CSS_OUT = ROOT / "web" / "src" / "styles" / "tokens.css"
ADMIN_OUT = ROOT / "admin" / "src" / "styles" / "tokens.css"

BANNER = """/* GENERATED FILE — DO NOT EDIT.
   Source: packages/design-tokens/tokens.json
   Regenerate: make tokens */
"""


def kebab(name: str) -> str:
    return "".join(f"-{c.lower()}" if c.isupper() else c for c in name).strip("-")


def theme_block(selector: str, colors: dict[str, str]) -> str:
    lines = [f"{selector} {{"]
    lines += [f"  --c-{kebab(name)}: {value};" for name, value in colors.items()]
    lines.append("}")
    return "\n".join(lines)


def scale_block(prefix: str, values: dict[str, float], unit: str) -> str:
    return "\n".join(f"  --{prefix}-{kebab(k)}: {v}{unit};" for k, v in values.items())


def build_css(tokens: dict) -> str:
    themes = tokens["themes"]
    parts = [BANNER, theme_block(":root, [data-theme='midnight']", themes["midnight"])]
    parts.append(theme_block("[data-theme='paper']", themes["paper"]))
    parts.append(
        "@media (prefers-color-scheme: light) {\n  "
        + theme_block(":root:not([data-theme])", themes["paper"]).replace("\n", "\n  ")
        + "\n}"
    )

    scales = [
        ":root {",
        scale_block("space", tokens["spacing"], "px"),
        scale_block("radius", tokens["radius"], "px"),
        scale_block("text", tokens["type"], "px"),
        scale_block("size", tokens["size"], "px"),
        scale_block("motion", tokens["motion"], "ms"),
        "}",
    ]
    parts.append("\n".join(scales))

    theme_inline = ["@theme inline {"]
    for name in themes["midnight"]:
        theme_inline.append(f"  --color-{kebab(name)}: var(--c-{kebab(name)});")
    theme_inline.append("}")
    parts.append("\n".join(theme_inline))

    return "\n\n".join(parts) + "\n"


def main() -> int:
    tokens = json.loads(SOURCE.read_text())
    css = build_css(tokens)

    written = []
    for out in (CSS_OUT, ADMIN_OUT):
        if not out.parent.parent.parent.exists():
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(css)
        written.append(str(out.relative_to(ROOT)))

    print(f"tokens written: {', '.join(written) or 'none (no web/ or admin/ yet)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
