from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import re


IOHOOK_KEY_NAMES: dict[int, str] = {
    1: "Escape",
    2: "Digit1",
    3: "Digit2",
    4: "Digit3",
    5: "Digit4",
    6: "Digit5",
    7: "Digit6",
    8: "Digit7",
    9: "Digit8",
    10: "Digit9",
    11: "Digit0",
    12: "Minus",
    13: "Equal",
    14: "Backspace",
    15: "Tab",
    16: "KeyQ",
    17: "KeyW",
    18: "KeyE",
    19: "KeyR",
    20: "KeyT",
    21: "KeyY",
    22: "KeyU",
    23: "KeyI",
    24: "KeyO",
    25: "KeyP",
    26: "BracketLeft",
    27: "BracketRight",
    28: "Enter",
    29: "ControlLeft",
    30: "KeyA",
    31: "KeyS",
    32: "KeyD",
    33: "KeyF",
    34: "KeyG",
    35: "KeyH",
    36: "KeyJ",
    37: "KeyK",
    38: "KeyL",
    39: "Semicolon",
    40: "Quote",
    41: "Backquote",
    42: "ShiftLeft",
    43: "Backslash",
    44: "KeyZ",
    45: "KeyX",
    46: "KeyC",
    47: "KeyV",
    48: "KeyB",
    49: "KeyN",
    50: "KeyM",
    51: "Comma",
    52: "Period",
    53: "Slash",
    54: "ShiftRight",
    55: "NumpadMultiply",
    56: "AltLeft",
    57: "Space",
    58: "CapsLock",
    59: "F1",
    60: "F2",
    61: "F3",
    62: "F4",
    63: "F5",
    64: "F6",
    65: "F7",
    66: "F8",
    67: "F9",
    68: "F10",
    69: "NumLock",
    70: "ScrollLock",
    71: "Numpad7",
    72: "Numpad8",
    73: "Numpad9",
    74: "NumpadSubtract",
    75: "Numpad4",
    76: "Numpad5",
    77: "Numpad6",
    78: "NumpadAdd",
    79: "Numpad1",
    80: "Numpad2",
    81: "Numpad3",
    82: "Numpad0",
    83: "NumpadDecimal",
    87: "F11",
    88: "F12",
    91: "F13",
    92: "F14",
    93: "F15",
    95: "Fn",
    96: "Clear",
    99: "F16",
    100: "AltRight",
    101: "F18",
    102: "F19",
    103: "F20",
    104: "F21",
    105: "F22",
    106: "F23",
    107: "F24",
    112: "Convert",
    115: "Lang1",
    119: "Lang2",
    121: "KanaMode",
    123: "HiraganaKatakana",
    125: "IntlYen",
    126: "NumpadComma",
    3597: "ControlRight",
    3612: "NumpadEnter",
    3613: "NumpadMultiply",
    3637: "NumpadDivide",
    3639: "Numpad7",
    3640: "Numpad8",
    3653: "Numpad9",
    3655: "NumpadAdd",
    3657: "Numpad4",
    3663: "Numpad5",
    3665: "Numpad6",
    3666: "Numpad1",
    3667: "Numpad2",
    3675: "Numpad3",
    3676: "NumpadEnter",
    3677: "Numpad0",
    57399: "PrintScreen",
    57400: "AltRight",
    57415: "Home",
    57416: "ArrowUp",
    57417: "PageUp",
    57419: "ArrowLeft",
    57421: "ArrowRight",
    57423: "End",
    57424: "ArrowDown",
    57425: "PageDown",
    57426: "Insert",
    57427: "Delete",
    57435: "MetaLeft",
    57436: "MetaRight",
    57437: "ContextMenu",
    60999: "Insert",
    61000: "Delete",
    61001: "Home",
    61003: "End",
    61005: "PageUp",
    61007: "PageDown",
    61008: "PrintScreen",
    61009: "ScrollLock",
    61010: "Pause",
    61011: "NumpadDecimal",
}

