MODULES = pg_cjk_parser
EXTENSION = pg_cjk_parser
DATA = pg_cjk_parser--0.0.1.sql pg_cjk_parser--0.0.1--0.1.0.sql pg_cjk_parser--0.1.0.sql pg_cjk_parser--0.1.0--0.2.0.sql pg_cjk_parser--0.2.0.sql
PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
