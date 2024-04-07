# Indexes with\without null values

By default, PostgreSQL indexes the null values and stores them to the generated index.  
In that way, we need to exclude the null values explicitly from the index
in order to decrease index size and increase write performance.

## Documentation

### RUS

- [create index](https://postgrespro.ru/docs/postgresql/16/sql-createindex)
- [pg_stats](https://postgrespro.ru/docs/postgresql/16/view-pg-stats)

### ENG

- [create index](https://www.postgresql.org/docs/16/sql-createindex.html)
- [pg_stats](https://www.postgresql.org/docs/16/view-pg-stats.html)
-

## Example

|   | tablename | indexname             | num_rows | table_size | index_size | unique_idx |
|---|-----------|-----------------------|----------|------------|------------|------------|
| 1 | test      | idx_ref_with_nulls    | 1000000  | 46 MB      | 55 MB      | NO         |
| 2 | test      | idx_ref_without_nulls | 1000000  | 46 MB      | 19 MB      | NO         |
