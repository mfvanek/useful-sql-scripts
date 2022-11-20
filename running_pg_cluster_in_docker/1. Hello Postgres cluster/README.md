# The simplest way to run PostgreSQL cluster in Docker

## Docker Compose
### Start
`docker-compose --project-name="habr-pg-ha-14" up -d`

### Stop
`docker-compose --project-name="habr-pg-ha-14" down`

### Run psql
`psql -U postgres -d habrdb`  
`psql -U habrpguser -d habrdb`

See:
```sql
show wal_level;
```
Should be `wal_level = 'replica'`

### How to inspect where the primary is
```sql
select case when pg_is_in_recovery() then 'secondary' else 'primary' end as host_status;
```

Without log in to psql:
```bash
psql -c "select case when pg_is_in_recovery() then 'secondary' else 'primary' end as host_status;" "dbname=habrdb user=habrpguser password=pgpwd4habr"
```

## How to manually init failover

### Stop container with current primary
```bash
docker stop postgres_1
```

### Ensure replica has been promoted to primary
See containers logs and wait for
```
LOG:  database system was not properly shut down; automatic recovery in progress
…
LOG:  database system is ready to accept connections
```

### Return the first host to the cluster
```bash
docker start postgres_1
```

## repmgr docs
https://repmgr.org/docs/repmgr.html

### switchover
`/opt/bitnami/scripts/postgresql-repmgr/entrypoint.sh repmgr standby switchover -f /opt/bitnami/repmgr/conf/repmgr.conf --siblings-follow --dry-run`