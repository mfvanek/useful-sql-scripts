# Run
```shell
docker-compose up -d
```

# Stop
```shell
docker-compose down
```

# Logs
```shell
docker compose logs 
```

# Connection string
`jdbc:mysql://localhost:3306/sandbox`

# Query
```sql
SELECT `course_name`, ROUND(SUM(cnt) / COUNT(`month`), 2) `avg_months`
FROM (SELECT `course_name`, month (`subscription_date`) `month`, COUNT(*) cnt
      FROM `PurchaseList`
      WHERE YEAR (`subscription_date`) = 2018
      GROUP by `course_name`, month (`subscription_date`)) t
GROUP by `course_name`
ORDER BY `avg_months` desc
```