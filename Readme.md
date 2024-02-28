# Postgres CJK Parser - pg_cjk_parser

Postgres CJK Parser pg_cjk_parser is a fts (full text search) parser derived from the default parser in PostgreSQL. When a postgres database uses utf-8 encoding, this parser supports all the features of the default parser while splitting CJK (Chinese, Japanese, Korean) characters into 2-gram tokens. If the database's encoding is not utf-8, the parser behaves just like the default parser.

Now pg_cjk_parser supports PostgreSQL 12 to 16.

## Introduction

It is not easy for text search parsers to split strings with CJK charatcters into words because in CJK languages, space is not word boundary. PostgreSQL's default parser treats CJK characters as a single word "Word, all letters". This is undesirable for CJK users.

The pg_cjk_parser extends the default parser by splitting CJK into 2-gram tokens while splitting other languages the way the default parser does.

Please note that CJK punctuations are treated as unigram and will not be part of any 2-gram CJK tokens.

```sql
SELECT alias, description, token FROM 
ts_debug('Doraemnon Nobita「ドラえもん のび太の牧場物語」多拉A梦 野比大雄χΨψΩω https://www.doraemon.com/welcome.html');

```

|alias|description|token|
|-|-|-|
|"asciiword"|"Word, all ASCII"|"Doraemnon"|
|"blank"|"Space symbols"|" "|
|"asciiword"|"Word, all ASCII"|"Nobita"|
|"cjk"|"CJK Char"|"「"|
|"cjk"|"CJK Char"|"ドラ"|
|"cjk"|"CJK Char"|"ラえ"|
|"cjk"|"CJK Char"|"えも"|
|"cjk"|"CJK Char"|"もん"|
|"blank"|"Space symbols"|" "|
|"blank"|"Space symbols"|" "|
|"cjk"|"CJK Char"|"のび"|
|"cjk"|"CJK Char"|"び太"|
|"cjk"|"CJK Char"|"太の"|
|"cjk"|"CJK Char"|"の牧"|
|"cjk"|"CJK Char"|"牧場"|
|"cjk"|"CJK Char"|"場物"|
|"cjk"|"CJK Char"|"物語"|
|"blank"|"Space symbols"|" "|
|"cjk"|"CJK Char"|"」"|
|"cjk"|"CJK Char"|"多拉"|
|"blank"|"Space symbols"|" "|
|"asciiword"|"Word, all ASCII"|"A"|
|"cjk"|"CJK Char"|"梦"|
|"blank"|"Space symbols"|" "|
|"cjk"|"CJK Char"|"野比"|
|"cjk"|"CJK Char"|"比大"|
|"cjk"|"CJK Char"|"大雄"|
|"blank"|"Space symbols"|" "|
|"word"|"Word, all letters"|"χΨψΩω"|
|"blank"|"Space symbols"|" "|
|"protocol"|"Protocol head"|"https://"|
|"url"|"URL"|"www.doraemon.com/welcome.html"|
|"host"|"Host"|"www.doraemon.com"|
|"url_path"|"URL path"|"/welcome.html"|

## Build

You can build pg_cjk_parser in a docker container.

1. Clone this repository into your local computer, say in /home/user/pg_cjk_parser
2. Ener /home/user/pg_cjk_parser
3. Build the docker image postgres:12-dev

To build this extension for PostgreSQL 12
```bash
docker build -t postgres:12-dev . --build-arg POSTGRES_VERSION=12 -f Dockerfile_alpine
```

To build this extension for PostgreSQL 16
```bash
docker build -t postgres:16-dev . --build-arg POSTGRES_VERSION=16 -f Dockerfile_alpine
```

To build this extension for PostgreSQL 11
```bash
docker build -t postgres:11-dev . -f Dockerfile_pg11
```

4. Run the following command

```bash
docker run -it --rm -v $(pwd):/root/code postgres:12-dev /bin/bash -c "cd /root/code && make clean && make"
```

Then pg_cjk_parser.bc and pg_cjk_parser.so will be available in current directory (/home/user/pg_cjk_parser). You can manually install the parser to a PostgreSQL instances or you can install it as an extension.

