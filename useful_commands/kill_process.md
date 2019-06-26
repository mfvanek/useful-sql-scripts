# System Administration Functions
[Doc](https://postgrespro.ru/docs/postgrespro/10/functions-admin)

## Option 1
```
select * from pg_stat_activity where query like 'delete from order_event where event_id in%' order by pid;
SELECT pg_cancel_backend(<pid>);
SELECT pg_terminate_backend(<pid>);
```

## Option 2
```
DO $$DECLARE r record;
BEGIN
    FOR r IN select pid, query, (extract(epoch from now()) - extract(epoch from query_start)) duration
             from pg_stat_activity
             where (query like 'select %' or query like 'update %' or query like 'delete %') and (extract(epoch from now()) - extract(epoch from query_start)) > 50

    LOOP
        select pg_sleep(2);
        select pg_terminate_backend(r.pid);
    END LOOP;
END$$;
```

## Зависшие запросы
```
select (now() - xact_start)::time as xact_age,
       (now() - query_start)::time as query_age,
       (now() - state_change)::time as change_age,
       pid,
       'select pg_terminate_backend(' || pid || ');' as kill_statement,
       state, datname, usename,
       coalesce(wait_event_type = 'lock', 'f') as waiting,
       wait_event_type ||'.'|| wait_event as wait_details,
       client_addr ||'.'|| client_port as client,
       query
from pg_stat_activity
where clock_timestamp() - coalesce(xact_start, query_start) > '00:00:00.1'::interval
  and pid <> pg_backend_pid() and state <> 'idle'
order by coalesce(xact_start, query_start);
```
