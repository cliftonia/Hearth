"""Rebuilds Localizable.xcstrings from Strings.swift and its extensions. Run with `python3 Tools/sync_strings.py`."""
import glob
import json
import re

SOURCES = "HearthKit/Sources/HearthUI/Localization/Strings*.swift"
CATALOG = "HearthKit/Sources/HearthUI/Resources/Localizable.xcstrings"

pattern = re.compile(r'String\(localized: "([^"]+)", defaultValue: "((?:[^"\\]|\\.)*)"[^\n]*?(?://\s*one:\s*"((?:[^"\\]|\\.)*)")?\n')
strings = {}
text = "".join(open(path, encoding="utf-8").read() for path in sorted(glob.glob(SOURCES)))


def formatted(value):
    """Interpolations become positional format specifiers, as the compiler writes them."""
    arguments = re.findall(r"\\\(([^)]+)\)", value)
    for position, argument in enumerate(arguments, start=1):
        specifier = "lld" if argument in ("seconds", "modelCount", "number", "total", "ahead") else "@"
        prefix = f"%{position}$" if len(arguments) > 1 else "%"
        value = value.replace(f"\\({argument})", prefix + specifier, 1)
    return value


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


for key, value, one in pattern.findall(text):
    # A string with a `// one: "..."` comment after it on the same line has a singular form, and becomes a plural
    # variation, so that 1 is never followed by a plural noun.
    if one:
        english = {"variations": {"plural": {"one": unit(formatted(one)), "other": unit(formatted(value))}}}
    else:
        english = unit(formatted(value))
    strings[key] = {"extractionState": "manual", "localizations": {"en": english}}

catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
with open(CATALOG, "w", encoding="utf-8") as output:
    json.dump(catalog, output, ensure_ascii=False, indent=2, sort_keys=True)
    output.write("\n")
print(f"{len(strings)} keys")
