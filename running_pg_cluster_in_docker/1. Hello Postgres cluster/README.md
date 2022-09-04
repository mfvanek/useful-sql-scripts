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

## repmgr docs
https://repmgr.org/docs/repmgr.html

### switchover
`/opt/bitnami/scripts/postgresql-repmgr/entrypoint.sh repmgr standby switchover -f /opt/bitnami/repmgr/conf/repmgr.conf --siblings-follow --dry-run`