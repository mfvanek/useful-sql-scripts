# Tuning parameters via postgresql.conf

## Docker Compose

### Start

```shell
docker-compose --project-name="habr-pg-16" up -d
```

### Stop

```shell
docker-compose --project-name="habr-pg-16" down
```

### Run psql

```shell
psql -U habrpguser -d habrdb
```

#### Check options

```shell
show work_mem;
show max_connections;
```
