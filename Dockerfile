ARG POSTGRES_VERSION=16
FROM postgres:$POSTGRES_VERSION as build
ARG POSTGRES_VERSION=16
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-server-dev-$POSTGRES_VERSION gcc make icu-devtools libicu-dev

RUN mkdir -p /root/parser
WORKDIR /root/parser
COPY pg_cjk_parser.c /root/parser/
COPY pg_cjk_parser.control /root/parser/
COPY Makefile /root/parser/
COPY pg_cjk_parser--0.0.1.sql /root/parser/
COPY zht2zhs.h /root/parser/
RUN make clean && make install

FROM postgres:$POSTGRES_VERSION
ARG POSTGRES_VERSION=16
COPY --from=build /root/parser/pg_cjk_parser.bc /usr/lib/postgresql/$POSTGRES_VERSION/lib/bitcode
COPY --from=build /root/parser/pg_cjk_parser.so /usr/lib/postgresql/$POSTGRES_VERSION/lib
COPY --from=build /root/parser/pg_cjk_parser--0.0.1.sql /usr/share/postgresql/$POSTGRES_VERSION/extension
COPY --from=build /root/parser/pg_cjk_parser.control /usr/share/postgresql/$POSTGRES_VERSION/extension
