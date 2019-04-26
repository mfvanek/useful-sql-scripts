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

## Unused indexes
Нужно быть осторожным в том случае, если вы используете потоковую репликацию.  
Например, readonly-запросы могут всегда выполняться на синхронной реплике.  
И если запустить скрипт на мастере, то вы увидите совсем не то...
По-хорошему, скрипт нужно запускать на всех хостах и брать пересечение полученных результатов.
```sql
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
  psui.idx_scan < 50 and
  pg_relation_size(psui.relid) >= 5 * 8192 -- skip small tables
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
1. Drop index and recreate it
2. [Reindex](https://postgrespro.ru/docs/postgresql/9.6/sql-reindex)
```sql
reindex index i_item_shipment_id;
```

## Duplicate indexes

### For totally identical
Типовая ошибка, когда создаётся столбец с UNIQUE CONSTRAINTS, а затем на него вручную создаётся уникальный индекс. См. [документацию](https://www.postgresql.org/docs/10/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS).
```sql
select table_name, pg_size_pretty(sum(pg_relation_size(idx))::bigint) as total_size, string_agg(idx::text, '; ') as index_names,
       (array_agg(idx))[1] as idx1, (array_agg(idx))[2] as idx2,
       (array_agg(idx))[3] as idx3, (array_agg(idx))[4] as idx4
from (
       select x.indexrelid::regclass as idx, x.indrelid::regclass as table_name,
              (x.indrelid::text ||' '|| x.indclass::text ||' '|| x.indkey::text ||' '|| coalesce(pg_get_expr(x.indexprs, x.indrelid),'')||e' ' || coalesce(pg_get_expr(x.indpred, x.indrelid),'')) as key
       from pg_index x
              join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid and psai.schemaname = 'public'::text
     ) sub
group by table_name, key having count(*)>1
order by sum(pg_relation_size(idx)) desc;
```

### For intersecting indexes
```sql
select a.indrelid::regclass as table_name, a.indexrelid::regclass as first_index, b.indexrelid::regclass as second_index,
       pg_relation_size(a.indexrelid) + pg_relation_size(b.indexrelid) as total_size
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

## Indexes with nulls
```sql
select
  pg_index.indrelid::regclass as table,
  pg_index.indexrelid::regclass as index,
  pg_attribute.attname as field,
  pg_statistic.stanullfrac,
  pg_size_pretty(pg_relation_size(pg_index.indexrelid)) as indexsize,
  pg_get_indexdef(pg_index.indexrelid) as indexdef
from pg_index
       join pg_attribute ON pg_attribute.attrelid=pg_index.indrelid AND pg_attribute.attnum=ANY(pg_index.indkey)
       join pg_statistic ON pg_statistic.starelid=pg_index.indrelid AND pg_statistic.staattnum=pg_attribute.attnum
where pg_statistic.stanullfrac>0.5 AND pg_relation_size(pg_index.indexrelid)>10*8192
order by pg_relation_size(pg_index.indexrelid) desc,1,2,3;
```

```
select x.indrelid::regclass as table_name, x.indexrelid::regclass as index_name,
coalesce(pg_get_expr(x.indpred, x.indrelid),'') as index_predicate,
string_agg(a.attname, ', ') as nullable_fields
from pg_index x
join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid and psai.schemaname = 'public'::text
join pg_attribute a ON a.attrelid = x.indrelid AND a.attnum = any(x.indkey)
where not x.indisunique
and not a.attnotnull
and (x.indpred is null or (position(lower(a.attname) in lower(pg_get_expr(x.indpred, x.indrelid))) = 0))
group by x.indrelid, x.indexrelid, x.indpred
order by 1,2
```