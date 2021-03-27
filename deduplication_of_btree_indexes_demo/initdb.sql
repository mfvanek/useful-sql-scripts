create table if not exists test
(
  id bigserial primary key,
  fld varchar(255),
  mark varchar(255),
  nil varchar(255)
);

insert into test
select data.id, case when data.id % 2 = 0 then now()::text else null end, case when data.id % 2 = 0 then 'test_string'::text else null end, null
from generate_series(1, 100000) as data(id);

create index if not exists i_test_fld_with_nulls on test (fld);
create index if not exists i_test_fld_without_nulls on test (fld) where fld is not null;
create index if not exists i_test_mark_with_nulls on test (mark);
create index if not exists i_test_mark_without_nulls on test (mark) where mark is not null;
create index if not exists i_test_nil_with_nulls on test (nil);
create index if not exists i_test_nil_without_nulls on test (nil) where nil is not null;