MACOS_KEY_GROUPS: dict[str, set[int]] = {
    "space": {49},
    "enter": {36, 52},
    "backspace": {51},
    "tab": {48},
    "escape": {53},
    "caps_lock": {57},
    "function": {64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105, 106, 107, 109, 111, 113, 118, 120, 122},
    "arrow": {123, 124, 125, 126},
    "navigation": {114, 115, 116, 117, 119, 121},
    "numpad": {65, 67, 69, 71, 72, 73, 75, 76, 77, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92},
    "modifier_left": {55, 56, 58, 59, 63},
    "modifier_right": {54, 60, 61, 62},
    "number_row": {18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 50},
    "alphanumeric_left": {0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 17},
    "alphanumeric_right": {4, 16, 31, 32, 34, 35, 37, 38, 40, 45, 46},
    "punctuation": {30, 33, 39, 41, 42, 43, 44, 47},
}

LEFT_ALPHA_KEYS = {
    "KeyQ", "KeyW", "KeyE", "KeyR", "KeyT",
    "KeyA", "KeyS", "KeyD", "KeyF", "KeyG",
    "KeyZ", "KeyX", "KeyC", "KeyV", "KeyB",
}
RIGHT_ALPHA_KEYS = {
    "KeyY", "KeyU", "KeyI", "KeyO", "KeyP",
    "KeyH", "KeyJ", "KeyK", "KeyL",
    "KeyN", "KeyM",
}
PUNCTUATION_KEYS = {
    "BracketLeft", "BracketRight", "Backslash",
    "Semicolon", "Quote", "Comma", "Period", "Slash",
}
LEFT_MODIFIER_KEYS = {"ShiftLeft", "ControlLeft", "AltLeft", "MetaLeft", "CommandLeft", "Fn", "OptionLeft"}
RIGHT_MODIFIER_KEYS = {"ShiftRight", "ControlRight", "AltRight", "MetaRight", "CommandRight", "ContextMenu", "OptionRight"}
NAVIGATION_KEYS = {"Home", "End", "PageUp", "PageDown", "Insert", "Delete", "Help"}
NUMPAD_KEYS = {
    "NumLock", "Clear", "NumpadComma", "NumpadDecimal", "Numpad0", "Numpad1", "Numpad2", "Numpad3",
    "Numpad4", "Numpad5", "Numpad6", "Numpad7", "Numpad8", "Numpad9", "NumpadAdd",
    "NumpadSubtract", "NumpadMultiply", "NumpadDivide", "NumpadEnter", "NumpadEquals",
}
FUNCTION_KEYS = {
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
    "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23", "F24",
    "PrintScreen", "ScrollLock", "Pause",
}
NUMBER_ROW_KEYS = {"Backquote", "Digit1", "Digit2", "Digit3", "Digit4", "Digit5", "Digit6", "Digit7", "Digit8", "Digit9", "Digit0", "Minus", "Equal"}

NAMED_KEYS = {
    "space": "Space",
    "spacebar": "Space",
    "enter": "Enter",
    "return": "Enter",
    "backspace": "Backspace",
    "bksp": "Backspace",
    "tab": "Tab",
    "capslock": "CapsLock",
    "capslockkey": "CapsLock",
    "caps": "CapsLock",
    "capslocktoggle": "CapsLock",
    "capslockbutton": "CapsLock",
    "shift": "ShiftLeft",
    "shiftleft": "ShiftLeft",
    "lshift": "ShiftLeft",
    "shiftright": "ShiftRight",
    "rshift": "ShiftRight",
    "ctrl": "ControlLeft",
    "control": "ControlLeft",
    "option": "AltLeft",
    "alt": "AltLeft",
    "cmd": "MetaLeft",
    "command": "MetaLeft",
    "meta": "MetaLeft",
    "menu": "ContextMenu",
    "escape": "Escape",
    "esc": "Escape",
    "left": "ArrowLeft",
    "right": "ArrowRight",
    "up": "ArrowUp",
    "down": "ArrowDown",
    "arrowleft": "ArrowLeft",
    "arrowright": "ArrowRight",
    "arrowup": "ArrowUp",
    "arrowdown": "ArrowDown",
    "home": "Home",
    "end": "End",
    "pageup": "PageUp",
    "pagedown": "PageDown",
    "delete": "Delete",
    "ins": "Insert",
    "insert": "Insert",
    "clear": "Clear",
    "fn": "Fn",
    "printscreen": "PrintScreen",
    "prtsc": "PrintScreen",
    "scrolllock": "ScrollLock",
    "pause": "Pause",
}

