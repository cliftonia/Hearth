"""Rebuilds Localizable.xcstrings from Strings.swift. Run with `python3 Tools/sync_strings.py`."""
import json
import re

SOURCE = "HearthKit/Sources/HearthUI/Localization/Strings.swift"
CATALOG = "HearthKit/Sources/HearthUI/Resources/Localizable.xcstrings"

pattern = re.compile(r'String\(localized: "([^"]+)", defaultValue: "((?:[^"\\]|\\.)*)"')
strings = {}
for key, value in pattern.findall(open(SOURCE, encoding="utf-8").read()):
    # Interpolations become positional format specifiers, as the compiler writes them.
    arguments = re.findall(r"\\\(([^)]+)\)", value)
    for position, argument in enumerate(arguments, start=1):
        specifier = "lld" if argument in ("seconds", "modelCount", "number", "total", "ahead") else "@"
        prefix = f"%{position}$" if len(arguments) > 1 else "%"
        value = value.replace(f"\\({argument})", prefix + specifier, 1)
    strings[key] = {"extractionState": "manual", "localizations": {"en": {"stringUnit": {"state": "translated", "value": value}}}}

catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
with open(CATALOG, "w", encoding="utf-8") as output:
    json.dump(catalog, output, ensure_ascii=False, indent=2, sort_keys=True)
    output.write("\n")
print(f"{len(strings)} keys")
