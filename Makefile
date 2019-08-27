MODULES = pg_cjk_parser
EXTENSION = pg_cjk_parser
DATA = pg_cjk_parser--0.0.1.sql
PGXS := $(shell pg_config --pgxs)
include $(PGXS)