## Installation

You can manually install pg_cjk_parser or you can install it as an extension.

### Install as an extension

Let's say that you have an instance of PostgreSQL 12 running, either on a docker container on a server.
Make sure you have the following dependencies installed.

```bash
# replace 12 with 16 if you build this extension for pg 16
sudo apt-get install -y postgresql-server-dev-12 
sudo apt-get install -y gcc
sudo apt-get install -y icu-devtools libicu-dev
```

If you are using other Linux distrubitions other than debian or ubuntu, you should replace "apt-get install -y" with corresponding commands.

Copy the following files
> pg_cjk_parser.c
> pg_cjk_parser.control
> pg_cjk_parser--0.0.1.sql
> zht2zhs.h
> Makefile

to a directory on the server, say, /home/user/parser/

Run the following command on the server

```bash
cd /home/user/parser
make clean && make install
sudo make USE_PGXS=1 install
```

Connect to your server via pgAdmin or other clients and then execute the following sql to create the pg_cjk_parser extension.

```sql
CREATE EXTENSION pg_cjk_parser;
```

Then you should create a search configuration and make it default.

```sql
CREATE TEXT SEARCH PARSER public.pg_cjk_parser (
    START = prsd2_cjk_start,
    GETTOKEN = prsd2_cjk_nexttoken,
    END = prsd2_cjk_end,
    LEXTYPES = prsd2_cjk_lextype,
    HEADLINE = prsd2_cjk_headline);

CREATE TEXT SEARCH CONFIGURATION public.config_2_gram_cjk (
    PARSER = pg_cjk_parser
);

SET default_text_search_config = 'public.config_2_gram_cjk';
```

Now you can execute the sql demonstrated in the introduction section to see the results.

### Docker image

There is a Dockerfile in this repository which helps you build a docker image based on postgres:12.

```bash
docker build -t postgres:12-dev . --build-arg POSTGRES_VERSION=12 -f Dockerfile_alpine
```

or you can build a docker image based on postgres:16.
```bash
docker build -t postgres:16-dev . --build-arg POSTGRES_VERSION=16 -f Dockerfile_alpine
```

or you can build a docker image based on postgres:11.
```bash
docker build -t postgres:11-dev . -f Dockerfile_pg11
```

If you use this image to start an instance of postgres:12, all you need to do is to create the extension, search parser and configuration in pgAdmin.

Connect to your server via pgAdmin or other clients and then execute the following sql to create the pg_cjk_parser extension.

```sql
CREATE EXTENSION pg_cjk_parser;
```

Then you should create a search configuration and make it default.

```sql
CREATE TEXT SEARCH PARSER public.pg_cjk_parser (
    START = prsd2_cjk_start,
    GETTOKEN = prsd2_cjk_nexttoken,
    END = prsd2_cjk_end,
    LEXTYPES = prsd2_cjk_lextype,
    HEADLINE = prsd2_cjk_headline);

CREATE TEXT SEARCH CONFIGURATION public.config_2_gram_cjk (
    PARSER = pg_cjk_parser
);

SET default_text_search_config = 'public.config_2_gram_cjk';
```

Now you can execute the sql demonstrated in the introduction section to see the results.

### Install manually

Suppose you have an docker instance of postgres name postgres_db_1 whose image is postgres:12.

```bash
docker cp pg_cjk_parser.so postgres_db_1:/usr/lib/postgresql/12/lib/
```

Connect to the postgres instance via pgAdmin or other clients and then execute the following sql

```sql
CREATE FUNCTION public.prsd2_cjk_nexttoken(IN internal, IN internal, IN internal)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS '$libdir/pg_cjk_parser.so', 'prsd2_nexttoken'
;

	
CREATE FUNCTION public.prsd2_cjk_end(IN internal)
    RETURNS void
    LANGUAGE 'c' STRICT
    
AS '$libdir/pg_cjk_parser.so', 'prsd2_end'
;

CREATE FUNCTION public.prsd2_cjk_lextype(IN internal)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS '$libdir/pg_cjk_parser.so', 'prsd2_lextype'
;

	
CREATE FUNCTION public.prsd2_cjk_headline(IN internal, IN internal, IN tsquery)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS '$libdir/pg_cjk_parser.so', 'prsd2_headline'
;
```

