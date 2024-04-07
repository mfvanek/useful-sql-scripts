## Getting information about PostgreSQL database

### Replication status, list of replicas (synchronous\asynchronous)

```sql
select * from pg_stat_replication;
```

### Determines the state of the host (primary/secondary)

```sql
select
    not pg_is_in_recovery(),
    (
        case when pg_is_in_recovery()
        then coalesce((extract(epoch from now() - pg_last_xact_replay_timestamp()) * 1000)::integer, 0)
        else 0 end
    )
```

`pg_is_in_recovery()` returns:
- **false** on primary host and
- **true** on replicas.

### Replication lag (Отставание реплики)

```sql
select pg_wal_lsn_diff(pg_current_wal_lsn(),restart_lsn) as lag_in_bytes, slot_name, slot_type
from pg_replication_slots
where active;
```

### Database size (Размер базы данных)

To get the physical size of the database files (storage), use the following query:

```sql
select pg_database_size(current_database());
```

The result will be represented as a number of the form **41809016**.  
[current_database()](https://www.postgresql.org/docs/16/functions-info.html)
— a function that returns the name of the current database.

Instead, you can enter the name explicitly:

```sql
select pg_database_size('my_database');
```

In order to get information in human-readable form, we use the function
[pg_size_pretty()](https://www.postgresql.org/docs/16/functions-admin.html#FUNCTIONS-ADMIN-DBOBJECT):

```sql
select pg_size_pretty(pg_database_size(current_database()));
```

As a result, we get information like **40 Mb**.

#### Databases size for entire cluster

```sql
select pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) as size from pg_database;
```

### Перечень таблиц
Иногда требуется получить перечень таблиц базы данных. Для этого используем следующий запрос:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','pg_catalog');
```
[information_schema](https://www.postgresql.org/docs/9.5/information-schema.html) — стандартная схема базы данных, которая содержит коллекции представлений (views), таких как таблицы, поля и т.д.  
Представления таблиц содержат информацию обо всех таблицах баз данных.

Запрос, описанный ниже, выберет все таблицы из указанной схемы текущей базы данных:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
AND table_schema IN('public', 'myschema');
```
В последнем условии `IN` можно указать имя определенной схемы.

### Размер таблицы
```sql
select table_name,
       pg_size_pretty(total_size) as total_size,
       pg_size_pretty(table_size) as table_size,
       pg_size_pretty(indexes_size) as indexes_size,
       pg_size_pretty(toast_size) as toast_size
from (
    select c.oid::regclass as table_name,
        pg_total_relation_size(c.oid) as total_size,
        pg_table_size(c.oid) as table_size,
        pg_indexes_size(c.oid) as indexes_size,
        coalesce(pg_total_relation_size(c.reltoastrelid), 0) as toast_size
    from pg_class c
             left join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'r'
      and n.nspname = 'public'::text
    order by c.relname::text
) as tables;

```
Функция [pg_relation_size()](https://postgrespro.ru/docs/postgrespro/9.5/functions-admin) возвращает объём, который занимает на диске указанный слой заданной таблицы или индекса.

```sql
select pg_size_pretty(pg_total_relation_size('public.order_item'));
```

### Имя самой большой таблицы
Для того, чтобы вывести список таблиц текущей базы данных, отсортированный по размеру таблицы, выполним следующий запрос:
```sql
select
    coalesce(t.spcname, 'pg_default') as tablespace,
    n.nspname ||'.'||c.relname as table,
    (select count(*) from pg_index i where i.indrelid=c.oid) as index_count,
    pg_size_pretty(pg_relation_size(c.oid)) as t_size,
    pg_size_pretty(pg_indexes_size(c.oid)) as i_size
from pg_class c
         join pg_namespace n on c.relnamespace = n.oid
         left join pg_tablespace t on c.reltablespace = t.oid
where c.reltype != 0 and n.nspname = 'public'
order by (pg_relation_size(c.oid),pg_indexes_size(c.oid)) desc;
```
Для того, чтобы вывести информацию о самой большой таблице, ограничим запрос с помощью `LIMIT`:
```sql
SELECT relname, relpages FROM pg_class ORDER BY relpages DESC LIMIT 1;
```
- **relname** — имя таблицы, индекса, представления и т.п.
- **relpages** — размер представления этой таблицы на диске в количествах страниц (по умолчанию одна страницы равна 8 Кб).
- **pg_class** — системная таблица, которая содержит информацию о связях таблиц базы данных.

### List of connected users (Перечень подключенных пользователей)

To find out the name, IP and port of the connected users, run the following query:
```sql
select datname,usename,client_addr,client_port from pg_stat_activity;
```

### User activity (Активность пользователя)

To find out the connection activity of a specific user, use the following query:
```sql
select datname from pg_stat_activity where usename = 'devuser';
```

### Connection limit per user

```sql
select rolname, rolconnlimit from pg_roles where rolconnlimit <> -1;
```
See [pg_roles](https://www.postgresql.org/docs/16/view-pg-roles.html)

### Roles hierarchy

```
SELECT r.rolname, r.rolsuper, r.rolinherit,
       r.rolcreaterole, r.rolcreatedb, r.rolcanlogin,
       r.rolconnlimit, r.rolvaliduntil,
       ARRAY(SELECT b.rolname
             FROM pg_catalog.pg_auth_members m
                    JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
             WHERE m.member = r.oid) as memberof
    , pg_catalog.shobj_description(r.oid, 'pg_authid') AS description
    , r.rolreplication
FROM pg_catalog.pg_roles r
ORDER BY 1;
```

### Amount of dead and live tuples

```sql
select relname as objectname, pg_stat_get_live_tuples(c.oid) as livetuples, pg_stat_get_dead_tuples(c.oid) as deadtuples
from pg_class c where relname = 'order_item';
```

```sql
select * from pg_stat_all_tables where relname='order_item';
```

### Columns info

```sql
select table_name,
       c.column_name, c.data_type, coalesce(c.numeric_precision, c.character_maximum_length) as maximum_length, c.numeric_scale
from pg_catalog.pg_statio_all_tables as st
         inner join pg_catalog.pg_description pgd on (pgd.objoid=st.relid)
         right outer join information_schema.columns c on (pgd.objsubid=c.ordinal_position and  c.table_schema=st.schemaname and c.table_name=st.relname)
where table_schema = 'public';
```

### Tables without description

```sql
select psat.relid::regclass::text as table_name,
       psat.schemaname as schema_name
from pg_catalog.pg_stat_all_tables psat
where
    (obj_description(psat.relid) is null or length(trim(obj_description(psat.relid))) = 0)
  and position('flyway_schema_history' in psat.relid::regclass::text) <= 0
and psat.schemaname not in ('information_schema', 'pg_catalog', 'pg_toast')
order by 1;
```

### Columns without description

```sql
select t.oid::regclass::text as table_name,
       col.attname::text as column_name
from pg_catalog.pg_class t
         join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
         join pg_catalog.pg_attribute col on (col.attrelid = t.oid)
where t.relkind = 'r' and
        col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc.*/
        --nsp.nspname = :schema_name_param::text and
        position('flyway_schema_history' in t.oid::regclass::text) <= 0 and
        nsp.nspname not in ('information_schema', 'pg_catalog', 'pg_toast') and
    col_description(t.oid, col.attnum) is null
order by 1, 2;
```

### Index detailed info

```sql
select
    x.indrelid::regclass as table_name,
    x.indexrelid::regclass as index_name,
    x.indisunique as is_unique,
    x.indisvalid as is_valid,
    x.indnatts as columns_count,
    pg_get_indexdef(x.indexrelid) as index_definition
from
    pg_catalog.pg_index x
        join pg_catalog.pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid
where
        psai.schemaname = 'public'::text
and x.indexrelid::regclass::text = 'target_index_name'::text;
```

### Finds objects (e.g. indexes, constraints) that depend on a specific column

```sql
select
    d.classid::regclass as owning_object_type,
    d.objid::regclass as owning_object,
    d.refobjid::regclass as dependent_object,
    a.attname as dependent_column,
    d.deptype -- see https://www.postgresql.org/docs/current/catalog-pg-depend.html
from pg_catalog.pg_depend d
    left join pg_catalog.pg_attribute a on d.refobjid = a.attrelid and d.refobjsubid = a.attnum
where
    refobjid = 'target_table_name'::regclass and
    a.attname = 'target_column_name';
```
