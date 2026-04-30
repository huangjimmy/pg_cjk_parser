#!/bin/bash
	
docker run --name postgres16 -e POSTGRES_PASSWORD=password -d postgres:16-dev
sleep 5
OUTPUT=$(docker exec postgres16 psql -U postgres -c 'CREATE EXTENSION pg_cjk_parser;')
echo $OUTPUT
if [[ "$OUTPUT" != "CREATE EXTENSION" ]];
then
    docker stop postgres16 && docker rm postgres16
    exit 1
fi
docker exec postgres16 psql -U postgres -c "CREATE TEXT SEARCH PARSER public.pg_cjk_parser (START = prsd2_cjk_start, GETTOKEN = prsd2_cjk_nexttoken, END = prsd2_cjk_end, LEXTYPES = prsd2_cjk_lextype, HEADLINE = prsd2_cjk_headline); CREATE TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ( PARSER = pg_cjk_parser ); SET default_text_search_config = 'public.config_2_gram_cjk';"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR asciihword WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR cjk WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR email WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR asciiword WITH english_stem;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR entity WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR file WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR float WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR host WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword_asciipart WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword_numpart WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword_part WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR int WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR numhword WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR numword WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR protocol WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR sfloat WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR tag WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR uint WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR url WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR url_path WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR version WITH simple;"

docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR word WITH simple;"
docker exec postgres16 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR emoji WITH simple;"

OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config = 'public.config_2_gram_cjk'; SELECT to_tsvector('Doraemnon Nobita「ドラえもん のび太の牧場物語」多拉A梦 野比大雄χΨψΩω'), to_tsquery('のび太'), to_tsquery('野比大雄');")
echo $OUTPUT
if [[ "$OUTPUT" != *"| 'のび' <-> 'び太' | '野比' <-> '比大' <-> '大雄'"* ]];
then
    echo "Chinese/Japanese not splitted into 2-grams"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi

OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config = 'public.config_2_gram_cjk'; SELECT to_tsvector('大韩民国개인정보의 수집 및 이용 목적(「개인정보 보호법」 제15조)'), to_tsquery('「大韩民国개인정보');")
echo $OUTPUT
if [[ "$OUTPUT" != *"「' <-> '大韩' <-> '韩民' <-> '民国' <-> '国개' <-> '개인' <-> '인정' <-> '정보'"* ]];
then
    echo "Korean not splitted into 2-grams"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi

# --- cjk_zht2zhs regression tests ---

# Basic sanity: pure Traditional Chinese string
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('漢語');")
echo $OUTPUT
if [[ "$OUTPUT" != *"汉语"* ]];
then
    echo "cjk_zht2zhs: basic Traditional->Simplified conversion failed"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi

# Bug 002: 2-byte Latin char (é) at position 0 followed by ASCII then Traditional Chinese.
# The else branch reads *cur (byte 0) instead of *(cur+pos), causing 'a' to advance by 2
# instead of 1, landing the scan in the middle of 漢 and missing the conversion entirely.
# Expected: éa汉   Actual with bug: éa漢
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('éa漢');")
echo $OUTPUT
if [[ "$OUTPUT" != *"éa汉"* ]];
then
    echo "cjk_zht2zhs Bug 002: conversion missed after mixed-length UTF-8 prefix (see issues/2026-04-30-bug-002-cjk_zht2zhs-wrong-pointer.md)"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi

# Test utf8_setCjkCodePoint is not a silent no-op:
# if it silently did nothing, Traditional Chinese input would be returned unchanged
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('漢') != '漢';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]];
then
    echo "cjk_zht2zhs: utf8_setCjkCodePoint appears to be a silent no-op"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi

# Bug 001 + 002: 4-byte CJK Ext-B characters interspersed with Traditional Chinese.
# Bug 001 (missing return in utf8_cjkCodePoint) causes 𠁐 to return 0 and fall to else.
# Bug 002 then reads *cur (0xE6, 3-byte lead of 汉) instead of *(cur+pos) (0xF0, 4-byte
# lead of 𠁐), advancing by 3 instead of 4 and misaligning the scan past the second 漢.
# Expected: 𠀀汉𠁐汉   Actual with bugs: 𠀀汉𠁐漢
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('𠀀漢𠁐漢');")
echo $OUTPUT
if [[ "$OUTPUT" != *"𠀀汉𠁐汉"* ]];
then
    echo "cjk_zht2zhs Bug 001+002: conversion missed after 4-byte CJK character (see issues/2026-04-30-bug-001-utf8_cjkCodePoint-missing-return.md)"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi


# Test utf8_setCjkCodePoint is not a silent no-op:
# if it silently did nothing, Traditional Chinese input would be returned unchanged
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('漢') != '漢';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]];
then
    echo "cjk_zht2zhs: utf8_setCjkCodePoint appears to be a silent no-op"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi

