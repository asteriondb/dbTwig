create or replace
TYPE            "PLUGIN$MESSAGE_T" as object
(
  client_handle         varchar2(24),
  plugin_server         varchar2(255),
  message_payload       varchar2(4000)
);
.
/
show errors type plugin$message_t

