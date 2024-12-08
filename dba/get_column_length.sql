create or replace
function get_column_length
  (
    p_table_name                      user_tab_columns.table_name%type,
    p_column_name                     user_tab_columns.column_name%type
  )
  return number

  authid current_user

  is

    l_data_length                     user_tab_columns.data_length%type;

  begin

    select  data_length
      into  l_data_length
      from  user_tab_columns
     where  table_name = p_table_name
       and  column_name = p_column_name;

    return l_data_length;

  end get_column_length;
.
/
show errors function get_column_length