# Test upgrade path: ALTER EXTENSION UPDATE must succeed (requires upgrade SQL script in image)
OUTPUT=$(docker exec postgres16 psql -U postgres -c "ALTER EXTENSION pg_cjk_parser UPDATE TO '0.2.0';")
echo $OUTPUT
if [[ "$OUTPUT" != "ALTER EXTENSION" ]];
then
    echo "ALTER EXTENSION pg_cjk_parser UPDATE failed — upgrade SQL script missing from image"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi


# Test characters with no simplified form are returned unchanged (not errored)
# 一(U+4E00) has no simplified equivalent — zht2zhs maps it to 0.
# Before the fix, calling utf8_setCjkCodePoint with 0 triggered elog(ERROR).
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('一') = '一';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]];
then
    echo "cjk_zht2zhs: character with no simplified form should be returned unchanged"
    docker stop postgres16 && docker rm postgres16
    exit 1
fi


# --- Mixed language and emoji tests ---

# French (2-byte UTF-8) before Traditional Chinese
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('café漢語');")
echo $OUTPUT
if [[ "$OUTPUT" != *"café汉语"* ]]; then
    echo "cjk_zht2zhs: French chars before CJK failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Traditional Chinese around French
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('漢語café漢');")
echo $OUTPUT
if [[ "$OUTPUT" != *"汉语café汉"* ]]; then
    echo "cjk_zht2zhs: French chars between CJK failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Emoji (4-byte) before Traditional Chinese
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('😀漢語');")
echo $OUTPUT
if [[ "$OUTPUT" != *"😀汉语"* ]]; then
    echo "cjk_zht2zhs: emoji before CJK failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Traditional Chinese around emoji
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('漢😀語');")
echo $OUTPUT
if [[ "$OUTPUT" != *"汉😀语"* ]]; then
    echo "cjk_zht2zhs: emoji between CJK failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Pure ASCII must be returned unchanged
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('hello world') = 'hello world';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]]; then
    echo "cjk_zht2zhs: pure ASCII not returned unchanged"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Empty string must not crash
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SELECT cjk_zht2zhs('') = '';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]]; then
    echo "cjk_zht2zhs: empty string failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Single CJK character must emit as unigram (not dropped)
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('你');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'你'"* ]]; then
    echo "tokenizer: single CJK character not emitted as unigram"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Two CJK characters must produce exactly one 2-gram
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('你好');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'你好'"* ]]; then
    echo "tokenizer: two CJK chars did not produce 2-gram"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# English + Chinese: ASCII words and CJK 2-grams coexist
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('hello 你好世界');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'你好'"* ]] || [[ "$OUTPUT" != *"'好世'"* ]] || [[ "$OUTPUT" != *"'世界'"* ]]; then
    echo "tokenizer: English + Chinese mixed tokenization failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# French + Japanese: non-ASCII Latin and CJK coexist
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('café 東京 bonjour');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'東京'"* ]] || [[ "$OUTPUT" != *"'café'"* ]]; then
    echo "tokenizer: French + Japanese mixed tokenization failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# CJK + emoji + CJK: emoji is classified as blank (not indexed by default),
# but CJK 2-grams on both sides must survive
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('你好😀世界');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'你好'"* ]] || [[ "$OUTPUT" != *"'世界'"* ]]; then
    echo "tokenizer: CJK + emoji + CJK tokenization failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# CJK adjacent to ASCII with no spaces
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('abc你好def');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'abc'"* ]] || [[ "$OUTPUT" != *"'你好'"* ]] || [[ "$OUTPUT" != *"'def'"* ]]; then
    echo "tokenizer: CJK adjacent to ASCII (no spaces) failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi


# Emoji is tokenized as its own 'emoji' token type (always unigram, never n-gram)
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('😀');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'😀'"* ]]; then
    echo "tokenizer: emoji not indexed as emoji token type"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Emoji between CJK chars: CJK 2-grams and emoji are all indexed
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('你好😀世界');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'你好'"* ]] || [[ "$OUTPUT" != *"'😀'"* ]] || [[ "$OUTPUT" != *"'世界'"* ]]; then
    echo "tokenizer: CJK + emoji + CJK tokenization failed"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

# Multiple emoji: each is a separate token
OUTPUT=$(docker exec postgres16 psql -U postgres -c "SET default_text_search_config='public.config_2_gram_cjk'; SELECT to_tsvector('😀🔥');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'😀'"* ]] || [[ "$OUTPUT" != *"'🔥'"* ]]; then
    echo "tokenizer: consecutive emoji not tokenized as separate tokens"
    docker stop postgres16 && docker rm postgres16; exit 1
fi

docker stop postgres16 && docker rm postgres16
