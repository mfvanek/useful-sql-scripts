## Получение информации о базе данных

### Состояние репликации, список реплик (сихронных\асинхронных)
```sql
select * from pg_stat_replication;
```

### Определить состояние хоста
```sql
SELECT
    NOT pg_is_in_recovery(),
    (
        CASE WHEN pg_is_in_recovery()
        THEN COALESCE((EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp()) * 1000)::INTEGER, 0)
        ELSE 0 END
    )
```
```pg_is_in_recovery()``` - возвращает false на мастере и true - на репликах.
```now() - pg_last_xact_replay_timestamp()``` - возвращает разницу между текущим временем и меткой последней проигранной транзакции.

### Размер базы данных

Чтобы получить физический размер файлов (хранилища) базы данных, используем следующий запрос:
```sql
SELECT pg_database_size(current_database());
```
Результат будет представлен как число вида **41809016**.  
[current_database()](https://postgrespro.ru/docs/postgrespro/9.5/functions-info) — функция, которая возвращает имя текущей базы данных.  

Вместо неё можно ввести имя текстом:
```sql
SELECT pg_database_size('my_database');
```

Для того, чтобы получить информацию в человекочитаемом виде, используем функцию [pg_size_pretty](https://postgrespro.ru/docs/postgrespro/9.5/functions-admin):
```sql
SELECT pg_size_pretty(pg_database_size(current_database()));
```
В результате получим информацию вида **40 Mb**.

#### Для всех баз данных
```sql
SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;
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

### Перечень подключенных пользователей
Чтобы узнать имя, IP и используемый порт подключенных пользователей, выполним следующий запрос:
```sql
SELECT datname,usename,client_addr,client_port FROM pg_stat_activity;
```

### Активность пользователя
Чтобы узнать активность соединения конкретного пользователя, используем следующий запрос:
```sql
SELECT datname FROM pg_stat_activity WHERE usename = 'devuser';
```

### Connection limit per user
```sql
select rolname, rolconnlimit from pg_roles where rolconnlimit <> -1;
```
See [pg_roles](https://postgrespro.ru/docs/postgrespro/10/view-pg-roles)

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
