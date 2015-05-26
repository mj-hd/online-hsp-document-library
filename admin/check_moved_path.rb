#!/usr/bin/env ruby

# Moved テーブルに存在する新パスが not found にならないかチェック

require 'pathname'
require 'uri'
require 'cgi'
Dir.chdir Pathname(File.dirname($0)).parent
require './ohdl/config'
require './ohdl/application'
require './ohdl/screen'
require './ohdl/database'

def parse_request(uri_str)
  uri = URI(uri_str)
  params = CGI.parse(uri.query || '')
  @application.send(:parse_request, uri.path, params, uri.query)
end

def check_uri(uri)
  cmd, *args = parse_request(uri)
  
  if cmd == 'moved' or
   ((cmd == 'notfound' or cmd == 'plain') and not File.file?(File.join(".", URI.decode(uri))))
    printf "%p: %s(%p)\n", uri, cmd, args
    @ng += 1
  else
    @ok += 1
  end
end

begin
  @db = OHDL::Database.new('hdlbase.xdb')
  config = OHDL::Config.new()
  screen_manager = OHDL::ScreenManager.new(config, @db)
  @urimapper = screen_manager.urimapper
  @application = OHDL::Application.new(config, @db, screen_manager)
  @ok = @ng = 0
  @db.sqdb.execute("SELECT New FROM Moved") do |new, *|
    check_uri(@urimapper.moved_uri(new))
  end
  puts "OK: #{@ok}, NG: #{@ng}"
ensure
  @db.close if @db
end

