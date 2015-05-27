# coding: utf-8

module OHDL
  class Config
    def initialize(&block)
      if block
        instance_eval(&block)
      end
      @origin  ||= ENV['HTTP_HOST'] ? "http://#{ENV['HTTP_HOST']}" : ''
      @uripath ||= ENV['SCRIPT_NAME'] ? "#{File.dirname(ENV['SCRIPT_NAME'])}/".sub(/\/+/,'/') : '/'
      @dbfilename ||= 'hdlbase.xdb'
      @template_dir ||= 'template'
      @cache_dir ||= 'cache'
    end
    
    attr_reader :origin, :uripath, :dbfilename, :template_dir, :cache_dir
    
    def baseuri
      @origin + @uripath
    end
  end
end

