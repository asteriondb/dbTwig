@quiet
SET LONG 20000
SET LONGC 20000
SET LINESIZE 20000

set trimspool on
set termout off

spool &1

select  'insert into middle_tier_map values ('''||entry_point||''', '''||object_type||''', '''||object_name||''', '''||object_group||''');'
  from  middle_tier_map
 where  object_group = '&2';

spool off
exit;
