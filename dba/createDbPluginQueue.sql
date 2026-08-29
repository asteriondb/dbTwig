begin

  dbms_aqadm.create_queue_table(
    queue_table => '&1..plugin$server',
    queue_payload_type => 'plugin$message_t');

  dbms_aqadm.create_queue(
    queue_name => '&1..plugin$server',
    queue_table => '&1..plugin$server');

  dbms_aqadm.start_queue('&1..plugin$server');

end;
.
/  


