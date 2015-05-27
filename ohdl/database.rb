# coding: utf-8

require 'sqlite3'
require 'kconv'

module OHDL
  class Database
    def initialize(file_name)
      @sqdb = SQLite3::Database.new(file_name)

      # SJISからUTF8への変換
      @sqdb.type_translation = true
      [nil, "text", "varchar"].each do |type|
        @sqdb.translator.add_translator(type) do |t, v|
          if v.class == String then
            v.encode("UTF-8")
          else
            v
          end
        end
      end

      @params = Params.new(self, @sqdb)
      
      @refcats = ReferenceCategoryContainer.new(@params)
      @doccats = DocCategoryContainer.new(@params)
      @samcats = SampleCategoryContainer.new(@params)
      
      @refs = ReferenceContainer.new(@params)
      @docs = DocContainer.new(@params)
      @samples = SampleContainer.new(@params)
      @docsams = DocSampleContainer.new(@params)
      @ref_name_cache = nil
    end
    
    attr_reader :refcats, :doccats, :samcats, :refs, :docs, :samples, :docsams, :ref_name_cache, :sqdb

    def close
      @sqdb.close
    end

    def search_sample(name)
      @sqdb.execute( 'SELECT ID FROM Docs WHERE Type="hsp" and Search LIKE ? and Search GLOB ? order by lower(Title)', 
                     "%#{name}%", "*[^0-9a-z]#{name}[^0-9a-z]*" ).map do |id,*|
        Sample.new(@params, id)
      end
    end
    
    # リファレンスから似た名前の項目を探す
    def mosikasite(name)
      len = name.length
      return [] unless len >= 3 and /\A[\x00-\x7f]+\z/n.match(name)
      count = @sqdb.get_first_value('SELECT count(*) FROM Help WHERE Name LIKE ? OR Mod LIKE ?', name, name).to_i
      return [] unless count == 0
      
      min_length = max_length = len
      if len >= 4
        min_length -= 1
        max_length += 1
      end
      
      @sqdb.execute('SELECT Name FROM Help WHERE ' \
                    '(Name LIKE ? OR Name LIKE ? OR Name LIKE ? OR Name LIKE ?) ' \
                    'AND (length(Name)>=? AND length(Name)<=?) ORDER BY lower(Name)',
                    name[0, len*3/4]+'%',
                    name[0, len/2]+'%'+name[len*3/4..-1],
                    name[0, len/4]+'%'+name[len/2..-1],
                    '%'+name[len/4..-1],
                    min_length, max_length).flatten
    end

    def sqlite_version
      @sqdb.get_first_value('SELECT sqlite_version()')
    end

    def count_files
      @sqdb.get_first_value('SELECT count(ID) FROM Files').to_i
    end
    
    def count_dirs
      @sqdb.get_first_value('SELECT count(ID) FROM Dir').to_i
    end
    
    def find_doc_or_sample_by_id(id)
      id = @sqdb.get_first_value('SELECT ID, Type FROM Docs WHERE ID = ?', id)
      DocAndSample.new(@params, id) if id
    end
    
    def find_doc_or_sample_by_path(path)
      id = @sqdb.get_first_value('SELECT ID, Type FROM Docs WHERE Path = ?', path.gsub('/','\\'))
      DocAndSample.new(@params, id) if id
    end
    
    def search_file_path_by_basename(basename)
      @sqdb.get_first_value("SELECT Path FROM Files WHERE Fn=lower(?)", basename)
    end
    
    def search_moved(path)
      @sqdb.get_first_value("SELECT New FROM Moved WHERE Old=lower(?)", path)
    end
    
    def create_ref_name_cache
      return if @ref_name_cache
      cache = {}
      @sqdb.execute('SELECT ID, lower(Name) FROM Help') {|id,name| cache[name] = id.to_i }
      @ref_name_cache = cache
    end
    
    alias inspect to_s

    Params = Struct.new(:db, :sqdb)
    
    class Base
      def initialize(params)
        @params = params
        @db = params.db
        @sqdb = params.sqdb
      end
    end
    
    module MReference
      def reference?() true end
      def doc?() false end
      def sample?() false end
    end

    module MDoc
      def reference?() false end
      def doc?() true end
      def sample?() false end
    end

    module MSample
      def reference?() false end
      def doc?() false end
      def sample?() true end
    end
    
    class CategoryContainer < Base
      include Enumerable
      
      def length
        size()
      end
      
      def empty?
        each { return false }
        true
      end
    end
    
    class ReferenceCategoryContainer < CategoryContainer
      include MReference
      def each
        @sqdb.execute('SELECT Mod, count(ID) FROM Help ' \
                      'GROUP BY Mod ORDER BY lower(Mod)') do |name,size|
          yield ReferenceCategory.new(@params, name, size)
        end
      end
      
      def find_by_name(name)
        row = @sqdb.get_first_row('SELECT Mod, count(ID) FROM Help WHERE Mod=? GROUP BY Mod', name)
        if row
          ReferenceCategory.new(@params, *row)
        elsif name.empty?
          ReferenceCategory.new(@params, name, 0)
        end
      end
      
      def size
        @sqdb.get_first_value('SELECT count(*) FROM (SELECT Mod FROM Help GROUP BY Mod)').to_i
      end
    end
    
    class DocAndSampleCategoryContainer < CategoryContainer
      def each
        @sqdb.execute("SELECT Catego, count(ID) FROM Docs WHERE Type#{hspoper}'hsp' " \
                      'GROUP BY Catego ORDER BY lower(Catego)') do |name,size|
          yield pcs_new(name, size)
        end
      end
      
      def find_by_name(name)
        row = @sqdb.get_first_row("SELECT Catego, count(ID) FROM Docs WHERE Type#{hspoper}'hsp' " \
                                  'AND Catego=? GROUP BY Catego', name)
        if name.empty? and row.nil?
          # 標準カテゴリがない場合 : ファーストカテゴリ選択
          row = @sqdb.get_first_row("SELECT Catego, count(ID) FROM Docs WHERE Type#{hspoper}'hsp' " \
                                    'GROUP BY Catego ORDER BY lower(Catego) LIMIT 1')
        end
        if row
          pcs_new(*row)
        elsif name.empty?
          pcs_new(name, 0)
        end
      end
      
      def size
        @sqdb.get_first_value("SELECT count(*) FROM (SELECT Catego FROM Docs WHERE Type#{hspoper}'hsp' GROUP BY Catego)").to_i
      end
    end
    
    class DocCategoryContainer < DocAndSampleCategoryContainer
      include MDoc
      private
      def pcs_new(name, size)
        DocCategory.new(@params, name, size)
      end
      
      def hspoper() '!=' end
    end
    
    class SampleCategoryContainer < DocAndSampleCategoryContainer
      include MSample
      private
      def pcs_new(name, size)
        SampleCategory.new(@params, name, size)
      end
      
      def hspoper() '=' end
    end

    class Category < Base
      include Enumerable
      
      def initialize(params, name, size)
        super params
        @name = name
        @size = size.to_i
      end
      
      attr_reader :name, :size
      
      alias length size
      
      def inspect
        '#<%s: name=%p>' % [self.class, @name]
      end
      
      def empty?
        @size == 0
      end
    end
    
    class ReferenceCategory < Category
      include MReference
      def versions
        @sqdb.execute('SELECT Ver FROM Help WHERE Mod=? and Ver != "" '\
                      'GROUP BY Ver ORDER BY lower(Ver) desc', @name).flatten
      end
      
      def metadata
        @sqdb.execute('SELECT Ver, Date, Author FROM Help ' \
                      'WHERE Mod=? and (Ver || Date || Author != "") ' \
                      'GROUP BY Ver, Date, Author ' \
                      'ORDER BY lower(Ver) desc, lower(Date) desc, lower(Author)',
                      @name)
      end
      
      def groups
        @sqdb.execute('SELECT Group3, count(ID) as IDs FROM Help WHERE Mod=? '\
                      'GROUP BY Group3 ORDER BY lower(Group3)', @name)
      end
      
      def each
        @sqdb.execute('SELECT ID FROM Help WHERE Mod=? ' \
                      'ORDER BY lower(Group3), Group3, lower(Name)', @name) do |id,|
          yield Reference.new(@params, id)
        end
      end
    end
    
    class DocAndSampleCategory < Category
      def each
        @sqdb.execute("SELECT ID FROM Docs WHERE Catego=? AND " \
                      "Type#{hspoper}'hsp' ORDER BY lower(Title), lower(Path)", @name) do |id,|
          yield pcs_new(id)
        end
      end
      
      def each_order_by_dir
        @sqdb.execute("SELECT Docs.ID FROM Docs LEFT JOIN Files ON Docs.Path=Files.Path "\
                      "WHERE Docs.Type#{hspoper}'hsp' AND Catego=? " \
                      "ORDER BY lower(Dir), lower(Title)", @name) do |id,|
          yield pcs_new(id)
        end
      end
      
      def directories
        @sqdb.execute("SELECT Dir FROM Docs " \
                      "LEFT JOIN Files ON Docs.Path=Files.Path " \
                      "WHERE Docs.Type#{hspoper}'hsp' AND Catego=? " \
                      "GROUP BY Dir ORDER BY lower(Dir)", @name).flatten
      end
    end
    
    class DocCategory < DocAndSampleCategory
      include MDoc
      private
      def hspoper() '!=' end
      def pcs_new(id)
        Doc.new(@params, id)
      end
    end
    
    class SampleCategory < DocAndSampleCategory
      include MSample
      private
      def hspoper() '=' end
      def pcs_new(id)
        Sample.new(@params, id)
      end
    end

    class ModelContainer < Base
      include Enumerable
      
      def length
        size()
      end
      
      def empty?
        each { return false }
        true
      end
      
      def search(query)
        whereq = ''
        binds = []
        target = search_target()
        query.split(' ').each do |word|
          next if word.empty?
          whereq << 'AND'
          if word[0] == ?-
            whereq << ' NOT'
            word[0,1] = ''
          end
          whereq << '('
          # 単純検索
          whereq << target << ' LIKE ?'
          binds << "%#{word}%"
          if (word[0] || 0) <= ?z # 英単語検索
            whereq << " AND lower(' '||#{target}||' ') GLOB lower(?)"
            binds << "*[^a-z]#{word}*"
          end
          whereq << ')'
        end
        search_run(whereq, binds)
      end
    end
    
    class ReferenceContainer < ModelContainer
      include MReference
      def find_by_name(name)
        if cache = @db.ref_name_cache
          id = cache[name.downcase]
          return id && Reference.new(@params, id)
        end
        id = @sqdb.get_first_value('SELECT ID FROM Help WHERE Name=?', name) ||
             @sqdb.get_first_value('SELECT ID FROM Help WHERE lower(Name)=lower(?)', name)
        Reference.new(@params, id) if id
      end
      
      def find_by_mod_and_name(mod, name)
        id = @sqdb.get_first_value('SELECT ID FROM Help WHERE ' \
                                   '(Name=? OR lower(Name)=lower(?)) AND Mod=?', name, name, mod)
        Reference.new(@params, id) if id
      end
      
     def find_by_id(id)
       id = @sqdb.get_first_value('SELECT ID FROM Help WHERE ID=?', id)
       Reference.new(@params, id) if id
     end
      
      def size
        @sqdb.get_first_value('SELECT count(ID) FROM Help').to_i
      end
      
      def each
        @sqdb.execute('SELECT ID FROM Help ' \
                      'ORDER BY lower(Mod), lower(Group3), lower(Name)') do |id,|
          yield Reference.new(@params, id)
        end
      end
      
      def [](offset)
        id = @sqdb.get_first_value('SELECT ID FROM Help LIMIT 1 OFFSET ?', offset)
        Reference.new(@params, id) if id
      end
      
      private
      def search_target
        'Name||" "||Summary||" "||Inst||" "||Prm||" "||Prm2||" "||Sample||" "||' \
        'Href||" "||Portinf||" "||Port||" "||Group3||" "||Type||" "||' \
        'Note||" "||Url||" "||Ver||" "||Date||" "||Mod||" "||Author||" "||Path'
      end
      
      def search_run(whereq, binds)
        @sqdb.execute("SELECT ID FROM Help WHERE 1=1 #{whereq} ORDER BY lower(Mod), lower(Group3), Group3, lower(Name)", *binds).map do |id,|
          Reference.new(@params, id)
        end
      end
    end
    
    class DocSampleContainer < ModelContainer
      def find_by_path(path)
        id = @sqdb.get_first_value('SELECT id FROM Docs WHERE Path = ?', path.gsub('/','\\'))
        DocAndSample.new(@params, id) if id
      end
      
     def find_by_id(id)
       id = @sqdb.get_first_value('SELECT ID Docs Help WHERE ID=?', id)
       DocAndSample.new(@params, id) if id
     end
      
      def size
        @sqdb.get_first_value("SELECT count(ID) FROM Docs").to_i
      end
      
      def each
        @sqdb.execute("SELECT ID FROM Docs ORDER BY lower(Catego), lower(Title)") do |id,|
          yield DocAndSample.new(@params, id)
        end
      end
      
      def [](offset)
        id = @sqdb.get_first_value('SELECT ID FROM Docs LIMIT 1 OFFSET ?', offset)
        DocAndSample.new(@params, id) if id
      end
    end
    
    class DocAndSampleContainer < ModelContainer
      def find_by_path(path)
        id = @sqdb.get_first_value('SELECT id FROM Docs WHERE Path = ? AND ' \
                                   "Type#{hspoper}'hsp'", path.gsub('/','\\'))
        pcs_new(id) if id
      end
      
      def size
        @sqdb.get_first_value("SELECT count(ID) FROM Docs WHERE TYPE#{hspoper}'hsp'").to_i
      end
      
      def each
        @sqdb.execute("SELECT ID FROM Docs WHERE Type#{hspoper}'hsp'" \
                      'ORDER BY lower(Catego), lower(Title)') do |id,|
          yield pcs_new(id)
        end
      end
      
      private
      def search_target
        'Search'
      end
      
      def search_run(whereq, binds)
        @sqdb.execute("SELECT ID FROM Docs WHERE Type#{hspoper}'hsp' #{whereq} " \
                      'ORDER BY lower(Catego), lower(Title), lower(Path)', *binds).map do |id,|
          pcs_new(id)
        end
      end
    end
    
    class DocContainer < DocAndSampleContainer
      include MDoc
      private
      def hspoper() '!=' end
      def pcs_new(id)
        Doc.new(@params, id)
      end
    end
    
    class SampleContainer < DocAndSampleContainer
      include MSample
      private
      def hspoper() '=' end
      def pcs_new(id)
        Sample.new(@params, id)
      end
    end
    
    class Model < Base
      def initialize(params, id)
        super params
        @id = id.to_i
      end 

      attr_reader :id
    end

    class Reference < Model
      include MReference
      %w(name summary mod ver date author group3 prm prm2
         inst sample href portinf port url type note path).each do |name|
        module_eval( <<-EOS )
          def #{name}
            @sqdb.get_first_value('SELECT #{name.capitalize} FROM Help WHERE ID = ?', @id)
          end
        EOS
      end
      
      alias category mod
      alias group group3
      
      def related
        result = []
        href.each_line do |line|
          line.chomp!
          result << Reference.find_by_name(@sqdb, line)
        end
        result
      end
      
      def category
        @db.refcats.find_by_name(mod())
      end
      
      def inspect
        '#<%s: id=%p, name=%p>' % [self.class, @id, name()]
      end
    end
    
    class DocAndSample < Model
      %w(path type title catego search).each do |name|
        module_eval( <<-EOS )
          def #{name}
            @sqdb.get_first_value('SELECT #{name.capitalize} FROM Docs WHERE ID = ?', @id)
          end
        EOS
      end
      
      alias category catego
      alias name title
      
      def summary(size)
        @sqdb.get_first_value('SELECT substr(Search,SmryIdx,?) FROM Docs WHERE ID = ?', size, @id)
      end
      
      def inspect
        '#<%s: id=%p, path=%p>' % [self.class, @id, path()]
      end
      
      def thumb_img_path
        path = path().gsub('\\', '/')
        dirname = File.dirname(path).gsub('/', '\\')
        basename = File.basename(path)
        @sqdb.get_first_value("SELECT Path FROM Files WHERE Path LIKE ?", "#{dirname}%#{basename}.___")
      end
      
      class << self
        alias pure_new new
        def new(params, id)
          d = pure_new(params, id)
          (d.type == 'hsp' ? Sample : Doc).new(params, id)
        end
      end
    end
    
    class Doc < DocAndSample
      include MDoc
      def self.new(params, id)
        pure_new(params, id)
      end
      
      def category
        @db.doccats.find_by_name(catego())
      end
    end
    
    class Sample < DocAndSample
      include MSample
      def self.new(params, id)
        pure_new(params, id)
      end
      
      def category
        @db.samcats.find_by_name(catego())
      end
    end
  end
end
