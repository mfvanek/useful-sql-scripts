-- select * from pg_stat_all_indexes where schemaname <> 'pg_catalog' and indexrelname like 'idx_ref%';
-- select * from pg_indexes where schemaname <> 'pg_catalog' and indexname like 'idx_ref%';

select
  t.tablename,
  indexname,
  c.reltuples::bigint AS num_rows,
  pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
  pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
  case when indisunique then 'YES' else 'NO' end as unique_idx
from pg_tables t
left join pg_class c on t.tablename=c.relname
left join (
    select c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
    JOIN pg_class c ON c.oid = x.indrelid
    JOIN pg_class ipg ON ipg.oid = x.indexrelid
    JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid AND psai.schemaname = 'public'
) as foo on t.tablename = foo.ctablename
where t.schemaname='public'
and indexname like 'idx_ref%'
order by 1,2;
								  
-- select * from pg_catalog.pg_stats where tablename = 'test' and null_frac > 0; -- null values exist