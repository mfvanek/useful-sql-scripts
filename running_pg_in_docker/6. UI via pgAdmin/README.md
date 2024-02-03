# A beautiful UI via pgAdmin

## Docker Compose
### Start
```shell
docker-compose --project-name="habr-pg-16" up -d
```

### Stop
```shell
docker-compose --project-name="habr-pg-16" down
```

## Access to PgAdmin
Open in browser [http://localhost:5050](http://localhost:5050)

## Explore volumes
### List all volumes
```shell
docker volume ls
```

### Delete specified volume
```shell
docker volume rm habr-pg-16_habrdb-data
docker volume rm habr-pg-16_pgadmin-data
```
