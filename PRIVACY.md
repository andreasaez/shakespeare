# Privacy

Shakespeare is built so that **what you type can't be recovered from what it stores**, and so that nothing ever leaves your Mac.

## What it reads
- The **key code** and **modifier flags** of each key press, through a *listen-only* event tap (it can't alter or block keys). A key code identifies which key was pressed, and on a known keyboard layout that maps to a letter, so treat it as sensitive. Shakespeare uses it for one thing: deciding whether the press was a letter, the space bar or something else.
- If you turn on **Track top apps** (off by default): the name of the front-most app at the moment of a key press.

What happens next is what protects you. Each key code is reduced to one of four buckets (letter, space, other, or ignored for quit and close shortcuts) in a single function, and the code is discarded there, so nothing downstream ever learns which key it was. **No key identity and no key order is stored.** The only timing saved to disk is a count per hour. For the speed readout, about 60 seconds of anonymous press timestamps (no key identity) are held in memory and never written anywhere. A test, `testStoredStatsDoNotDependOnWhichKeysWereTyped`, fails if the stored data ever depends on which keys were pressed.

macOS generally withholds key events while a password field has focus ("secure input"), so those presses are not seen at all. This is macOS behaviour, not something Shakespeare controls, so don't rely on it as a guarantee.

## What it stores
One file: `~/Library/Application Support/Shakespeare/stats.json` (folder `0700`, file `0600`). Per day it holds only counters:

| Field | Meaning |
|---|---|
| `keys` | total key presses |
| `textKeys` | letter + space presses (for WPM) |
| `bestWPM` | best 60-second rate that day |
| `hours` | 24 counters, presses per hour |
| `apps` | app name → count. **Empty unless you opt in.** |

Open the file in any editor and check. To remove everything Shakespeare leaves on your Mac, see **Uninstall** in the README. The menu has **Show data** and **Delete…** buttons, and turning off *Track top apps* erases stored app names immediately.

## What leaves your Mac
Nothing. There is no networking code, no analytics and no crash reporter, and the app is signed with no network entitlement.
`Scripts/audit-privacy.sh` (run in CI) fails the build if networking APIs, telemetry SDKs or character-reading APIs appear in the source.
Share cards are rendered locally to a PNG that is scrubbed of all metadata (no EXIF, author, device, time or location; only the pixels and a colour profile). You decide whether and where to post them, and app names appear on a card only if you tick **Show top apps on card**.

## Limits worth knowing
- A key code is not anonymous. The protection is what this code does with it (count it, then forget it), and that is a property of this source. A modified copy could log keys, which is why you should build it yourself from source you have read.
- Anything with Input Monitoring permission *could* observe keys. Shakespeare is open source so you can verify it only does what's described here. Build it yourself rather than trusting a binary.
- Key counts and active hours are still personal data about your habits; treat `stats.json` and shared cards accordingly.
