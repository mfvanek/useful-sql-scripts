# Initializing Postgres database at startup

## Docker
```shell
docker run --name habr-pg-14 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -d -v "/absolute/path/to/directory-with-init-scripts":/docker-entrypoint-initdb.d postgres:14.8-alpine3.18
```

### Auto detect current directory (for macOS and Linux)
```shell
docker run --name habr-pg-14 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -d -v "$(pwd)":/docker-entrypoint-initdb.d postgres:14.8-alpine3.18
```

### Run psql
```shell
psql -U habrpguser -d habrdb
```

## Docker Compose
### Start
```shell
docker-compose --project-name="habr-pg-14" up -d
```

### Stop
```shell
docker-compose --project-name="habr-pg-14" down
```
