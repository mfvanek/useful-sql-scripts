# Index Maintenance
Partially based on [wiki](https://wiki.postgresql.org/wiki/Index_Maintenance) and [this video](https://youtu.be/aaecM4wKdhY)

## Index summary
```sql
SELECT
    pg_class.relname,
    pg_size_pretty(pg_class.reltuples::BIGINT) AS rows_in_bytes,
    pg_class.reltuples AS num_rows,
    COUNT(indexname) AS number_of_indexes,
    CASE WHEN x.is_unique = 1 THEN 'Y'
       ELSE 'N'
    END AS UNIQUE,
    SUM(CASE WHEN number_of_columns = 1 THEN 1
              ELSE 0
            END) AS single_column,
    SUM(CASE WHEN number_of_columns IS NULL THEN 0
             WHEN number_of_columns = 1 THEN 0
             ELSE 1
           END) AS multi_column
FROM pg_namespace 
LEFT OUTER JOIN pg_class ON pg_namespace.oid = pg_class.relnamespace
LEFT OUTER JOIN
       (SELECT indrelid,
           MAX(CAST(indisunique AS INTEGER)) AS is_unique
       FROM pg_index
       GROUP BY indrelid) x
       ON pg_class.oid = x.indrelid
LEFT OUTER JOIN
    ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns FROM pg_index x
           JOIN pg_class c ON c.oid = x.indrelid
           JOIN pg_class ipg ON ipg.oid = x.indexrelid  )
    AS foo
    ON pg_class.relname = foo.ctablename
WHERE 
     pg_namespace.nspname='public'
AND  pg_class.relkind = 'r'
GROUP BY pg_class.relname, pg_class.reltuples, x.is_unique
ORDER BY 2;
```

## Index size/usage statistics
```sql
SELECT
    t.tablename,
    indexname,
    c.reltuples AS num_rows,
    pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
    pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
    CASE WHEN indisunique THEN 'Y'
       ELSE 'N'
    END AS UNIQUE,
    idx_scan AS number_of_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_tables t
LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
LEFT OUTER JOIN
    ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique
        FROM pg_index x
        JOIN pg_class c ON c.oid = x.indrelid
        JOIN pg_class ipg ON ipg.oid = x.indexrelid
        JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid AND psai.schemaname = 'public' )
    AS foo
    ON t.tablename = foo.ctablename
WHERE t.schemaname='public'
ORDER BY 1,2;
```

### Top 10 indexes by size
```sql
SELECT
       c.relname AS table_name,
       ipg.relname AS index_name,
       pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size
FROM pg_index x
JOIN pg_class c ON c.oid = x.indrelid
JOIN pg_class ipg ON ipg.oid = x.indexrelid
JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid AND psai.schemaname = 'public'
ORDER BY pg_relation_size(quote_ident(indexrelname)::text) desc nulls last
LIMIT 10;
```

## Tables without primary keys
```sql
select tablename
from pg_tables
where
      schemaname = 'public' and
      tablename not in (
          select c.conrelid::regclass::text as table_name
          from pg_constraint c
          where contype = 'p') and
      tablename not in ('databasechangelog')
order by tablename;
```

### Detailed information about primary keys
```sql
select c.conrelid::regclass as table_name, string_agg(col.attname, ', ' order by u.attposition) as columns,
       c.conname as constraint_name, pg_get_constraintdef(c.oid) as definition
from pg_constraint c
         join lateral unnest(c.conkey) with ordinality as u(attnum, attposition) on true
         join pg_class t on (c.conrelid = t.oid)
         join pg_attribute col on (col.attrelid = t.oid and col.attnum = u.attnum)
where contype = 'p'
group by c.conrelid, c.conname, c.oid
order by (c.conrelid::regclass)::text, columns;
```

## Missing indexes
```sql
with tables_without_indexes as (
  select
    relname as table_name,
    coalesce(seq_scan, 0) - coalesce(idx_scan, 0) as too_much_seq,
    pg_relation_size(relname::regclass) as table_size,
    coalesce(seq_scan, 0) as seq_scan,
    coalesce(idx_scan, 0) as idx_scan
  from pg_stat_all_tables
  where
      schemaname = 'public' and
      pg_relation_size(relname::regclass) > 10 * 8192 and -- skip small tables
      relname not in ('databasechangelog')
)
select *
from tables_without_indexes
where
    (seq_scan + idx_scan) > 0 and -- table in use
    too_much_seq > 0 -- too much sequential scans
order by too_much_seq desc;
```

## Unused indexes
Нужно быть осторожным в том случае, если вы используете потоковую репликацию.  
Например, readonly-запросы могут всегда выполняться на синхронной реплике.  
И если запустить скрипт на мастере, то вы увидите совсем не то...
По-хорошему, скрипт нужно запускать на всех хостах и брать пересечение полученных результатов.
```sql
with forein_key_indexes as (
  select i.indexrelid
    from pg_constraint c
    join lateral unnest(c.conkey) with ordinality as u(attnum, attposition) on true
    join pg_index i on i.indrelid = c.conrelid and (c.conkey::int[] <@ indkey::int[])
    where c.contype = 'f'
)
select
  psui.relname as table_name,
  psui.indexrelname as index_name,
  pg_relation_size(i.indexrelid) as index_size,
  pg_size_pretty(pg_relation_size(i.indexrelid)) as index_size_pretty,
  psui.idx_scan as index_scans
from pg_stat_user_indexes psui
  join pg_index i on psui.indexrelid = i.indexrelid
where
      psui.schemaname = 'public'::text and
      not i.indisunique and
      i.indexrelid not in (select * from forein_key_indexes) and -- retain indexes on foreign keys
      psui.idx_scan < 50 and
      pg_relation_size(psui.relid) >= 5 * 8192 -- skip small tables
	  and pg_relation_size(psui.indexrelid) >= 5 * 8192 -- skip small indexes
order by psui.relname, pg_relation_size(i.indexrelid) desc
```

## Invalid indexes
Когда индекс создаётся конкурентно, то он может быть физически создан, но оставаться невалидным.  
Причин этому может быть несколько, например, нехватка памяти из-за некорректных значений параметров **maintenance_work_mem** и **temp_file_limit**. Подробности [здесь](https://github.com/mfvanek/useful-sql-scripts/blob/master/performance_optimization/configuration.md#maintenance_work_mem).  
Найти все навалидные индексы можно с помощью запроса:
```sql
select x.indrelid::regclass as table_name, x.indexrelid::regclass as index_name
from pg_index x
join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid and psai.schemaname = 'public'::text
where x.indisvalid = false;
```

### How to fix invalid indexes
1. Drop index and re-create it
2. [Reindex](https://postgrespro.ru/docs/postgresql/10/sql-reindex)
```sql
reindex index i_item_shipment_id;
```
3. [Reindex concurrently](https://postgrespro.ru/docs/postgresql/12/sql-reindex) (from PostgreSQL 12)

## Duplicate indexes

### For totally identical
Типовая ошибка, когда создаётся столбец с UNIQUE CONSTRAINTS, а затем на него вручную создаётся уникальный индекс. См. [документацию](https://www.postgresql.org/docs/10/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS).
```sql
select table_name,
       string_agg('idx=' || idx::text || ', size=' || pg_relation_size(idx), '; ') as indexes
from (
       select x.indexrelid::regclass as idx, x.indrelid::regclass as table_name,
              (x.indrelid::text ||' '|| x.indclass::text ||' '|| x.indkey::text ||' '||
               coalesce(pg_get_expr(x.indexprs, x.indrelid),'')||e' ' ||
               coalesce(pg_get_expr(x.indpred, x.indrelid),'')) as key
       from pg_index x
       join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid
       where psai.schemaname = 'public'::text
     ) sub
group by table_name, key having count(*) > 1
order by table_name, sum(pg_relation_size(idx)) desc;
```

### For intersecting indexes
```sql
select a.indrelid::regclass as table_name,
       'idx=' || a.indexrelid::regclass || ', size=' || pg_relation_size(a.indexrelid) || '; idx=' ||
       b.indexrelid::regclass || ', size=' || pg_relation_size(b.indexrelid) as indexes
from (
    select *, array_to_string(indkey, ' ') as cols from pg_index) as a
    join (select *, array_to_string(indkey, ' ') as cols from pg_index) as b
        on (a.indrelid = b.indrelid and a.indexrelid > b.indexrelid and (
            (a.cols like b.cols||'%' and coalesce(substr(a.cols, length(b.cols)+1, 1), ' ') = ' ') or
            (b.cols like a.cols||'%' and coalesce(substr(b.cols, length(a.cols)+1, 1), ' ') = ' ')))
order by a.indrelid::regclass::text;
```

## Indexes with nulls
```sql
select x.indrelid::regclass as table_name, x.indexrelid::regclass as index_name,
       coalesce(pg_get_expr(x.indpred, x.indrelid),'') as index_predicate,
       string_agg(a.attname, ', ') as nullable_fields,
       pg_relation_size(x.indexrelid) as index_size,
       pg_size_pretty(pg_relation_size(x.indexrelid)) as index_size_pretty
from pg_index x
       join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid and psai.schemaname = 'public'::text
       join pg_attribute a ON a.attrelid = x.indrelid AND a.attnum = any(x.indkey)
where not x.indisunique
  and not a.attnotnull
  and (x.indpred is null or (position(lower(a.attname) in lower(pg_get_expr(x.indpred, x.indrelid))) = 0))
  and pg_relation_size(x.indexrelid) > 10 * 8192 -- skip small indexes
group by x.indrelid, x.indexrelid, x.indpred
order by 1,2;
```

Расширенная версия запроса, которая игнорирует многоколоночные индексы, у которых первый столбец не null
```sql
select x.indrelid::regclass as table_name, x.indexrelid::regclass as index_name,
       coalesce(pg_get_expr(x.indpred, x.indrelid),'') as index_predicate,
       string_agg(a.attname, ', ') as nullable_fields,
       pg_relation_size(x.indexrelid) as index_size,
       pg_size_pretty(pg_relation_size(x.indexrelid)) as index_size_pretty
from pg_index x
         join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid and psai.schemaname = 'public'::text
         join pg_attribute a ON a.attrelid = x.indrelid AND a.attnum = any(x.indkey)
where not x.indisunique
  and not a.attnotnull
  and array_position(x.indkey, a.attnum) = 0 -- only for first segment
  and (x.indpred is null or (position(lower(a.attname) in lower(pg_get_expr(x.indpred, x.indrelid))) = 0))
  and pg_relation_size(x.indexrelid) > 10 * 8192 -- skip small indexes
group by x.indrelid, x.indexrelid, x.indpred
order by 1,2
```

## Indexes on foreign keys
### All foreign keys
```sql
select t.relname as table_name, string_agg(col.attname, ', ' order by u.attposition) as columns,
       c.conname as constraint_name, pg_get_constraintdef(c.oid) as definition,
       i.indexrelid::regclass covered_index_name
from pg_constraint c
       join lateral unnest(c.conkey) with ordinality as u(attnum, attposition) on true
       join pg_class t on t.oid = c.conrelid
       join pg_namespace sch on sch.oid = t.relnamespace
       join pg_attribute col on (col.attrelid = t.oid and col.attnum = u.attnum)
       left join pg_index i on i.indrelid = c.conrelid and (c.conkey::int[] <@ i.indkey::int[]) and (c.conkey::int[] @> i.indkey::int[])
where c.contype = 'f' and sch.nspname = 'public'
group by constraint_name, table_name, definition, covered_index_name
order by table_name;
```

### Foreign keys that are not covered with index
```sql

select c.conrelid::regclass as table_name, string_agg(col.attname, ', ' order by u.attposition) as columns,
       c.conname as constraint_name, pg_get_constraintdef(c.oid) as definition
from pg_constraint c
         join lateral unnest(c.conkey) with ordinality as u(attnum, attposition) on true
         join pg_class t on (c.conrelid = t.oid)
         join pg_attribute col on (col.attrelid = t.oid and col.attnum = u.attnum)
where contype = 'f'
  and not exists (
        select 1 from pg_index
        where indrelid = c.conrelid and
              (c.conkey::int[] <@ indkey::int[]) and -- все поля внешнего ключа должны быть в индексе
              array_position(indkey::int[], (c.conkey::int[])[1]) = 0 -- порядок полей во внешнем ключе и в индексе совпадает
      -- здесь бы нужно проверить порядок следования всех полей, но нам это не нужно, так как у нас нет составных FK
    )
group by c.conrelid, c.conname, c.oid
order by (c.conrelid::regclass)::text, columns;
```
