#!/usr/local/bin/ruby -Ks

begin
  require './ohdl/config'
  require './ohdl/application'
  require './ohdl/database'
  require './ohdl/screen'

  config = OHDL::Config.new()
  db = OHDL::Database.new(config.dbfilename)
  screen_manager = OHDL::ScreenManager.new(config, db)
  application = OHDL::Application.new(config, db, screen_manager)
  application.main
#rescue Exception => e
#  puts 'Content-Type: text/plain'
#  puts
#  p e
#  puts e.backtrace
ensure
  db.close if db
end
