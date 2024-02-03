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

## Add a new server in PgAdmin

* Host name/address `postgres` (as Docker-service name)
* Port `5432` (inside Docker)
* Maintenance database `habrdb` (as `POSTGRES_DB`)
* Username `habrpguser` (as `POSTGRES_USER`)
* Password `pgpwd4habr` (as `POSTGRES_PASSWORD`)

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
