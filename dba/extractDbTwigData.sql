@quiet
SET LONG 20000
SET LONGC 20000
SET LINESIZE 20000
set verify off

set trimspool on
set termout off

spool &1

select  'insert into middle_tier_map values ('''||entry_point||''', '''||object_type||''', '''||object_name||''', '''||object_group||''', '''||required_authorization_level
          ||''', '''||allow_blocked_session||''');'
  from  middle_tier_map
 where  object_group = '&2'
 order  by entry_point;

spool off
