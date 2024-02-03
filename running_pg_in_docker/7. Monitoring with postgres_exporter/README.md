# Monitoring database with postgres_exporter

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

## PostgreSQL Exporter for Prometheus
See [postgres_exporter on GitHub](https://github.com/prometheus-community/postgres_exporter)

Open in browser [http://localhost:9187/metrics](http://localhost:9187/metrics)
