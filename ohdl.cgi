#!/usr/local/bin/ruby -Ks

# 過去の URI からのリダイレクトを行う

require 'ohdl/config'
require 'ohdl/application'
require 'ohdl/database'
require 'ohdl/screen'
require 'cgi'
require 'uri'

module OHDL
  class ScreenManager
    def redirect_to_new_uri_screen(page, cmd, arg, new_db)
      uri = nil
      case page
      when 'main'
        case cmd
        when 'hid'
          ref = @db.refs.find_by_id(arg.to_i)
          uri = @urimapper.rid(ref) if ref
        when 'pid'
          doc = @db.find_doc_or_sample_by_id(arg.to_i)
          uri = @urimapper.did(doc) if doc
        when 'hcat'
          category = @db.refcats.find_by_name(arg)
          uri = @urimapper.refcat(category) if category
        when 'dcat'
          category = @db.doccats.find_by_name(arg)
          uri = @urimapper.doccat(category) if category
        when 'scat'
          category = @db.samcats.find_by_name(arg)
          uri = @urimapper.samcat(category) if category
        when 'sysinf'
          uri = @urimapper.verinfo
        when ''
          uri = @urimapper.home
        end
      when 'menu'
        uri = @urimapper.menu(arg)
      when ''
        uri = @urimapper.frameset(arg)
      end
      if uri
        MovedScreen.new(@params, filter_moved(new_db, uri))
      else
        NotFoundScreen.new(@params, ENV['REQUEST_URI'])
      end
    end
    
    private
    def filter_moved(db, uri)
      baseuri = @urimapper.uri
      unless uri.index(baseuri) == 0
        return uri
      end
      path, params = uri[baseuri.size..-1].split('?', 2)
      
      new_path = db.search_moved(URI.decode(path))
      if new_path
        @urimapper.moved_uri(new_path, params)
      else
        uri
      end
    end
  end
end

begin
  config = OHDL::Config.new()
  db = OHDL::Database.new('hdlbase.old.xdb')
  new_db = OHDL::Database.new('hdlbase.xdb')
  screen_manager = OHDL::ScreenManager.new(config, db)
  
  cgi = CGI.new
  page = cgi.params['page'][0] || ''
  cmd = cgi.params['cmd'][0] || ''
  arg = cgi.params['arg'][0] || ''
  screen = screen_manager.redirect_to_new_uri_screen(page, cmd, arg, new_db)
  cgi.out(screen.http_response_header_options()){ screen.body() }
#rescue Exception => e
#  puts 'Content-Type: text/plain'
#  puts
#  p e
#  puts e.backtrace
ensure
  db.close if db
  new_db.close if new_db
end
