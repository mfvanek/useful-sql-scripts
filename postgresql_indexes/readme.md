# Indexes with\without null values
By default, PostgreSQL indexes null values and stores them to the generated index.  
In that way, we need to exclude null values explicitly from the index in order to decrease index size and increase write performance.

## Documentation
- [Create index](https://postgrespro.ru/docs/postgrespro/11/sql-createindex)
- [pg_stats](https://postgrespro.ru/docs/postgresql/11/view-pg-stats)

## Example
|   | tablename | indexname             | num_rows | table_size | index_size | unique_idx |
|---|-----------|-----------------------|----------|------------|------------|------------|
| 1 | test      | idx_ref_with_nulls    | 1000000  | 46 MB      | 55 MB      | NO         |
| 2 | test      | idx_ref_without_nulls | 1000000  | 46 MB      | 19 MB      | NO         |
