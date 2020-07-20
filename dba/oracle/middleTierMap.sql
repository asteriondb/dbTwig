create table middle_tier_map
(
  entry_point                       varchar2(128) primary key,
  object_type                       varchar2(9) not null
    constraint object_type_check check (object_type in ('function', 'procedure')),
  object_name                       varchar2(128) not null
);
