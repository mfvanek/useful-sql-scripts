# De-duplication of B-tree indexes in PostgreSQL 13

## Run PostgreSQL 13.2 in Docker
```
docker run --name postgres-13 -e POSTGRES_USER=testuser -e POSTGRES_PASSWORD=testpwd -e POSTGRES_DB=testdb -d -p 5432:5432 -v /absolute/path/to/initdb.sql:/docker-entrypoint-initdb.d/initdb.sql postgres:13.2
```

## Run PostgreSQL 12.6 in Docker
```
docker run --name postgres-12 -e POSTGRES_USER=testuser -e POSTGRES_PASSWORD=testpwd -e POSTGRES_DB=testdb -d -p 6432:5432 -v /absolute/path/to/initdb.sql:/docker-entrypoint-initdb.d/initdb.sql postgres:12.6
```

## Run psql from Docker CLI
```
psql -U testuser -d testdb
```

## Get indexes size
```sql
select
  x.indrelid::regclass as table_name,
  x.indexrelid::regclass as index_name,
  pg_size_pretty(pg_relation_size(x.indexrelid)) as index_size
from pg_index x
join pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid and psai.schemaname = 'public'
order by 1,2;
```

### PostgreSQL 12 results
|table_name |        index_name         | index_size
|-----------|---------------------------|------------
|test       | test_pkey                 | 2208 kB
|test       | i_test_fld_with_nulls     | 3552 kB
|test       | i_test_fld_without_nulls  | 2456 kB
|test       | i_test_mark_with_nulls    | 2664 kB
|test       | i_test_mark_without_nulls | 1568 kB
|test       | i_test_nil_with_nulls     | 2224 kB
|test       | i_test_nil_without_nulls  | 8192 bytes

### PostgreSQL 13 results
|table_name |        index_name         | index_size
|-----------|---------------------------|------------
|test       | test_pkey                 | 2208 kB
|test       | i_test_fld_with_nulls     | 704 kB
|test       | i_test_fld_without_nulls  | 368 kB
|test       | i_test_mark_with_nulls    | 696 kB
|test       | i_test_mark_without_nulls | 360 kB
|test       | i_test_nil_with_nulls     | 696 kB
|test       | i_test_nil_without_nulls  | 8192 bytes
