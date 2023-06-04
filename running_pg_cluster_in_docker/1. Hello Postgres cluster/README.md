# The simplest way to run PostgreSQL cluster in Docker

## Docker Compose

### Start

```shell
docker-compose --project-name="habr-pg-ha-14" up -d
```

### Stop

```shell
docker-compose --project-name="habr-pg-ha-14" down
```

### Explore volumes
#### List all volumes
```shell
docker volume ls
```

#### Delete specified volume if need
```shell
docker volume rm habr-pg-ha-14_pg_1_data
docker volume rm habr-pg-ha-14_pg_2_data
```

### Run psql

```shell
psql -U postgres -d habrdb
```

```shell
psql -U habrpguser -d habrdb
```

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

```shell
docker exec postgres_1 psql -c "select case when pg_is_in_recovery() then 'secondary' else 'primary' end as host_status;" "dbname=habrdb user=habrpguser password=pgpwd4habr"
```

```shell
docker exec postgres_2 psql -c "select case when pg_is_in_recovery() then 'secondary' else 'primary' end as host_status;" "dbname=habrdb user=habrpguser password=pgpwd4habr"
```

### DB metrics

Open in browser:
* [http://localhost:9187/metrics](http://localhost:9187/metrics)
* [http://localhost:9188/metrics](http://localhost:9188/metrics)

## How to manually init failover

### Stop container with current primary

```shell
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

```shell
docker start postgres_1
```

## repmgr docs

https://repmgr.org/docs/repmgr.html

### switchover

`/opt/bitnami/scripts/postgresql-repmgr/entrypoint.sh repmgr standby switchover -f /opt/bitnami/repmgr/conf/repmgr.conf --siblings-follow --dry-run`
