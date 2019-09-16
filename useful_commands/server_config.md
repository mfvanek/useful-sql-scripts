## runtime-config-query

show temp_file_limit;
select * from pg_settings where name = 'temp_file_limit';

show work_mem;
show maintenance_work_mem;

[Resource Consumption RU](https://postgrespro.ru/docs/postgrespro/10/runtime-config-resource)
[Resource Consumption EN](https://www.postgresql.org/docs/10/runtime-config-resource.html)

postgresql.conf

show random_page_cost;
[Настройка сервера](https://postgrespro.ru/docs/postgrespro/10/runtime-config-query)

log_min_duration_statement
idle_in_transaction_session_timeout
statement_timeout