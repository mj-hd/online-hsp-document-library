#!/usr/bin/env ruby

# 旧データベースに存在するドキュメントが新データベースにも存在するか確認

require 'pathname'
require 'uri'
require 'cgi'
Dir.chdir Pathname(File.dirname($0)).parent
require 'ohdl/config'
require 'ohdl/application'
require 'ohdl/screen'
require 'ohdl/database'

def parse_request(uri_str)
  uri = URI(uri_str)
  params = CGI.parse(uri.query || '')
  @application.send(:parse_request, uri.path, params, uri.query)
end

def check_uri(uri)
  cmd, *args = parse_request(uri)
  if (cmd == 'notfound' or cmd == 'plain') and not File.file?(File.join(".", URI.decode(uri)))
    puts uri
    @ng += 1
  else
    @ok += 1
  end
end

begin
  @old_db = OHDL::Database.new('hdlbase.old.xdb')
  @new_db = OHDL::Database.new('hdlbase.xdb')
  config = OHDL::Config.new()
  screen_manager = OHDL::ScreenManager.new(config, @new_db)
  @urimapper = screen_manager.urimapper
  @application = OHDL::Application.new(config, @new_db, screen_manager)
  @ok = @ng = 0
  @old_db.refs.each do |ref|
    check_uri(@urimapper.rid(ref))
  end
  @old_db.docs.each do |doc|
    check_uri(@urimapper.did(doc))
  end
  @old_db.samples.each do |sample|
    check_uri(@urimapper.did(sample))
  end
  puts "OK: #{@ok}, NG: #{@ng}"
ensure
  @old_db.close if @old_db
  @new_db.close if @new_db
end
