require 'ohdl/cache'
require 'erb'
require 'strscan'
require 'kconv'

module OHDL
  class URIMapper
    def initialize(baseurl)
      @uri = baseurl
    end
    
    attr_reader :uri

    def frameset(search_query = nil)
      if search_query.nil? or search_query.empty?
        @uri
      else
        "#{@uri}?q=#{encode_uri(search_query)}"
      end
    end

    def menu(search_query = '')
      ret = "#{@uri}menu/"
      ret += "?q=#{encode_uri(search_query)}" unless search_query.empty?
      ret
    end

    def home
      "#{@uri}home/"
    end

    def refcat(name="")
      ret = "#{@uri}reference/"
      ret += "#{encode_uri(name)}/" unless name.empty?
      ret
    end

    def rid(reference)
      ret = "#{@uri}reference/"
      if reference.mod.empty?
        ret += '_builtin/'
      else
        ret +=  "#{encode_uri(reference.mod)}/"
      end
      ret += "#{encode_uri(reference.name)}/"
      ret
    end

    def verinfo
      "#{@uri}verinfo/"
    end

    def doccat(name="")
      ret = "#{@uri}docs/"
      ret += "#{encode_uri(name)}/" unless name.empty?
      ret
    end

    def samcat(name="")
      ret = "#{@uri}sample/"
      ret += "#{encode_uri(name)}/" unless name.empty?
      ret
    end

    def did(doc, format = false)
      ret = @uri
      ret += path2uri(doc.path)
      ret += "?format=#{encode_uri(format)}" if format
      ret
    end
    
    def opensearch
      "#{@uri}opensearch/"
    end
    
    def function_list_js
      "#{@uri}function_list.js"
    end
    
    def cat(category)
      case category
      when Database::ReferenceCategory
        refcat(category.name)
      when Database::DocCategory
        doccat(category.name)
      when Database::SampleCategory
        samcat(category.name)
      else
        raise ArgumentError
      end
    end
    
    def id(model)
      case model
      when Database::Reference
        rid(model)
      when Database::Doc
        did(model)
      when Database::Sample
        did(model)
      else
        raise ArgumentError
      end
    end
    
    def cat_with_section(name, container)
      case container
      when Database::ReferenceCategoryContainer
        refcat(name)
      when Database::DocCategoryContainer
        doccat(name)
      when Database::SampleCategoryContainer
        samcat(name)
      else
        raise ArgumentError
      end
    end
    
    def section(container)
      cat_with_section("", container)
    end
    
    def moved_uri(path, params=nil)
      ret = @uri + path2uri(path)
      ret += '?' + params if params
      ret
    end
    
    private
    def encode_uri(str)
      str.gsub(/[^\w\.\-]/n) {|ch| sprintf('%%%02X', ch[0]) }
    end
    
    def path2uri(path)
      path.split(/[\\\/]/, -1).map{|i| encode_uri(i) }.join("/")
    end
  end
  
  class ScreenManager
    def initialize(config, db, options = {})
      @urimapper = URIMapper.new(config.baseuri)
      repos = TemplateRepository.new(config.template_dir)
      cache = (options[:no_cache] ? LazyCacheReader : CacheReader).new(config, db)
      @params = Params.new(@urimapper, db, repos, cache).freeze
      @db = db
      @template_repository = repos
    end
    
    attr_reader :urimapper
    
    def notfound_screen(uri)
      NotFoundScreen.new(@params, uri)
    end
    
    def frameset_screen(search_query)
      FrameSetScreen.new(@params, search_query)
    end
    
    def verinfo_screen
      VerInfoScreen.new(@params)
    end
    
    def menu_screen(search_query)
      MenuScreen.new(@params, search_query)
    end
    
    def opensearch_screen
      OpenSearchScreen.new(@params)
    end
    
    def function_list_js_screen
      FunctionListJSScreen.new(@params)
    end
    
    def home_screen
      HomeScreen.new(@params)
    end
    
    def refcat_screen(category)
      ReferenceCatalogScreen.new(@params, category)
    end
    
    def doccat_screen(category)
      DocCatalogScreen.new(@params, category)
    end
    
    def samcat_screen(category)
      SampleCatalogScreen.new(@params, category)
    end
    
    def rid_screen(reference, search_keyword=nil)
      ReferenceScreen.new(@params, reference, search_keyword)
    end
    
    def did_screen(doc, search_keyword=nil)
      DocScreen.new(@params, doc, search_keyword)
    end
    
    def moved_screen(uri)
      MovedScreen.new(@params, uri)
    end
    
    def plaintext_screen(path, uri)
      PlainTextScreen.new(@params, path, uri)
    end
    
    Params = Struct.new(:urimapper, :db, :template_repository, :cache)
    
    if false
    # ERB#def_method を使ってキャッシュし、ERBファイルを読み込んでRubyプログラムに変換してパースするのを省く
    # create_cache.cgi で使ったらキャッシュの生成が速くなるかと思ったらあまり効果なし
    # それに template_repository が決めうちになってしまうのもよくない。
    def add_template_cache
      def_template_method TemplateScreen, 'head(title, navi)', 'head'
      def_template_method TemplateScreen, 'foot', 'foot'
      def_template_method ReferenceCatalogScreen, 'body', 'refcat'
      def_template_method DocAndSampleCatalogScreen, 'body0(mode, secname, cats)', 'samcat_doccat'
      def_template_method ReferenceScreen, 'body0(title, category)', 'rid'
      def_template_method DocScreen, 'body0(is_sample, secname, category)', 'did'
    end
    
    def def_template_method(klass, method_name, id)
      erb = ERB.new(@template_repository.load(id), nil, '%')
      erb.filename = id
      erb.def_method(klass, method_name, id)
    end
    end
  end
  
  class TemplateRepository
    def initialize(prefix)
      @prefix = prefix
    end

    def load(id)
      File.read("#{@prefix}/#{id}.erb")
    end
  end
  
  class Screen
    include ERB::Util
    
    def http_response_header_options
      {'charset' => 'Shift_JIS', 'language' => 'ja', }
    end
  end
  
  class TemplateScreen < Screen
    def initialize(params)
      @params = params
      @urimapper = params.urimapper
      @db = params.db
      @template_repository = params.template_repository
      @cache = params.cache
    end
    
    ENVSTR = {
      'Win' => 'Windows 版 HSP',
      'Mac' => 'Macintosh 版 HSP',
      'Let' => 'HSPLet',
      'Cli' => 'コマンドライン版 HSP',
    }
    
    private
    
    def run_template(id, b=binding())
      erb = ERB.new(@template_repository.load(id), nil, '%-')
      erb.filename = id
      erb.result(b)
    end
    
    def head(title, navi)
      run_template('head', binding())
    end
    
    def foot
      run_template('foot')
    end
    
    def ex_html_enc(str)
      html_escape(str).gsub(/ /n, '&nbsp;').gsub(/\n/n, '<br>')
    end
    
    def strhash(str)
      a = 0
      2.times do
        str.each_byte do |c|
          a = a * 137 + c
        end
      end
      'X%08X' % (a&0xffffffff)
    end
    
    # テキスト → ハイパーテキスト 変換 text, br-mode
    # (HTML Enc & シンボル オートリンク & URL オートリンク)
    def html_enc_spider(src, brmode = false)
      @db.create_ref_name_cache
      scanner = StringScanner.new(src)
      dest = ''
      cache = {}
      until scanner.eos?
        case
        when brmode && scanner.scan(/\n/)
          dest << '<br>'
        when scanner.scan(/(?:https?|ftp):\/\/[^\x00- "'(),\\\x7f-\xff]+/n) #"
          escaped_uri = html_escape(scanner.matched)
          dest << "<a href=\"#{escaped_uri}\" target=\"_top\">#{escaped_uri}</a>"
        when scanner.scan(/[A-Za-z0-9_#%$.]{2,40}/)
          word = scanner.matched
          unless replace_html = cache[word]
            reference = @db.refs.find_by_name(word)
            if reference
              replace_html = "<a href=\"#{h @urimapper.rid(reference)}\" " \
                              "title=\"#{h reference.name} - #{h reference.summary}\">#{h word}</a>"
            else
              path = nil
              if word.index(".")
                path = @db.search_file_path_by_basename(word)
              end
              if path
                path = path.gsub("\\", "/")
                replace_html = "<a href=\"#{h(@urimapper.uri + path)}\">#{h word}</a>"
              else
                replace_html = word
              end
            end
            cache[word] = replace_html
          end
          dest << replace_html
        #when scanner.scan(/["&<>]/)
        #  dest << '&#%d;' % scanner.matched[0]
        when scanner.scan(/[^\nA-Za-z0-9_#%$]+|./m) #(/[^\nA-Za-z0-9_#%$"&<>]+|./m)
          dest << h(scanner.matched)
        else
          raise Exception, 'must not happen'
        end
      end
      dest
    end
    
    def highlight_keyword(str, keyword)
      src = str.downcase
      if false
        [/(<.*?)<body/m, /(<!--.*?)-->/m, /(<style.*?)<\/style>/m, /(<script.*?)<\/script>/m].each do |re|
          src.gsub!(re) do |m|
            m[2, $1.size] = '<' * $1.size
            m
          end
        end
      else # ボトルネックのため最適化
        [['<', '<body'], ['<!--', '-->'],
         ['<style>', '</style>'], ['<script', '</script>']].each do |a, b|
          loop do 
            pos_a = src.index(a)
            pos_b = src.index(b)
            if pos_a and pos_b and pos_b > pos_a
              src[pos_a+2, pos_b-pos_a] = '<' * (pos_b-pos_a)
            else
              break
            end
          end
        end
      end
      
      keyword = keyword.downcase
      sp = 0
      cp = 0
      dest = ''
      re = Regexp.compile(Regexp.escape(keyword))
      while sp = src.index(re, sp)
        gt = src.rindex(?>, sp-1)
        lt = src.rindex(?<, sp-1)
        if gt && lt ? gt > lt : !lt # 本文中（タグの中でない）
          if not /&[^;]*\z/n.match(src[[sp-9, gt||0].max...sp]) # 文字参照の中でない
            dest << str[cp...sp] << '<span class="kwd">' << str[sp, keyword.size] << '</span>'
            cp = sp + keyword.size
          end
        end
        sp += keyword.size
      end
      dest << str[cp..-1]
      dest << "<!-- KeywordEmphasis : #{keyword} -->\n"
    end
    
    def highlight_keywords(str, keywords)
      keywords.split(/ +/).each do |keyword|
        str = highlight_keyword(str, html_escape(keyword))
      end
      str
    end
    
    # HTML 中のアクティブスクリプトに関するキーワードを禁止
    def doubt_angel(src)
      src.gsub(/<script|<iframe|<applet|<meta|<embed|<object|
      javascript:|vbscript:|onunload|onsubmit|onstop|onstart|onselectstart|
      onselectionchange|onselect|onscroll|onrowsinserted|onrowsdelete|
      onrowexit|onrowenter|onresizestart|onresizeend|onresize|onreset|
      onreadystatechange|onpropertychange|onpaste|onpage|onmovestart|onmoveend|
      onmove|onmousewheel|onmouseup|onmouseover|onmouseout|onmousemove|
      onmouseleave|onmouseenter|onmousedown|onlosecapture|onload|
      onlayoutcomplete|onkeyup|onkeypress|onkeydown|onhelp|onfocusout|
      onfocusin|onfocus|onfinish|onfilterchange|onerrorupdate|onerror|ondrop|
      ondragstart|ondragover|ondragleave|ondragenter|ondragend|ondrag|
      ondeactivate|ondblclick|ondatasetcomplete|ondatasetchanged|
      ondataavailable|oncut|oncopy|oncontrolselect|oncontextmenu|onclick|
      onchange|oncellchange|onbounce|onblur|onbeforeupdate|onbeforeunload|
      onbeforeprint|onbeforepaste|onbeforeeditfocus|onbeforedeactivate|
      onbeforecut|onbeforecopy|onbeforeactivate|onafterupdate|onafterprint|
      onactivate|onabort/ix) do |matched|
        sprintf('%c%s%c', matched[0], '_' * (matched.size - 2), matched[-1])
      end
    end
    
    # 文字列長さ制限..
    def left_html_enc(src, width)
      if src.size <= width
        return html_escape(src)
      end
      dest = ''
      chars = src.split(//)
      chars.each do |char|
        dest << char
        if dest.size >= (width - 3)
          dest << '..'
          break
        end
      end
      '<span title="'+html_escape(src) + '">' + html_escape(dest) + '</span>'
    end
    
    def catego_disp(str, mode = nil)
      return str unless str.empty?
      if mode == ?R
        '標準機能'
      else
        '標準カテゴリ'
      end
    end
    
    def dll_disp(str)
      catego_disp(str, ?R)
    end
    
    def grp_disp(str)
      str.empty? ? '(グループ未定義)' : str
    end
    
    def null_cvt(str)
      str.empty? ? '-' : str
    end
    
    def cats_ref
      "リファレンス <small>#{h @db.refcats.size}</small>"
    end
    
    def cats_doc
      "ドキュメント <small>#{h @db.doccats.size}</small>"
    end
    
    def cats_sample
      "サンプル <small>#{h @db.samcats.size}</small>"
    end
    
    #  インライン HTML 記述のサポート ( html{ ... }html )
    def inline_html(inst)
      pos = 0
      dest = ''
      256.times do
        pos2 = inst.index(/html\{\r\n|\z/, pos)
        newpos = Regexp.last_match.end(0)
        if pos2 > pos && inst[pos...pos2] != "\n"
          dest << "<pre class=\"para\">#{html_enc_spider(inst[pos...pos2])}</pre>\n"
        end
        pos = newpos
        break if pos >= inst.size
        
        pos2 = inst.index(/\r\n\}html|\z/, pos)
        newpos = Regexp.last_match.end(0)
        dest << "<div class=\"para\">#{doubt_angel(inst[pos...pos2])}</div>\n"
        pos = newpos
        break if pos >= inst.size
      end
      dest
    end
    
    def thumb_img(doc)
      path = doc.thumb_img_path
      if path
        uri = @urimapper.uri + path.gsub("\\", "/")
        "<img src=\"#{h(uri)}\" class=\"thumb\">"
      else
        nil
      end
    end
    
    def file_mtime(filename)
      File.mtime(filename).strftime("%Y/%m/%d")
    rescue SystemCallError
      ""
    end
    
    def omit_sentence(s, len, delimiters, minlen)
      pos = len
      delimiters.each do |delimiter|
        i = s.rindex(delimiter, pos)
        if i and i + delimiter.size > minlen
          pos = i + delimiter.size
          break
        end
      end
      s[0...pos]
    end
    
    def file_content(path)
      realpath = File.expand_path(path.gsub('\\','/'))
      return nil unless realpath.index(Dir.pwd) == 0
      begin
        File.read(realpath)
      rescue SystemCallError
        nil
      end
    end
  end
  
  class NotFoundScreen < TemplateScreen
    def initialize(params, uri)
      super params
      @uri = uri
    end
    
    def http_response_header_options
      super.update('status' => 'NOT_FOUND')
    end
    
    def body
      run_template('not-found')
    end
  end
  
  class FrameSetScreen < TemplateScreen
    def initialize(params, search_query)
      super params
      @query = search_query||''
    end
    
    def body
      @cache.read_frameset {|r| return r } if @query.empty?
      run_template('frameset')
    end
  end
  
  class HomeScreen < TemplateScreen
    def body
      @cache.read_home {|r| return r }
      run_template('home')
    end
  end
  
  class VerInfoScreen < TemplateScreen
    def body
      @cache.read_verinfo {|r| return r }
      run_template('verinfo')
    end
  end
  
  class ReferenceCatalogScreen < TemplateScreen
    def initialize(params, category)
      super params
      @category = category
    end
    
    def body
      @cache.read_refcat(@category) {|r| return r }
      run_template('refcat')
    end
    
    private
    def omit_inst(ref)
      s = ref.inst.gsub('---', '')[/\A.{0,150}/m] + '..'
      len = s.index(/html\{/n) || s.size
      omit_sentence(s, len, ["。", "\n", " "], 10)
    end
  end
  
  class DocAndSampleCatalogScreen < TemplateScreen
    def initialize(params, category)
      super params
      @category = category
    end
    
    private
    def omit_content(doc)
      s = doc.summary(250)
      omit_sentence(s, s.size, ["。", ". ", " "], 10)
    end
    
    def body0(mode, secname, cats)
      @cache.read_cat(@category) {|r| return r }
      run_template('samcat_doccat', binding())
    end
  end
  
  class DocCatalogScreen < DocAndSampleCatalogScreen
    def body
      body0(?D, 'Document', @db.doccats)
    end
  end
  
  class SampleCatalogScreen < DocAndSampleCatalogScreen
    def body
      body0(?S, 'Sample', @db.samcats)
    end
  end
  
  class ReferenceScreen < TemplateScreen
    def initialize(params, ref, search_keyword)
      super params
      @ref = ref
      @search_keyword = search_keyword
    end
    
    def body
      title = @ref.name
      title += '()' if title[0] == ?(
      ret = body0(title, @ref.category)
      if @search_keyword
        ret = highlight_keywords(ret, @search_keyword)
      end
      ret
    end
    
    private
    def body0(title, category)
      @cache.read_rid(@ref) {|r| return r }
      run_template('rid', binding())
    end
  end
  
  class DocScreen < TemplateScreen
    def initialize(params, doc, search_keyword)
      super params
      @doc = doc
      @search_keyword = search_keyword
      @content = file_content(@doc.path)
    end
    
    def http_response_header_options
      ret = super
      if @content.nil?
        ret['status'] = 'NOT_FOUND'
      end
      ret
    end
    
    def body
      is_sample = @doc.type == 'hsp'
      secname = is_sample ? 'Sample' : 'Document'
      category = @doc.category
      ret = body0(is_sample, secname, category)
      if @search_keyword
        ret = highlight_keywords(ret, @search_keyword)
      end
      ret
    end
    
    private
    def body0(is_sample, secname, category)
      @cache.read_did(@doc) {|r| return r }
      run_template('did', binding())
    end
  end
  
  class MenuScreen < TemplateScreen
    def initialize(params, search_query)
      super params
      @query = (search_query || '').strip
    end
    
    def body
      ret = body0()
      ret = highlight_keywords(ret, @query) unless index?
      ret
    end
    
    def index?
      @query.empty?
    end
    
    private
    def body0
      @cache.read_menu {|r| return r } if index?
      run_template('menu')
    end
    
    def search_result(cats, models)
      if index?
        result = []
        cats.each do |cat|
          result << [cat.name, cat.to_a]
        end
      else
        models = models.search(@query)
        prev_category = nil
        pos = 0
        result = []
        models.each_with_index do |obj, i|
          category = obj.category.name
          if prev_category and prev_category != category
            result << [prev_category, models[pos...i]]
            pos = i
          end
          prev_category = category
        end
        if prev_category
          result << [prev_category, models[pos..-1]]
        end
      end
      
      result
    end
    
    def each_section(&block)
      [[?R, 'リファレンス', @db.refcats, @db.refs],
       [?D, 'ドキュメント', @db.doccats, @db.docs],
       [?S, 'サンプル',     @db.samcats, @db.samples]].each(&block)
    end
    
    def doc_summary(doc)
      s = doc.summary(75)
      i = s.rindex(" ")
      i < 10 ? s : s[0..i]
    end
  end
  
  class OpenSearchScreen < TemplateScreen
    def http_response_header_options
      super.update('type' => 'application/opensearchdescription+xml', 'charset' => 'UTF-8')
    end
    
    def body
      @cache.read_opensearch {|r| return r }
      run_template('opensearch').kconv(Kconv::UTF8, Kconv::SJIS)
    end
  end
  
  class FunctionListJSScreen < TemplateScreen
    def http_response_header_options
      super.update('type' => 'text/javascript')
    end
    
    def body
      run_template('function_list')
    end
    
    private
    def to_js_string_literal(str)
      result = "\""
      str.each_byte do |ch|
        case ch
        when ?\\
          result << "\\\\"
        when ?\"
          result << "\\\""
        when ?\s .. ?~
          result << ch
        else
          result << ("\\x%02x" % ch)
        end
      end
      result << "\""
      result
    end
  end
  
  class PlainTextScreen < TemplateScreen
    def initialize(params, path, uri)
      super params
      @path = path
      @content = file_content(path)
      @screen = @content ? nil : NotFoundScreen.new(params, uri)
    end
    
    def http_response_header_options
      return @screen.http_response_header_options if @screen
      ret = super
      ret['type'] = 'text/plain'
      begin
        ret['Last-Modified'] = CGI.rfc1123_date(File.mtime(@path.gsub('\\', '/')))
      rescue SystemCallError
      end
      ret
    end
    
    def body
      return @screen.body if @screen
      @content
    end
  end
  
  class MovedScreen < TemplateScreen
    def initialize(params, uri)
      super params
      @uri = uri
    end
    
    def http_response_header_options
      super.update('status' => 'MOVED', 'Location' => @uri)
    end
    
    def body
      <<-EndHTML
    <title>Document Moved</title>
    <h1>Document Moved</h1>
    <p><a href="#{html_escape(@uri)}">#{html_escape(@uri)}</a></p>
      EndHTML
    end
  end
end
