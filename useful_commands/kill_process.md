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
