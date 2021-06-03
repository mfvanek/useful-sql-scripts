# Run
```
docker-compose --project-name=my_pg up -d --build
```

# Stop
```
docker-compose --project-name=my_pg down
```

# Metrics
Metrics from [postgres-exporter](https://github.com/prometheus-community/postgres_exporter) will be available at  
[http://localhost:9187/metrics](http://localhost:9187/metrics)