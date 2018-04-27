Ohai.plugin(:DefaultCollectDataWithStubbedShellOut) do
  provides 'apache/modules'

  collect_data(:default) do
    apache Mash.new
    modules_cmd = shell_out('apachectl -t -D DUMP_MODULES')
    apache[:modules] = modules_cmd.stdout
  end
end
