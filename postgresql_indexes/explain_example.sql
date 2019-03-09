set search_path to public;

explain (analyze, buffers) select * from test where ref in ('00000000000000000007', '00000000000000000008', '00000000000000000009') order by 1,2;