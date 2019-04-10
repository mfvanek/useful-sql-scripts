# Оптимизация производительности PostgreSQL

Ниже перечислены основные параметры, на  которые следует обратить внимание при оптимизации производительности PostgreSQL.

## Документация
- [На русском](https://postgrespro.ru/docs/postgrespro/10/runtime-config-resource)
- [На английском](https://www.postgresql.org/docs/10/runtime-config-resource.html)

### shared_buffers
Если вы используете выделенный сервер с объёмом ОЗУ 1 ГБ и более, разумным начальным значением **shared_buffers** будет 25% от объёма памяти.  
При увеличении **shared_buffers** обычно требуется соответственно увеличить **max_wal_size**, чтобы растянуть процесс записи большого объёма новых или изменённых данных на более продолжительное время.
```sql
show shared_buffers;
show max_wal_size;
```

### work_mem
Задаёт объём памяти, который будет использоваться для внутренних операций сортировки и хеш-таблиц, прежде чем будут задействованы временные файлы на диске.  
Операции сортировки используются для ORDER BY, DISTINCT и соединений слиянием. Хеш-таблицы используются при соединениях и агрегировании по хешу, а также обработке подзапросов IN с применением хеша.  
Значение по умолчанию — четыре мегабайта (4MB).  
Оценить необходимое значение для **work_mem** можно разделив объём доступной памяти (физическая память минус объём занятый под другие программы и под совместно используемые страницы shared_buffers) на максимальное число одновременно используемых активных соединений.  
Другой подход: start **work_mem** small at say 16 MB and gradually increase **work_mem** when see **temporary file**.  
```sql
show work_mem;
```

[См.](https://www.citusdata.com/blog/2018/06/12/configuring-work-mem-on-postgres/)
[См. также](https://www.depesz.com/2011/07/03/understanding-postgresql-conf-work_mem/)

### maintenance_work_mem
Задаёт максимальный объём памяти для операций обслуживания БД, в частности VACUUM, CREATE INDEX и ALTER TABLE ADD FOREIGN KEY.  
По умолчанию его значение — 64 мегабайта (64MB).
```sql
show maintenance_work_mem;
show autovacuum_work_mem;
show autovacuum_max_workers;
-- set maintenance_work_mem = '256MB';
```

#### Рекомендации Amazon
See [link](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.html).  
In general terms, for large hosts set the maintenance_work_mem parameter to a value between one and two gigabytes (between 1,048,576 and 2,097,152 KB). For extremely large hosts, set the parameter to a value between two and four gigabytes (between 2,097,152 and 4,194,304 KB).
```sql
set maintenance_work_mem='2 GB';
```

### temp_file_limit
Задаёт максимальный объём дискового пространства, который сможет использовать один сеанс для временных файлов, например, при сортировке и хешировании, или для сохранения удерживаемого курсора. Транзакция, которая попытается превысить этот предел, будет отменена.  
Этот параметр задаётся в килобайтах, а значение **-1** (по умолчанию) означает, что предел отсутствует. 

```sql
show temp_file_limit;
```

#### Мои рекомендации
Значение **temp_file_limit** имеет смысл устанавливать исходя из максимального размера индексов в БД с некоторым запасом.  
Получить топ-10 индексов по размеру можно с помощью запроса:
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

## Логирование и поиск долгих запросов
### log_min_duration_statement
#### Документация
- [На русском](https://postgrespro.ru/docs/postgrespro/10/runtime-config-logging)
- [На английском](https://www.postgresql.org/docs/10/runtime-config-logging.html)

#### Команды
```sql
show log_min_duration_statement;
show log_destination;
show logging_collector;
show log_directory;
show log_filename;
show log_file_mode;
show log_rotation_age;
show log_rotation_size;
show log_statement;
show log_temp_files;
```
