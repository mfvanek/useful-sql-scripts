# Specifying catalog for database files

## Docker
```
docker run --name habr-pg-13.3 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -e PGDATA=/var/lib/postgresql/data/pgdata -d -v "/absolute/path/to/directory-with-data":/var/lib/postgresql/data -v "/absolute/path/to/directory-with-init-scripts":/docker-entrypoint-initdb.d postgres:13.3
```

### Auto detect current directory (for macOS and Linux)
```
docker run --name habr-pg-13.3 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -e PGDATA=/var/lib/postgresql/data/pgdata -d -v "$(pwd)":/var/lib/postgresql/data -v "$(pwd)/../2. Init Database":/docker-entrypoint-initdb.d postgres:13.3
```

## Docker Compose
### Start
`docker-compose --project-name="habr-pg-13.3" up -d`

### Stop
`docker-compose --project-name="habr-pg-13.3" down`
