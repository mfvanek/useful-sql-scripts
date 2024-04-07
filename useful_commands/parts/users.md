### List of connected users (Перечень подключенных пользователей)

To find out the name, IP and port of the connected users, run the following query:
```sql
select datname,usename,client_addr,client_port from pg_stat_activity;
```

### User activity (Активность пользователя)

To find out the connection activity of a specific user, use the following query:
```sql
select datname from pg_stat_activity where usename = 'devuser';
```

### Connection limit per user

```sql
select rolname, rolconnlimit from pg_roles where rolconnlimit <> -1;
```
See [pg_roles](https://www.postgresql.org/docs/16/view-pg-roles.html)

### Roles hierarchy

```sql
select r.rolname, r.rolsuper, r.rolinherit,
       r.rolcreaterole, r.rolcreatedb, r.rolcanlogin,
       r.rolconnlimit, r.rolvaliduntil,
       array(select b.rolname
             from pg_catalog.pg_auth_members m
                    join pg_catalog.pg_roles b on (m.roleid = b.oid)
             where m.member = r.oid) as memberof
    , pg_catalog.shobj_description(r.oid, 'pg_authid') as description
    , r.rolreplication
from pg_catalog.pg_roles r
order by 1;
```
