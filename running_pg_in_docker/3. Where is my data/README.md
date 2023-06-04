# Specifying catalog for database files

## Docker
```shell
docker run --name habr-pg-14 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -e PGDATA=/var/lib/postgresql/data/pgdata -d -v "/absolute/path/to/directory-with-data":/var/lib/postgresql/data -v "/absolute/path/to/directory-with-init-scripts":/docker-entrypoint-initdb.d postgres:14.8-alpine3.18
```

### Auto-detect current directory (for macOS and Linux)
```shell
docker run --name habr-pg-14 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -e PGDATA=/var/lib/postgresql/data/pgdata -d -v "$(pwd)":/var/lib/postgresql/data -v "$(pwd)/../2. Init Database":/docker-entrypoint-initdb.d postgres:14.8-alpine3.18
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

## Explore volumes
### List all volumes
```shell
docker volume ls
```

### Delete specified volume
```shell
docker volume rm habr-pg-14_habrdb-data
```
