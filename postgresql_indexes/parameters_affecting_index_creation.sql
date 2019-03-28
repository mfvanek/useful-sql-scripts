set search_path to public;

--show temp_file_limit;
--set temp_file_limit = '1 MB';
--set temp_file_limit = '10 MB';
--set temp_file_limit = '100 MB';
--show maintenance_work_mem;
--set maintenance_work_mem = '1 MB';
--set maintenance_work_mem = '1 GB';

drop index concurrently if exists idx_ref_without_nulls;
create index concurrently if not exists idx_ref_without_nulls on test (ref) where ref is not null;

-- Query returned successfully in 2 secs 815 msec. when maintenance_work_mem = '1 MB' and temp_file_limit = '100 MB'