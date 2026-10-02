# ARB recovery check against the v16 APK

`app/lib/l10n/app_en.arb` and `app_ur.arb` came back from replaying session logs. This compares every key in both files (370 each) with the strings compiled into the v16 APK and records what I changed.

## Result

| | en | ur | total |
|---|---|---|---|
| Matches the APK exactly | 361 | 361 | 722 |
| Restored from the APK | 0 | 1 | 1 |
| Differs, kept for review | 1 | 0 | 1 |
| Not in the APK: added after v16 | 4 | 4 | 8 |
| Not in the APK: key never used, so AOT dropped it | 4 | 4 | 8 |
| **Total** | 370 | 370 | 740 |

After the fixes both files are valid JSON with no duplicate keys, the key sets are identical (370 each), every placeholder used in en is used in ur and declared in en's `@key` metadata, and `flutter gen-l10n` runs clean (exit 0, no warnings, Flutter at `D:\dev\flutter`).

## How the comparison works

`apk/strings/libapp_prose_strings.txt` and `libapp.so.strings.txt` aren't enough on their own. They're `strings` output, so:

- Strings with any character above U+00FF (`…`, `—`, `’`, `·`) are stored as UTF-16 in the Dart snapshot and don't appear in them at all.
- A line can carry a stray byte from the next record (`Abhi koi baat cheet nahi(`), so a line match isn't proof of an exact match.

So I read `apk/apktool_out/lib/arm64-v8a/libapp.so` directly. In this snapshot each string is a varint header (`length << 1 | is_two_byte`, last byte has the high bit set) followed by Latin-1 or UTF-16LE data, which gives the exact bounds of every string. For each ARB message I split out its literal parts (text between `{placeholders}` and each plural branch, which is how the compiled interpolation stores them) and looked for each part as a complete string record. A message counts as an exact match only when every part is a whole record in the APK.

The 48 keys where en and ur hold the same text (`email`, `Save`, `Emergency · 1122`, `Box breathing` and so on) match the APK, and I found no leftover Roman Urdu string in the APK that would belong to any of them, so those are intentional.

## Changes made

Commit `086ef85` (Fix recovery damage in the ARB string tables):

1. **Duplicated block removed, both files.** The replay wrote the same block twice: `settingsPrivacy`, `appLockTitle`, `appLockBody`, `appLockUnavailable`, `lockTitle`, `lockBody`, `lockUnlock`, `lockFailed`, `lockReason`, `quickExitTitle`, `quickExitBody`, `quickExitNeutral`, `dbMigrationFailed`, `dbUnreadable`, plus their 8 `@` entries in en. That's 22 duplicate entries in en (lines 620-657) and 14 in ur (lines 481-494). Both copies were byte-identical, so no text changed. JSON parsers took the last copy without complaint, which is why the earlier "valid JSON" check missed it.
2. **ur `dbOpenFailed` restored.** This is the string whose unescaped quotes broke the JSON. The repair deleted the quotes. The APK has single quotes, the same way ur `appLockBody` (which matches the APK) quotes the button name:
   - before: `... baat karni hai to Abhi madad lein ab bhi kaam karta hai.`
   - after (as shipped): `... baat karni hai to 'Abhi madad lein' ab bhi kaam karta hai.`

   Single quotes are literal here because `l10n.yaml` doesn't turn on `use-escaping`. gen-l10n emits `\'Abhi madad lein\'` in `app_localizations_ur.dart`.

Not committed: `app_localizations_ur.dart`. Running gen-l10n changes that one line, but this workstream only edits the ARB files, so I put the generated file back. Whoever owns `app/lib` should regenerate it, or the build will keep showing the unquoted string.

## Differs, kept for review

**en `resultScore`** = `{score} out of {max}`. ur `{max} mein se {score}` is in the APK (` mein se ` is a record), so the screen was compiled, but there is no ` out of ` record. The only close record is `out of ` with no leading space, sitting among SDK strings. So v16's English wording for this was something else and I can't recover it from the binary. The current text is fine as copy. Left as is.

## Not in the APK

Added after v16 (the recovered app code uses them, and they're marked PENDING CLINICIAN REVIEW). Kept:

| key | en |
|---|---|
| `eveSafetyNotReadyTitle` | Safety check not ready |
| `eveSafetyNotReadyBody` | Eve checks every message for signs of danger before she replies. ... |
| `eveUnavailableTitle` | Eve isn't available in this version |
| `eveUnavailableBody` | Eve's model for this app hasn't been released yet. ... |

Never referenced by any Dart file in the recovered app (`D:\therapylink\app\lib`), so the compiler dropped them. Kept; delete them if v3 doesn't use them either:

| key | en | ur |
|---|---|---|
| `moodSaved` | Noted. | Note kar liya. |
| `careShareSummaries` | Weekly summaries | Haftawar summaries |
| `careRevoked` | Removed | Hata diya |
| `eveWrapUpWorking` | Pulling today together… | Aaj ki baat samet rahi hoon… |

## Shipped text that isn't in the ARB files

The APK also has user-facing text that never lived in the ARB files and so isn't covered above: crisis copy and the conversation list strings in `features/shared/crisis_copy.dart` and `features/eve/conversations_copy.dart` (e.g. "Kept on this phone only. Tap one to pick it up again.", "This phone couldn't start the call. Dial this number:"), and the PHQ-9/GAD-7 items in both languages. Those need the same review if they get ported to v3.
