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
