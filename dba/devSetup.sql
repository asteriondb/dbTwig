spool devSetup.log

set echo on

whenever sqlerror exit failure;

alter session set current_schema = &1;

grant connect, create table, create procedure, create sequence to &1 identified by "&2";

