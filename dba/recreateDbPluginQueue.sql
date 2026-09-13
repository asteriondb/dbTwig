set echo on
connect &1
@dropDbPluginQueue &2
@createDbPluginQueue &2
exit
