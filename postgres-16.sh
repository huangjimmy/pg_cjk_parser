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
docker stop postgres16 && docker rm postgres16
