## Получение информации о базе данных

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
По аналогии с получением размера базы данных размер данных таблицы можно вычислить с помощью соответствующей функции:
```sql
SELECT pg_relation_size('accounts');
```
Функция [pg_relation_size()](https://postgrespro.ru/docs/postgrespro/9.5/functions-admin) возвращает объём, который занимает на диске указанный слой заданной таблицы или индекса.

### Имя самой большой таблицы
Для того, чтобы вывести список таблиц текущей базы данных, отсортированный по размеру таблицы, выполним следующий запрос:
```sql
SELECT relname, relpages FROM pg_class ORDER BY relpages DESC;
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
