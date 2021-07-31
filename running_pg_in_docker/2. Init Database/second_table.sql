create table if not exists second_table
(
  id bigserial primary key,
  first_id bigint not null references first_table (id)
);
