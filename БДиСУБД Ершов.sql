DROP FUNCTION IF EXISTS public.get_next_id(TEXT, TEXT);

DROP TABLE IF EXISTS public.test2 CASCADE;
DROP TABLE IF EXISTS public.test CASCADE;
DROP TABLE IF EXISTS public.spec CASCADE;


CREATE TABLE public.spec (
    id BIGINT PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    current_max BIGINT NOT NULL,
    UNIQUE (table_name, column_name)
);



INSERT INTO public.spec
    (id, table_name, column_name, current_max)
VALUES
    (1, 'spec', 'id', 1);



CREATE OR REPLACE FUNCTION public.get_next_id(
    p_table_name TEXT,
    p_column_name TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_table REGCLASS;
    v_max BIGINT;
    v_next BIGINT;
    v_new_id BIGINT;
BEGIN
    IF p_table_name IS NULL OR p_column_name IS NULL THEN
        RAISE EXCEPTION 'Table and column names cannot be NULL';
    END IF;

    v_table := TO_REGCLASS(p_table_name);

    IF v_table IS NULL THEN
        RAISE EXCEPTION 'Table % does not exist', p_table_name;
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_table
          AND attname = p_column_name
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        RAISE EXCEPTION 'Column % does not exist', p_column_name;
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            v_table::TEXT || '.' || p_column_name, 0
        )
    );


    SELECT current_max
    INTO v_next
    FROM public.spec
    WHERE table_name = p_table_name
      AND column_name = p_column_name
    FOR UPDATE;


    IF FOUND THEN

        v_next := v_next + 1;

        UPDATE public.spec
        SET current_max = v_next
        WHERE table_name = p_table_name
          AND column_name = p_column_name;

        RETURN v_next;

    END IF;


    EXECUTE FORMAT(
        'SELECT MAX(%I)::BIGINT FROM %s',
        p_column_name,
        v_table
    )
    INTO v_max;

    v_next := COALESCE(v_max, 0) + 1;

    v_new_id := public.get_next_id('spec', 'id');

    INSERT INTO public.spec (
        id,
        table_name,
        column_name,
        current_max
    )
    VALUES (
        v_new_id,
        p_table_name,
        p_column_name,
        v_next
    );

    RETURN v_next;

END;
$$;





SELECT public.get_next_id('spec', 'id');

SELECT * FROM public.spec ORDER BY id;

SELECT public.get_next_id('spec', 'id');

SELECT * FROM public.spec ORDER BY id;





CREATE TABLE public.test (
    id INTEGER
);

INSERT INTO public.test (id)
VALUES (10);


SELECT public.get_next_id('test', 'id');


SELECT * FROM public.spec ORDER BY id;


SELECT public.get_next_id('test', 'id');


SELECT * FROM public.spec ORDER BY id;


CREATE TABLE public.test2 (
    num_value1 INTEGER,
    num_value2 INTEGER
);



SELECT public.get_next_id('test2', 'num_value1');


SELECT * FROM public.spec ORDER BY id;


SELECT public.get_next_id('test2', 'num_value1');


SELECT * FROM public.spec ORDER BY id;


INSERT INTO public.test2 (num_value1, num_value2)
VALUES (2, 13);



SELECT public.get_next_id('test2', 'num_value2');

SELECT * FROM public.spec ORDER BY id;



SELECT public.get_next_id('test2', 'num_value1');
SELECT public.get_next_id('test2', 'num_value1');
SELECT public.get_next_id('test2', 'num_value1');
SELECT public.get_next_id('test2', 'num_value1');
SELECT public.get_next_id('test2', 'num_value1');


SELECT * FROM public.spec ORDER BY id;
