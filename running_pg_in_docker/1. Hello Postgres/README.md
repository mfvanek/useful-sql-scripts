# The simplest way to run PostgreSQL in Docker

## Docker
```
docker run --name habr-pg-13.3 -p 5432:5432 -e POSTGRES_USER=habrpguser -e POSTGRES_PASSWORD=pgpwd4habr -e POSTGRES_DB=habrdb -d postgres:13.3
```

### Run psql
`psql -U habrpguser -d habrdb`

## Docker Compose
### Start
`docker-compose --project-name="habr-pg-13.3" up -d`

### Stop
`docker-compose --project-name="habr-pg-13.3" down`
