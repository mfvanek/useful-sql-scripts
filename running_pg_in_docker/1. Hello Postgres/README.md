# The simplest way to run PostgreSQL in Docker

## Docker
```shell
docker run --name habr-pg-17 -p 6432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -d postgres:17.6-alpine3.22
```

### Run psql
```shell
psql -U habrpguser -d habrdb
```

## Docker Compose
### Start
```shell
docker-compose --project-name="habr-pg-17" up -d
```

### Stop
```shell
docker-compose --project-name="habr-pg-17" down
```
