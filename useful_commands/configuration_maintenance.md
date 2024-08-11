# Configuration Maintenance (Управление конфигурацией)

## Viewing server parameter values (Просмотр значений параметров сервера)

```sql
SELECT name, setting, unit, boot_val, reset_val,
source, sourcefile, sourceline, pending_restart, context
FROM pg_settings
WHERE name = 'work_mem';
```

## Re-reading the configuration (Перечитывание конфигурации)

```sql
SELECT pg_reload_conf();
```

## Read the configuration file (Прочитать конфигурационный файл)

```sql
SELECT pg_read_file('postgresql.auto.conf');

-- or
SELECT pg_read_file('/etc/postgresql/16/main/postgresql.conf', 1516, 861);
```


## Get the parameter value within the session (Получить значение параметра в рамках сеанса)

```sql
SHOW work_mem;

-- or
SELECT current_setting('work_mem');
```

## Get the value of a parameter within a transaction (Получить значение параметра в рамках транзакции)

```sql
SET LOCAL work_mem TO '64MB';

-- or
set_config('work_mem','64MB',true);
```
