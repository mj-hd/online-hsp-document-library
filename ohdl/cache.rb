require 'fileutils'

module OHDL
  class CacheBase
    def initialize(config, db)
      @config = config
      @db = db
    end
    
    def fname_home() "home" end
    def fname_frameset() "frameset" end
    def fname_verinfo() "verinfo" end
    def fname_menu() "menu" end
    def fname_opensearch() "opensearch" end
    def fname_rid(ref) "rid/#{ref.id}" end
    def fname_did(doc) "did/#{doc.id}" end
    def fname_refcat(cat) "refcat/#{escape_filename(cat.name)}" end
    def fname_doccat(cat) "doccat/#{escape_filename(cat.name)}" end
    def fname_samcat(cat) "samcat/#{escape_filename(cat.name)}" end

    def escape_filename(s)
      if s == ''
        '%5fempty'
      else
        s.gsub(/[^\w\-]/) {|ch| sprintf('%%%02X', ch[0].to_i) }
      end
    end
  end
  
  class CacheWriter < CacheBase
    def initialize(config, db, screen_manager)
      super config, db
      @mng = screen_manager
    end
    
    def screen_manager
      @mng
    end
    
    def clear_all_cache
      FileUtils.rm_rf(Dir[@config.cache_dir+'/*'])
    end
    
    def cache_home
      cache @mng.home_screen(), fname_home()
    end
    
    def cache_frameset
      cache @mng.frameset_screen(''), fname_frameset()
    end
    
    def cache_verinfo
      cache @mng.verinfo_screen(), fname_verinfo()
    end
    
    def cache_menu
      cache @mng.menu_screen(''), fname_menu()
    end
    
    def cache_opensearch
      cache @mng.opensearch_screen(), fname_opensearch()
    end
    
    def cache_refs
      @db.refs.each do |ref|
        cache_ref(ref)
      end
    end
    
    def cache_ref(ref)
      cache @mng.rid_screen(ref), fname_rid(ref)
    end
    
    def cache_docsams
      @db.docsams.each do |doc|
        cache_doc(doc)
      end
    end
    
    def cache_doc(doc)
      cache @mng.did_screen(doc), fname_did(doc)
    end
    
    def cache_refcats
      @db.refcats.each do |cat|
        cache_refcat(cat)
      end
    end
    
    def cache_refcat(cat)
        cache @mng.refcat_screen(cat), fname_refcat(cat)
    end
    
    def cache_doccats
      @db.doccats.each do |cat|
        cache_doccat(cat)
      end
    end
    
    def cache_doccat(cat)
      cache @mng.doccat_screen(cat), fname_doccat(cat)
    end
    
    def cache_samcats
      @db.samcats.each do |cat|
        cache_samcat(cat)
      end
    end
    
    def cache_samcat(cat)
      cache @mng.samcat_screen(cat), fname_samcat(cat)
    end
    
    def cache_function_list_js
      content = @mng.function_list_js_screen.body()
      open('function_list.js', 'wb') {|f| f.write content }
    end

    def cache(screen, fname)
      content = screen.body()
      path = File.join(@config.cache_dir, fname)
      FileUtils.mkdir_p File.dirname(path)
      open(path, 'wb') {|f| f.write content }
    end
  end
  
  class CacheReader < CacheBase
    def read_home(&b) read(fname_home(), &b) end
    def read_frameset(&b) read(fname_frameset(), &b) end
    def read_verinfo(&b) read(fname_verinfo(), &b) end
    def read_menu(&b) read(fname_menu(), &b) end
    def read_opensearch(&b) read(fname_opensearch(), &b) end
    def read_rid(ref, &b) read(fname_rid(ref), &b) end
    def read_did(doc, &b) read(fname_did(doc), &b) end
    def read_refcat(cat, &b) read(fname_refcat(cat), &b) end
    def read_doccat(cat, &b) read(fname_doccat(cat), &b) end
    def read_samcat(cat, &b) read(fname_samcat(cat), &b) end
    
    def read_cat(cat, &b)
      if cat.reference?
        fname = fname_refcat(cat)
      elsif cat.doc?
        fname = fname_doccat(cat)
      else
        fname = fname_samcat(cat)
      end
      read(fname, &b)
    end
    
    def read(fname)
      path = File.join(@config.cache_dir, fname)
      begin
        result = open(path, 'rb') {|f| f.read }
      rescue SystemCallError
        return
      end
      yield result
    end
  end
  
  class LazyCacheReader < CacheReader
    def read(fname)
    end
  end
end
