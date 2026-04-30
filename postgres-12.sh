#!/bin/bash
	
docker run --name postgres12 -e POSTGRES_PASSWORD=password -d postgres:12-dev
sleep 5
OUTPUT=$(docker exec postgres12 psql -U postgres -c 'CREATE EXTENSION pg_cjk_parser;')
echo $OUTPUT
if [[ "$OUTPUT" != "CREATE EXTENSION" ]];
then
    docker stop postgres12 && docker rm postgres12
    exit 1
fi
docker exec postgres12 psql -U postgres -c "CREATE TEXT SEARCH PARSER public.pg_cjk_parser (START = prsd2_cjk_start, GETTOKEN = prsd2_cjk_nexttoken, END = prsd2_cjk_end, LEXTYPES = prsd2_cjk_lextype, HEADLINE = prsd2_cjk_headline); CREATE TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ( PARSER = pg_cjk_parser ); SET default_text_search_config = 'public.config_2_gram_cjk';"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR asciihword WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR cjk WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR email WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR asciiword WITH english_stem;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR entity WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR file WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR float WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR host WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword_asciipart WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword_numpart WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR hword_part WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR int WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR numhword WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR numword WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR protocol WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR sfloat WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR tag WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR uint WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR url WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR url_path WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR version WITH simple;"

docker exec postgres12 psql -U postgres -c "ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk ADD MAPPING FOR word WITH simple;"

OUTPUT=$(docker exec postgres12 psql -U postgres -c "SET default_text_search_config = 'public.config_2_gram_cjk'; SELECT to_tsvector('Doraemnon Nobita「ドラえもん のび太の牧場物語」多拉A梦 野比大雄χΨψΩω'), to_tsquery('のび太'), to_tsquery('野比大雄');")
echo $OUTPUT
if [[ "$OUTPUT" != *"| 'のび' & 'び太' | '野比' & '比大' & '大雄'"* ]];
then
    echo "Chinese/Japanese not splitted into 2-grams"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

OUTPUT=$(docker exec postgres12 psql -U postgres -c "SET default_text_search_config = 'public.config_2_gram_cjk'; SELECT to_tsvector('大韩民国개인정보의 수집 및 이용 목적(「개인정보 보호법」 제15조)'), to_tsquery('「大韩民国개인정보');")
echo $OUTPUT
if [[ "$OUTPUT" != *"'「' & '大韩' & '韩民' & '民国' & '国개' & '개인' & '인정' & '정보'"* ]];
then
    echo "Korean not splitted into 2-grams"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

# --- cjk_zht2zhs regression tests ---

# Basic sanity: pure Traditional Chinese string
OUTPUT=$(docker exec postgres12 psql -U postgres -c "SELECT cjk_zht2zhs('漢語');")
echo $OUTPUT
if [[ "$OUTPUT" != *"汉语"* ]];
then
    echo "cjk_zht2zhs: basic Traditional->Simplified conversion failed"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

# Bug 002: 2-byte Latin char (é) at position 0 followed by ASCII then Traditional Chinese.
# The else branch reads *cur (byte 0) instead of *(cur+pos), causing 'a' to advance by 2
# instead of 1, landing the scan in the middle of 漢 and missing the conversion entirely.
# Expected: éa汉   Actual with bug: éa漢
OUTPUT=$(docker exec postgres12 psql -U postgres -c "SELECT cjk_zht2zhs('éa漢');")
echo $OUTPUT
if [[ "$OUTPUT" != *"éa汉"* ]];
then
    echo "cjk_zht2zhs Bug 002: conversion missed after mixed-length UTF-8 prefix (see issues/2026-04-30-bug-002-cjk_zht2zhs-wrong-pointer.md)"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

# Test utf8_setCjkCodePoint is not a silent no-op:
# if it silently did nothing, Traditional Chinese input would be returned unchanged
OUTPUT=$(docker exec postgres12 psql -U postgres -c "SELECT cjk_zht2zhs('漢') != '漢';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]];
then
    echo "cjk_zht2zhs: utf8_setCjkCodePoint appears to be a silent no-op"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

# Bug 001 + 002: 4-byte CJK Ext-B characters interspersed with Traditional Chinese.
# Bug 001 (missing return in utf8_cjkCodePoint) causes 𠁐 to return 0 and fall to else.
# Bug 002 then reads *cur (0xE6, 3-byte lead of 汉) instead of *(cur+pos) (0xF0, 4-byte
# lead of 𠁐), advancing by 3 instead of 4 and misaligning the scan past the second 漢.
# Expected: 𠀀汉𠁐汉   Actual with bugs: 𠀀汉𠁐漢
OUTPUT=$(docker exec postgres12 psql -U postgres -c "SELECT cjk_zht2zhs('𠀀漢𠁐漢');")
echo $OUTPUT
if [[ "$OUTPUT" != *"𠀀汉𠁐汉"* ]];
then
    echo "cjk_zht2zhs Bug 001+002: conversion missed after 4-byte CJK character (see issues/2026-04-30-bug-001-utf8_cjkCodePoint-missing-return.md)"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi


# Test utf8_setCjkCodePoint is not a silent no-op:
# if it silently did nothing, Traditional Chinese input would be returned unchanged
OUTPUT=$(docker exec postgres12 psql -U postgres -c "SELECT cjk_zht2zhs('漢') != '漢';")
echo $OUTPUT
if [[ "$OUTPUT" != *"t"* ]];
then
    echo "cjk_zht2zhs: utf8_setCjkCodePoint appears to be a silent no-op"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

# Test upgrade path: ALTER EXTENSION UPDATE must succeed (requires upgrade SQL script in image)
OUTPUT=$(docker exec postgres12 psql -U postgres -c "ALTER EXTENSION pg_cjk_parser UPDATE TO '0.1.0';")
echo $OUTPUT
if [[ "$OUTPUT" != "ALTER EXTENSION" ]];
then
    echo "ALTER EXTENSION pg_cjk_parser UPDATE failed — upgrade SQL script missing from image"
    docker stop postgres12 && docker rm postgres12
    exit 1
fi

docker stop postgres12 && docker rm postgres12
