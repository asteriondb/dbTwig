@quiet
SET LONG 20000
SET LONGC 20000
SET LINESIZE 20000

set trimspool on
set termout off

spool &1

select  'insert into middle_tier_map values ('''||entry_point||''', '''||object_type||''', '''||object_name||''');'
  from  middle_tier_map;

spool off
exit;
