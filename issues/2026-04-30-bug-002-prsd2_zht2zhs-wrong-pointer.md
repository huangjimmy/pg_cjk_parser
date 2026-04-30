# Bug 002 — `prsd2_zht2zhs`: wrong pointer in `else` branch skips conversions

**Status: FIXED** — merged in commit `b62aa51` (PR #13), 2026-04-30

**File:** `pg_cjk_parser.c`  
**Function:** `prsd2_zht2zhs`  
**Severity:** High — causes `prsd2_zht2zhs` to silently miss Traditional→Simplified conversions

---

## Description

`prsd2_zht2zhs` walks the input buffer byte-by-byte using an integer offset `pos`.
When the current character is **not** in the Traditional Chinese range, the `else`
branch reads the **first byte of the buffer** (`*cur`) to decide how many bytes to
advance — instead of the byte at the **current position** (`*(cur + pos)`).

```c
/* pg_cjk_parser.c ~line 2969 */
while(pos < size){
    unsigned int cjk = utf8_cjkCodePoint(cur + pos);   /* ✓ uses offset */

    if(cjk >= 0x346F && cjk <= 0x9FD3){
        cjk = zht2zhs[cjk - 0x346F];
        utf8_setCjkCodePoint(cur + pos, cjk);           /* ✓ uses offset */
        pos += 3;
    }
    else{
        unsigned char c = *cur;     /* ✗ BUG: should be *(cur + pos) */
        if(c < 128) pos++;
        else if(((c ^ 0xC0) & 0xE0) == 0) pos += 2;   /* 2-byte lead */
        else if(((c ^ 0xE0) & 0xF0) == 0) pos += 3;   /* 3-byte lead */
        else if(((c ^ 0xF0) & 0xF8) == 0) pos += 4;   /* 4-byte lead */
        else if(((c ^ 0xF8) & 0xFC) == 0) pos += 5;
        else if(((c ^ 0xFC) & 0xFE) == 0) pos += 6;
        /* if none match, pos never advances → infinite loop on invalid UTF-8 */
    }
}
```

When `buf[0]` has a **different UTF-8 sequence length** than `buf[pos]`, `pos` advances
by the wrong amount.  This can cause the scan to land in the middle of a multi-byte
sequence, causing `utf8_cjkCodePoint` at the misaligned position to return 0, and the
Traditional Chinese character is never detected or converted.

---

## Worked example: "éa漢"

| Byte offset | 0    | 1    | 2    | 3    | 4    | 5    |
|-------------|------|------|------|------|------|------|
| Byte value  | C3   | A9   | 61   | E6   | BC   | A2   |
| Character   | é (2-byte) | | a (1-byte) | 漢 (3-byte) | | |

With the bug (`c = *cur`):

| Iteration | `pos` | `utf8_cjkCodePoint` returns | `c = *cur` | action |
|-----------|-------|-----------------------------|-----------|--------|
| 1 | 0 | 0 (é, not CJK) | `0xC3` = 2-byte lead | `pos += 2` → pos=2 ✓ |
| 2 | 2 | 0 ('a', not CJK) | `0xC3` ← **WRONG** (reads byte 0 again!) | `pos += 2` → pos=4 ✗ should be +1 |
| 3 | 4 | 0 (byte 0xBC, middle of 漢) | `0xC3` | `pos += 2` → pos=6 = end |

The scan reaches the end without ever reading `0xE6` (the start byte of 漢),
so 漢 is **never converted** and the output is `"éa漢"` instead of `"éa汉"`.

---

## Second example: "𠀀漢𠁐漢" (combined with Bug 001)

After the first 漢 is correctly converted to 汉 (pos advances to 7), the scan
reaches 𠁐 (4-byte, U+20050).  Bug 001 causes `utf8_cjkCodePoint` to return 0
for the 4-byte character, so it falls into the `else` branch.  The bug then reads
`buf[0]` = `0xE6` (first byte of the converted 汉), interprets it as a 3-byte
lead, and advances by 3 instead of 4 — landing in the middle of 𠁐's continuation
bytes.  The second 漢 is never seen as a complete character and is not converted.

Expected: `"𠀀汉𠁐汉"`  
Actual:   `"𠀀汉𠁐漢"` (second 漢 missed)

---

## Fix

Change `*cur` to `*(cur + pos)`:

```c
else{
    unsigned char c = *(cur + pos);   /* ← fix: use current position */
    if(c < 128) pos++;
    else if(((c ^ 0xC0) & 0xE0) == 0) pos += 2;
    else if(((c ^ 0xE0) & 0xF0) == 0) pos += 3;
    else if(((c ^ 0xF0) & 0xF8) == 0) pos += 4;
    else if(((c ^ 0xF8) & 0xFC) == 0) pos += 5;
    else if(((c ^ 0xFC) & 0xFE) == 0) pos += 6;
    else pos++;   /* unrecognised byte — advance 1 to avoid infinite loop */
}
```

The final `else pos++` guard also prevents an infinite loop if invalid UTF-8
reaches this function (a continuation byte 0x80–0xBF matches none of the branches
and would otherwise stall `pos` forever).

---

## Tests that reveal this bug

Added to all CI test scripts (`postgres-11.sh`, `postgres-12.sh`, `postgres-16.sh`,
`postgres-1x.sh`). Both tests confirmed failing before fix and passing after.

```sql
-- Bug 002 alone: 2-byte Latin char before ASCII before Traditional Chinese
-- Expected: éa汉
-- Actual (with bug): éa漢
SELECT prsd2_zht2zhs('éa漢');

-- Bug 001 + 002: 4-byte CJK Ext-B chars interspersed with Traditional Chinese
-- Expected: 𠀀汉𠁐汉
-- Actual (with bugs): 𠀀汉𠁐漢
SELECT prsd2_zht2zhs('𠀀漢𠁐漢');
```
