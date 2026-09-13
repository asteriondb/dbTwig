begin

    dbms_aqadm.stop_queue('&1..PLUGIN$SERVER');
    dbms_aqadm.drop_queue(queue_name => '&1..PLUGIN$SERVER');
    dbms_aqadm.drop_queue_table(queue_table => '&1..PLUGIN$SERVER');

end;
.
/
