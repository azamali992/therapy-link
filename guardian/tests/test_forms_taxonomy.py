import pytest

from urduguard import taxonomy
from urduguard.forms import detect


def test_taxonomy_sets_are_consistent():
    assert set(taxonomy.PROTECTIVE) < set(taxonomy.LABELS)
    assert set(taxonomy.DESCRIPTIVE) < set(taxonomy.LABELS)
    assert not set(taxonomy.PROTECTIVE) & set(taxonomy.DESCRIPTIVE)
    assert "benign" in taxonomy.LABELS and "needs_caution" in taxonomy.LABELS
    assert not any("relig" in l for l in taxonomy.LABELS)


def test_validate_rejects_benign_with_others():
    taxonomy.validate(["benign"])
    taxonomy.validate(["harassment", "hate_group"])
    with pytest.raises(ValueError):
        taxonomy.validate(["benign", "sexual"])
    with pytest.raises(ValueError):
        taxonomy.validate([])


@pytest.mark.parametrize("text, form", [
    ("My exam is on Monday and I have not opened the book yet.", "en"),
    ("Janet at school punched me.", "en"),
    ("kal mera paper hai aur maine abhi tak kuch parha nahi", "roman_ur"),
    ("mujhe nahi pata kya karoon yaar", "roman_ur"),
    ("میں آج گھر نہیں جاؤں گا۔", "ur"),
    ("Pills ghar mein hain, I've counted them. Aaj raat.", "mixed"),
    ("", "en"),
])
def test_detect(text, form):
    assert detect(text).form == form
