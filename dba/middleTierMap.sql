create table middle_tier_map
(
  entry_point                       varchar2(128) primary key,
  object_type                       varchar2(9) not null
    constraint object_type_check check (object_type in ('function', 'procedure')),
  object_name                       varchar2(128) not null,
  object_group                      varchar2(128) not null,
  required_authorization_level      varchar2(13) default 'administrator' not null
    constraint required_auth_level_chk check (required_authorization_level in ('administrator', 'user', 'guest', 'none')),
  allow_blocked_session varchar2(1) default 'N' not null
    constraint allow_blocked_chk check (allow_blocked_session in ('Y', 'N'))
);
