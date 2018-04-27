Ohai.plugin(:NonDefaultCollectData) do
  provides 'application/version'

  collect_data(:linux) do
    application Mash.new
    application[:version] = '3.0.0'
  end

  collect_data(:windows) do
    application Mash.new
    application[:version] = '9.0.0'
  end
end
