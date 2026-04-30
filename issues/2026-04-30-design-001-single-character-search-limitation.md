# Design 001 — Single-character CJK search limitation and hybrid 1+2-gram option

**Status:** Known limitation. Hybrid mode not yet implemented.

---

## Limitation

The 2-gram tokenizer does not index individual CJK characters. Searching for a
single character returns no results even when that character appears in the text.

Example:

```sql
SELECT to_tsvector('野比大雄') @@ to_tsquery('野');
-- returns false — '野' is not in the tsvector

SELECT to_tsvector('野比大雄') @@ to_tsquery('野比');
-- returns true — '野比' is a 2-gram token
```

Tokens produced for `野比大雄`: `野比`, `比大`, `大雄`.
The final character `雄` is dropped because it is already covered by `大雄`.

This is not a bug — it is the fundamental trade-off of n-gram tokenisation:
no word-segmentation dictionary is needed, but sub-gram queries do not match.

---

## Proposed solution: hybrid 1+2-gram mode

Emit both a unigram and a 2-gram for every CJK character in a sequence:

| Input | 2-gram only (current) | Hybrid 1+2-gram |
|---|---|---|
| `野比大雄` | `野比` `比大` `大雄` | `野` `野比` `比` `比大` `大` `大雄` `雄` |

Queries that would become possible with hybrid mode:

```sql
to_tsquery('野')        -- single char: works
to_tsquery('野比大雄')  -- multi-char phrase: still works (unchanged)
```

### Trade-offs

- Index size approximately doubles.
- Slightly more false positives for short queries (single common characters
  like 大 or 人 appear in many unrelated documents).
- Phrase matching behaviour is unchanged.

### Implementation sketch

`prsd2_nexttoken` calls `TParserGet` once per character and returns one token
per call. To emit both a unigram and a 2-gram for the same character, a
`pending_bigram` flag would be added to `TParser`:

- Call 1 at `野`: return `野` (unigram), save `野比` as pending.
- Call 2 at `野` (flagged): return `野比` (2-gram), clear flag, advance.

Exposure: a separate `prsd2_cjk_nexttoken_hybrid` C function registered as a
second `GETTOKEN` option, so existing parsers using `prsd2_cjk_nexttoken` are
unaffected. Users who want hybrid create their own parser with the hybrid
gettoken function.

A GUC parameter (`pg_cjk_parser.mode = '2gram' | 'hybrid'`) is an alternative
but the separate-function approach is cleaner because it requires no server-wide
configuration and works per text-search configuration.
