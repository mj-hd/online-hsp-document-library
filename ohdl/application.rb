require 'uri'
require 'cgi'

module OHDL
  APPNAME = 'Online HSP Document Library'
  APPVER = '1.32'
  APPSIG_PORT = 'ported by : fujidig'
  APPSIG_ORIG = 'original : S.Programs 2007-2009'
  
  class Application
    def initialize(config, db, screen_manager)
      @config = config
      @db = db
      @screen_manager = screen_manager
      @urimapper = screen_manager.urimapper
    end
    
    def main
      cgi = CGI.new
      screen = handle(cgi)
      cgi.out(screen.http_response_header_options()){ screen.body() }
    end
    
    def handle(cgi)
      begin
        uri = URI(ENV['REQUEST_URI'])
        cmd, *args = parse_request(uri.path, cgi.params, uri.query)
      rescue URI::Error
        cmd, args = ['notfound', ENV['REQUEST_URI']]
      end
      send("handle_#{cmd}", *args)
    end
    
    private
    
    def handle_notfound(uri)
      @screen_manager.notfound_screen(uri)
    end
    
    def handle_frameset(search_query=nil)
      @screen_manager.frameset_screen(search_query)
    end
    
    def handle_verinfo
      @screen_manager.verinfo_screen()
    end
    
    def handle_menu(search_query)
      @screen_manager.menu_screen(search_query)
    end
    
    def handle_opensearch
      @screen_manager.opensearch_screen()
    end
    
    def handle_function_list_js
      @screen_manager.function_list_js_screen()
    end
    
    def handle_home
      @screen_manager.home_screen()
    end
    
    def handle_refcat(category)
      @screen_manager.refcat_screen(category)
    end
    
    def handle_rid(reference)
      @screen_manager.rid_screen(reference, get_referer_search_query())
    end
    
    def handle_doccat(category)
      @screen_manager.doccat_screen(category)
    end
    
    def handle_samcat(category)
      @screen_manager.samcat_screen(category)
    end
    
    def handle_did(doc)
      @screen_manager.did_screen(doc, get_referer_search_query(doc))
    end
    
    def handle_moved(uri)
      @screen_manager.moved_screen(uri)
    end
    
    def handle_plain(path, uri)
      @screen_manager.plaintext_screen(path, uri)
    end
    
    def get_referer_search_query(doc=nil)
      uri = URI(ENV['HTTP_REFERER'])
      return nil unless agree_origin(uri, ENV['HTTP_HOST'])
      params = CGI.parse(uri.query || '')
      cmd, arg = parse_request(uri.path, params, uri.query)
      if doc and doc.sample? and cmd == 'rid'
        # リファレンスのサンプル逆引き
        return arg.name
      end
      return nil unless cmd == 'search' or cmd == 'menu'
      arg
    rescue URI::Error
      nil
    end
    
    def agree_origin(uri, host)
      (uri.scheme == 'http' or uri.scheme == 'https') and
      (uri.host == host or "#{uri.host}:#{uri.port}" == host)
    end
    
    def parse_request(path, params, params_str)
      notfound = ['notfound', path]
      path = URI.decode(path)
      unless path and path.index(@config.uripath) == 0
        return notfound
      end
      
      path = path[@config.uripath.size..-1]
      result = case path
      when ''
        ['frameset', params['q'][0]]
      when %r<\Averinfo/?\z>
        ['verinfo']
      when %r<\Amenu/?\z>
        ['menu', params['q'][0]]
      when %r<\Aopensearch/?\z>
        ['opensearch']
      when %r<\Afunction_list\.js\z>
        ['function_list_js']
      when %r<\Ahome/?\z>
        ['home']
      when %r<\Areference(?:/(?:_builtin|([^/]+)))?/?\z>
        category = @db.refcats.find_by_name($1 || '')
        category ? ['refcat', category] : notfound
      when %r<\Areference/(?:_builtin|([^/]+))/([^/]+)/?\z>
        ref = @db.refs.find_by_mod_and_name($1 || '', $2 || '')
        ref ? ['rid', ref] : notfound
      when %r<\A(?:docs|doclib)/.*\.txt\z>, %r<\A(?:sample|doclib)/.*\.hsp\z>
        if params['format'][0] == 'plain'
          ['plain', path, notfound[1]]
        else
          doc = @db.find_doc_or_sample_by_path(path)
          doc ? ['did', doc] : notfound
        end
      when %r<\Adocs(?:/([^/]+))?/?\z>
        category = @db.doccats.find_by_name($1 || '')
        category ? ['doccat', category] : notfound
      when %r<\Asample(?:/([^/]+))?/?\z>
        category = @db.samcats.find_by_name($1 || '')
        category ? ['samcat', category] : notfound
      else
        notfound
      end
      if result == notfound
        if new_path = @db.search_moved(path)
          uri = @urimapper.moved_uri(new_path, params_str)
          result = ['moved', uri]
        elsif path =~ /\.(?:hsp|txt)\z/
          result = ['plain', path, notfound[1]]
        end
      end
      result
    end
  end
end

