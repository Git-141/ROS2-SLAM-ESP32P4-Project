from __future__ import annotations

import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "gui_charset" / "gui_locale_strings.json"
OUT_DIR = ROOT / "docs" / "gui_charset"
ASCII_PRINTABLE = tuple(chr(code) for code in range(0x20, 0x7F))


def flatten_locale_strings(locale_map: dict[str, list[str]]) -> list[str]:
    ordered: list[str] = []
    for section_values in locale_map.values():
        ordered.extend(section_values)
    return ordered


def collect_codepoints(shared_strings: list[str], locale_strings: list[str], symbols: list[str]) -> list[int]:
    chars = set(ASCII_PRINTABLE)
    for item in [*symbols, *shared_strings, *locale_strings]:
        chars.update(item)
    return sorted(ord(ch) for ch in chars)


def write_strings_file(path: Path, shared_strings: list[str], locale_sections: dict[str, list[str]]) -> None:
    lines = ["# shared"]
    lines.extend(shared_strings)
    for section, values in locale_sections.items():
        lines.append("")
        lines.append(f"# {section}")
        lines.extend(values)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_codepoint_text(path: Path, codepoints: list[int]) -> None:
    lines = []
    for codepoint in codepoints:
        ch = chr(codepoint)
        display = ch if ch not in {" ", "\t"} else repr(ch)
        lines.append(f"U+{codepoint:04X}\t{display}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_codepoint_binary(path: Path, codepoints: list[int]) -> None:
    header = struct.pack("<4sHHI", b"UCS4", 1, 0, len(codepoints))
    body = b"".join(struct.pack("<I", codepoint) for codepoint in codepoints)
    path.write_bytes(header + body)


def main() -> None:
    bundle = json.loads(SOURCE.read_text(encoding="utf-8"))
    shared_strings = bundle["shared"]["strings"]
    shared_symbols = bundle["shared"]["symbols"]
    locales = bundle["locales"]

    manifest = {
        "generated_from": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "binary_format": {
            "magic": "UCS4",
            "version": 1,
            "endianness": "little",
            "count_type": "uint32",
            "codepoint_type": "uint32"
        },
        "ascii_range": "U+0020-U+007E",
        "locales": {}
    }

    for locale_name, locale_sections in locales.items():
        locale_strings = flatten_locale_strings(locale_sections)
        codepoints = collect_codepoints(shared_strings, locale_strings, shared_symbols)

        strings_file = OUT_DIR / f"{locale_name}.strings.txt"
        txt_file = OUT_DIR / f"{locale_name}.codepoints.txt"
        bin_file = OUT_DIR / f"{locale_name}.codepoints.bin"

        write_strings_file(strings_file, shared_strings, locale_sections)
        write_codepoint_text(txt_file, codepoints)
        write_codepoint_binary(bin_file, codepoints)

        manifest["locales"][locale_name] = {
            "string_count": len(shared_strings) + len(locale_strings),
            "codepoint_count": len(codepoints),
            "strings_file": strings_file.name,
            "codepoints_text_file": txt_file.name,
            "codepoints_binary_file": bin_file.name
        }

    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