SYMBOL_KEYS = {
    "`": "Backquote",
    "[": "BracketLeft",
    "]": "BracketRight",
    "\\": "Backslash",
    ";": "Semicolon",
    "'": "Quote",
    ",": "Comma",
    ".": "Period",
    "/": "Slash",
    "-": "Minus",
    "=": "Equal",
}


def _normalize_identifier(identifier: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", identifier.lower())


def _strip_direction_suffix(stem: str) -> tuple[str, str]:
    lowered = stem.lower()
    if lowered.endswith("-up"):
        return stem[:-3], "up"
    if lowered.endswith("_up"):
        return stem[:-3], "up"
    return stem, "down"


def key_name_for_identifier(identifier: str) -> str | None:
    stripped = identifier.strip()
    if not stripped:
        return None

    if stripped.isdigit():
        return IOHOOK_KEY_NAMES.get(int(stripped))

    if stripped in SYMBOL_KEYS:
        return SYMBOL_KEYS[stripped]

    normalized = _normalize_identifier(stripped)
    if normalized in NAMED_KEYS:
        return NAMED_KEYS[normalized]

    if len(stripped) == 1 and stripped.isalpha():
        return f"Key{stripped.upper()}"
    if len(stripped) == 1 and stripped.isdigit():
        return f"Digit{stripped}"

    if normalized.startswith("key") and len(normalized) == 4 and normalized[-1].isalpha():
        return f"Key{normalized[-1].upper()}"
    if normalized.startswith("digit") and normalized[-1].isdigit():
        return f"Digit{normalized[-1]}"
    if normalized.startswith("f") and normalized[1:].isdigit():
        return normalized.upper()

    return None


def infer_group_for_key_name(key_name: str | None) -> str:
    if not key_name:
        return "alphanumeric"

    if key_name == "Space":
        return "space"
    if key_name == "Enter":
        return "enter"
    if key_name == "Backspace":
        return "backspace"
    if key_name == "Tab":
        return "tab"
    if key_name == "CapsLock":
        return "caps_lock"
    if key_name == "Escape":
        return "escape"
    if key_name.startswith("Arrow"):
        return "arrow"
    if key_name in FUNCTION_KEYS:
        return "function"
    if key_name in NUMBER_ROW_KEYS:
        return "number_row"
    if key_name in LEFT_MODIFIER_KEYS:
        return "modifier_left"
    if key_name in RIGHT_MODIFIER_KEYS:
        return "modifier_right"
    if key_name in NAVIGATION_KEYS:
        return "navigation"
    if key_name in NUMPAD_KEYS:
        return "numpad"
    if key_name in PUNCTUATION_KEYS:
        return "punctuation"
    if key_name in LEFT_ALPHA_KEYS:
        return "alphanumeric_left"
    if key_name in RIGHT_ALPHA_KEYS:
        return "alphanumeric_right"
    return "alphanumeric"


def infer_group_for_sample(relative_path: str) -> tuple[str, str]:
    path = Path(relative_path)
    stem, direction = _strip_direction_suffix(path.stem)
    lowered = relative_path.lower()
    if "/up/" in lowered or "/release/" in lowered:
        direction = "up"

    key_name = key_name_for_identifier(stem)
    return infer_group_for_key_name(key_name), direction


def build_grouped_sample_index(relative_paths: list[str]) -> dict[str, dict[str, list[str]]]:
    grouped: dict[str, dict[str, list[str]]] = defaultdict(lambda: {"down": [], "up": []})
    for relative_path in sorted(relative_paths):
        group, direction = infer_group_for_sample(relative_path)
        grouped[group][direction].append(relative_path)
    return dict(grouped)


def infer_group_for_macos_keycode(keycode: int) -> str:
    for group, codes in MACOS_KEY_GROUPS.items():
        if keycode in codes:
            return group
    return "alphanumeric"
