set search_path to public;

drop table if exists test;
create table test (id bigserial primary key, ref varchar(20));
create index idx_ref_with_nulls on test (ref);

insert into test (ref) 
select case when (g.idx % 2 = 0) then null else lpad(g.idx::text, 20, '0') end
from generate_series(1, 1000000) as g (idx);
														 
select * from test order by id asc limit 100;
														 
create index concurrently idx_ref_without_nulls on test (ref) where ref is not null;