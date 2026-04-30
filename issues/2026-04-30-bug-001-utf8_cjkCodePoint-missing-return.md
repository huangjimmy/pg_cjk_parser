# Bug 001 — `utf8_cjkCodePoint`: missing `return` for 4-byte UTF-8 sequences

**Status: FIXED** — merged in commit `b62aa51` (PR #13), 2026-04-30

**File:** `pg_cjk_parser.c`  
**Function:** `utf8_cjkCodePoint`  
**Severity:** Medium (code logic is wrong; current practical impact is masked by Bug 002)

---

## Description

`utf8_cjkCodePoint` decodes a UTF-8 sequence and returns its Unicode codepoint.
It handles 3-byte sequences correctly (returns `c`), but the 4-byte branch computes
the codepoint into `c` and then **falls through to `return 0`** instead of returning
the computed value.

```c
/* pg_cjk_parser.c ~line 699 */
if(((c ^ 0xE0) & 0xF0) == 0){
    /* 3-byte sequence — correct */
    a = ((s[0] & 0xF)<<4) | ((s[1]>>2) & 0xF);
    b = ((s[1] & 0x3)<<6) | (s[2] & 0x3f);
    c = ((a<<8) | b);
    return c;          /* ✓ returns */
}
if(((c ^ 0xF0) & 0xF8) == 0){
    /* 4-byte sequence — BROKEN */
    a = ((s[0] & 0x7)<<6) | ((s[1]) & 0x3F);
    b = ((s[2] & 0x3F)<<6) | (s[3] & 0x3F);
    c = ((a<<12) | b);
    /* ✗ missing: return c; */
}

return 0;   /* always reached for 4-byte sequences */
```

4-byte UTF-8 encodes Unicode supplementary characters (U+10000–U+10FFFF).
The relevant CJK ranges are CJK Extension B (U+20000–U+2A6DF) through
Extension F and the Compatibility Ideographs Supplement.

## Current practical impact

`utf8_cjkCodePoint` is called only inside `prsd2_zht2zhs`.  The Traditional-to-Simplified
conversion table covers codepoints U+346F–U+9FD3, all of which are BMP characters encoded
as **3-byte** UTF-8.  A 4-byte codepoint (U+10000+) would never match that range, so
returning 0 instead of the real value does not change which characters get converted.

However, returning the wrong value (0) causes every 4-byte character to fall into the
`else` branch that advances `pos` — and that branch has **Bug 002** (wrong pointer).
The combination of both bugs causes subsequent Traditional Chinese characters to be
**skipped** after a 4-byte CJK character appears earlier in the string.

See **Bug 002** for the test case that demonstrates the combined failure.

## Fix

Add `return c;` before the closing brace of the 4-byte branch:

```c
if(((c ^ 0xF0) & 0xF8) == 0){
    a = ((s[0] & 0x7)<<6) | ((s[1]) & 0x3F);
    b = ((s[2] & 0x3F)<<6) | (s[3] & 0x3F);
    c = ((a<<12) | b);
    return c;   /* ← add this */
}
```

## Test that reveals this bug (in combination with Bug 002)

```sql
-- Input:  𠀀漢𠁐漢
--         ^   ^   ^   ^
--         |   |   |   Traditional Chinese (U+6F22) — should convert to 汉
--         |   |   4-byte CJK Ext-B (U+20050)
--         |   Traditional Chinese (U+6F22) — should convert to 汉
--         4-byte CJK Ext-B (U+20000)
--
-- Expected: 𠀀汉𠁐汉
-- Actual (with both bugs): 𠀀汉𠁐漢  (second 漢 not converted)

SELECT prsd2_zht2zhs('𠀀漢𠁐漢');
```

Regression test added to all CI scripts (`postgres-11/12/16/1x.sh`). Confirmed failing before fix and passing after.
