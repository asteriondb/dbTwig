declare

    l_sql_text                        clob;
    l_default_tablespace              database_properties.property_value%type;

begin

    select  property_value
      into  l_default_tablespace
      from  database_properties 
     where  property_name = 'DEFAULT_PERMANENT_TABLESPACE';

    l_sql_text := 'create user &elog_user';
    execute immediate l_sql_text;

    l_sql_text := 'alter user &elog_user quota 50m on '||l_default_tablespace;
    execute immediate l_sql_text;

end;
.
/

alter user &elog_user temporary tablespace temp;


