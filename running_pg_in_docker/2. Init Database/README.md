# Initializing Postgres database at startup

## Docker
```
docker run --name habr-pg-14 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -d -v "/absolute/path/to/directory-with-init-scripts":/docker-entrypoint-initdb.d postgres:14.5
```

### Auto detect current directory (for macOS and Linux)
```
docker run --name habr-pg-14 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -d -v "$(pwd)":/docker-entrypoint-initdb.d postgres:14.5
```

### Run psql
`psql -U habrpguser -d habrdb`

## Docker Compose
### Start
`docker-compose --project-name="habr-pg-14" up -d`

### Stop
`docker-compose --project-name="habr-pg-14" down`
