rem  A little script to show the pattern required to allow a DBA to enable create session and connect as a schema owner...

grant create session to tester;

set echo off
set verify off
set termout off

column newPassword new_value newPasswordX

select  '#'||dbms_random.string('x', 9)||dbms_random.string('a', 9)||'#' newPassword
  from  dual;

declare

  l_sql_text                varchar2(256);

begin

  l_sql_text := 'alter user tester identified by "'||'&&newPasswordX'||'"';
  execute immediate l_sql_text;

end;
.
/

set echo on
set termout on

connect tester/&&newPasswordX@local-dev;

show user

connect system/xyzasdfkdkfkf@local-dev

revoke create session from tester;

show user
