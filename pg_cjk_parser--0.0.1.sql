--
--
\echo Use "CREATE EXTENSION pg_cjk_parser" to load this file. \quit

CREATE FUNCTION public.prsd2_cjk_start(IN internal, IN integer)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS 'MODULE_PATHNAME', 'prsd2_start'
;


CREATE FUNCTION public.prsd2_cjk_nexttoken(IN internal, IN internal, IN internal)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS 'MODULE_PATHNAME', 'prsd2_nexttoken'
;

	
CREATE FUNCTION public.prsd2_cjk_end(IN internal)
    RETURNS void
    LANGUAGE 'c' STRICT
    
AS 'MODULE_PATHNAME', 'prsd2_end'
;

CREATE FUNCTION public.prsd2_cjk_lextype(IN internal)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS 'MODULE_PATHNAME', 'prsd2_lextype'
;

CREATE FUNCTION public.prsd2_cjk_headline(IN internal, IN internal, IN tsquery)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS 'MODULE_PATHNAME', 'prsd2_headline'
;

CREATE FUNCTION public.cjk_zht2zhs(IN internal, IN internal, IN tsquery)
    RETURNS internal
    LANGUAGE 'c' STRICT
    
AS 'MODULE_PATHNAME', 'prsd2_zht2zhs'
;