Then you should create a search configuration and make it default.

```sql
CREATE TEXT SEARCH PARSER public.pg_cjk_parser (
    START = prsd2_cjk_start,
    GETTOKEN = prsd2_cjk_nexttoken,
    END = prsd2_cjk_end,
    LEXTYPES = prsd2_cjk_lextype,
    HEADLINE = prsd2_cjk_headline);

CREATE TEXT SEARCH CONFIGURATION public.config_2_gram_cjk (
    PARSER = pg_cjk_parser
);

SET default_text_search_config = 'public.config_2_gram_cjk';
```

Now you can execute the sql demonstrated in the introduction section to see the results.

### Search Configuration dictionary mappings

```sql
ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR asciihword
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR cjk
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR email
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR asciiword
    WITH english_stem;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR entity
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR file
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR float
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR host
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR hword
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR hword_asciipart
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR hword_numpart
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR hword_part
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR int
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR numhword
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR numword
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR protocol
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR sfloat
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR tag
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR uint
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR url
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR url_path
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.config_2_gram_cjk
    ADD MAPPING FOR word
    WITH simple;
```

Now you can use to_tsvector and to_tsquery to test the newly created search configuration.

```sql
SELECT to_tsvector('Doraemnon Nobita「ドラえもん のび太の牧場物語」多拉A梦 野比大雄χΨψΩω'), to_tsquery('のび太'), 
to_tsquery('野比大雄'),
to_tsvector('Doraemnon Nobita「ドラえもん のび太の牧場物語」多拉A梦 野比大雄χΨψΩω') @@ to_tsquery('のび太'),
to_tsvector('Doraemnon Nobita「ドラえもん のび太の牧場物語」多拉A梦 野比大雄χΨψΩω') @@ to_tsquery('野比大雄');
```

|to_tsvector|to_tsquery|to_tsquery|?boolean?|?boolean?|
|-|-|-|-|-|
|'doraemnon':1 'nobita':2 'χψψωω':22 '「':3 '」':15 'えも':6 'のび':8 'の牧':11 'び太':9 'もん':7 'ドラ':4 'ラえ':5 '場物':13 '多拉':16 '大雄':21 '太の':10 '梦':18 '比大':20 '牧場':12 '物語':14 '野比':19|"'のび' & 'び太'"|"'野比' & '比大' & '大雄'"|true|true|

```sql
SELECT to_tsvector('大韩民国개인정보의 수집 및 이용 목적(「개인정보 보호법」 제15조)'), to_tsquery('「大韩民国개인정보');
```

|to_tsvector|to_tsquery|
|-|-|
| '15':21 '「':13 '」':19 '国개':4 '大韩':1 '民国':3 '韩民':2 '개인':5,14 '목적':12 '및':10 '보의':8 '보호':17 '수집':9 '이용':11 '인정':6,15 '정보':7,16 '제':20 '조':22 '호법':18|'「' & '大韩' & '韩民' & '民国' & '国개' & '개인' & '인정' & '정보'|

## License

### PG CJK Parser

PG_CJK Parser is a derived work based on PostgreSQL source code 'src/backend/tsearch/wparser_def.c'.
The license of this derived work is the same as that of PostgreSQL source code.

### PostgreSQL

PostgreSQL Database Management System
(formerly known as Postgres, then as Postgres95)

Portions Copyright (c) 1996-2019, PostgreSQL Global Development Group

Portions Copyright (c) 1994, The Regents of the University of California

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose, without fee, and without a written agreement
is hereby granted, provided that the above copyright notice and this
paragraph and the following two paragraphs appear in all copies.

IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

### PostgreSQL Docker

Copyright (c) 2014, Docker PostgreSQL Authors (See AUTHORS)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
