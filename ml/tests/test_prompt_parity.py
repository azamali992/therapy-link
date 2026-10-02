import re
from pathlib import Path

from therapylink_ml.prompts import MEMORY_HEADER, SERVED_SYSTEM_PROMPT, SUMMARY_HEADER, fold_system_into_first_user

APP_ENGINE = Path(__file__).resolve().parents[2] / "app" / "lib" / "core" / "ml" / "eve_engine.dart"


def test_app_and_training_use_the_same_system_prompt():
    # The prompt is folded into every training conversation, so the app must send the identical
    # text. A one-word drift means the model is served a prompt it was never trained on.
    source = APP_ENGINE.read_text(encoding="utf-8")
    match = re.search(r"const eveSystemPrompt = '''(.*?)''';", source, re.S)
    assert match, "eveSystemPrompt not found in eve_engine.dart"
    assert match.group(1) == SERVED_SYSTEM_PROMPT


APP_MEMORY = Path(__file__).resolve().parents[2] / "app" / "lib" / "features" / "eve" / "memory.dart"


def test_app_and_training_use_the_same_memory_headers():
    source = APP_MEMORY.read_text(encoding="utf-8")
    assert f"const memoryHeader = '{MEMORY_HEADER}';" in source
    assert f"const summaryHeader = '{SUMMARY_HEADER}';" in source


def test_notes_sit_between_the_system_prompt_and_the_first_message():
    folded = fold_system_into_first_user([{"role": "user", "content": "hi"}], notes="NOTES")
    assert folded[0]["content"].endswith("\n\nNOTES\n\nhi")
    assert fold_system_into_first_user([{"role": "user", "content": "hi"}])[0]["content"].endswith("\n\nhi")
