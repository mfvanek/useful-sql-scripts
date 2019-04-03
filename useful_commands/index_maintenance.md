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
    ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
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

## Unused indexes
```sql
select
       schemaname || '.' || relname as table_name,
       indexrelname as index_name,
       pg_size_pretty(pg_relation_size(i.indexrelid)) as index_size,
       idx_scan as index_scans
from pg_stat_user_indexes ui
join pg_index i on ui.indexrelid = i.indexrelid
where
      not indisunique and
      idx_scan < 50 and
      pg_relation_size(relid) > 5 * 8192
order by
         pg_relation_size(i.indexrelid) / nullif(idx_scan, 0) desc nulls first,
         pg_relation_size(i.indexrelid) desc
```

## Invalid indexes
Когда индекс создаётся конкурентно, то он может быть физически создан, но оставаться невалидным.  
Причин этому может быть несколько, например, нехватка памяти из-за некоректных значений параметров **maintenance_work_mem** и **temp_file_limit**. Подробности [здесь](https://github.com/mfvanek/useful-sql-scripts/blob/master/performance_optimization/configuration.md#maintenance_work_mem).  
Найти все навалидные индексы можно с помощью запроса:  
```sql
select t.tablename, i.indexname
from pg_tables t
join pg_class c on t.tablename = c.relname
join (
  select c.relname AS ctablename, ipg.relname AS indexname
  from pg_index x
  join pg_class c ON c.oid = x.indrelid
  join pg_class ipg ON ipg.oid = x.indexrelid
  join pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid AND psai.schemaname = 'public'
  where x.indisvalid = false
) as i on t.tablename = i.ctablename;
```

### How to fix invalid indexes
1. Drop index and recreate it
2. [Reindex](https://postgrespro.ru/docs/postgresql/9.6/sql-reindex)
```sql
reindex index i_item_shipment_id;
```

## Duplicate indexes
### For totally identical
Типовая ошибка, когда создаётся столбец с UNIQUE CONSTRAINTS, а затем на него вручную создаётся уникальный индекс. См. [документацию](https://www.postgresql.org/docs/10/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS).
```sql
SELECT pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
       (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2,
       (array_agg(idx))[3] AS idx3, (array_agg(idx))[4] AS idx4
FROM (
       SELECT indexrelid::regclass AS idx, (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
                                            COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
       FROM pg_index) sub
GROUP BY KEY HAVING COUNT(*)>1
ORDER BY SUM(pg_relation_size(idx)) DESC;
```
### For intersecting indexes
```sql
select a.indrelid::regclass as table_name, a.indexrelid::regclass as first_index, b.indexrelid::regclass as second_index
from (select *, array_to_string(indkey, ' ') as cols from pg_index) as a
join (select *, array_to_string(indkey, ' ') as cols from pg_index) as b on
  (a.indrelid = b.indrelid and a.indexrelid > b.indexrelid and
   (
     (a.cols like b.cols||'%' and coalesce(substr(a.cols, length(b.cols)+1, 1), ' ') = ' ') or
     (b.cols like a.cols||'%' and coalesce(substr(b.cols, length(a.cols)+1, 1), ' ') = ' ')
     )
  )
order by a.indrelid;
```
### Version 3
```sql
select ui.relname as table_name, ui.indexrelname as index_name, ui.idx_scan as index_scans,
       pg_size_pretty(pg_relation_size(ui.relid)) as table_size,
       pg_size_pretty(pg_relation_size(ui.indexrelid)) as index_size,
       t.n_tup_upd + t.n_tup_ins + t.n_tup_del as writes,
       i.indexdef as create_command
from pg_stat_user_indexes ui
join pg_indexes i on (i.indexname = ui.indexrelname and ui.schemaname = i.schemaname)
join pg_stat_user_tables t on t.relid = ui.relid
where ui.idx_scan < 50 and i.indexdef !~* 'unique'
order by ui.relname, ui.indexrelname;
```