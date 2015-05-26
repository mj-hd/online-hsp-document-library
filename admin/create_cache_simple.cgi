#!/usr/bin/env ruby
require 'pathname'
require 'uri'
require 'cgi'
require 'fileutils'
require 'stringio'
Dir.chdir Pathname(File.dirname($0)).parent
require 'ohdl/config'
require 'ohdl/application'
require 'ohdl/screen'
require 'ohdl/database'

@all_targets = %w(home frameset verinfo menu opensearch refs docsams refcats doccats samcats function_list_js)
@targets_map = {
  'home' => 'ホーム',
  'frameset' => 'フレームセット',
  'verinfo' => 'バージョン情報',
  'menu' => 'メニュー',
  'opensearch' => 'OpenSearch',
  'refs' => 'リファレンス',
  'docsams' => 'ドキュメント・サンプル',
  'refcats' => 'リファレンスカタログ',
  'doccats' => 'ドキュメントカタログ',
  'samcats' => 'サンプルカタログ',
  'function_list_js' => 'function_list.js',
}

def fix_targets(t)
  if t.include?("all")
    t = @all_targets
  end
  t = t.select {|i| @targets_map.has_key?(i) }
  t.uniq!
  t
end

def output(targets, start_time, end_time)
  s = StringIO.new
  s.puts '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">'
  s.puts "<title>OHDL #{CGI.escapeHTML(File.basename($0))}</title>"
  s.puts "<h1>OHDL #{CGI.escapeHTML(File.basename($0))}</h1>"
  if targets.length > 0
    s.puts "<p>以下のキャッシュを作成しました</p>"
    s.puts "<ul>"
    targets.each do |t|
      s.puts "<li>#{CGI.escapeHTML(@targets_map[t])}</li>"
    end
    s.puts "</ul>"
    s.puts "開始時刻: #{CGI.escapeHTML(start_time.strftime("%Y/%m/%d %H:%M:%S"))}</p>"
    s.puts "<p>終了時刻: #{CGI.escapeHTML(end_time.strftime("%Y/%m/%d %H:%M:%S"))}</p>"
    s.puts "<p>実行時間: #{CGI.escapeHTML((end_time - start_time).to_s)} sec</p>"
  else
    s.puts '<p>create_cache_simple.cgi では一回のリクエストで全てのキャッシュの作成を済ませます。<a href="create_cache.cgi">create_cache.cgi</a>はリクエストを何回かに分けて途中経過を表示するバージョンです。</p>'
  end
  s.puts '<form method="post" action="">'
  s.puts '<fieldset>'
  s.puts '<legend>キャッシュ作成</legend>'
  s.puts '<input type="hidden" name="exc" value="1">'
  s.puts '<ul>'
  s.puts '<li><label><input type="checkbox" name="target" value="all">全て</label></li>'
  @all_targets.each do |t|
    s.print %Q!<li><label><input type="checkbox" name="target" value="#{CGI.escapeHTML(t)}"!
    s.print ' checked' if targets.include?(t)
    s.puts ">#{CGI.escapeHTML(@targets_map[t])}</label></li>"
  end
  s.puts '<p><input type="submit" value="作成"></p>'
  s.puts '</fieldset>'
  s.puts '</form>'
  s.string
end

begin
  config = OHDL::Config.new() do
    @uripath = "#{File.dirname(File.dirname(ENV['SCRIPT_NAME']))}/".sub(/\/+/,'/')
  end
  db = OHDL::Database.new('hdlbase.xdb')
  screen_manager = OHDL::ScreenManager.new(config, db, :no_cache => true)
  cache = OHDL::CacheWriter.new(config, db, screen_manager)
  cgi = CGI.new
  targets = fix_targets(cgi.request_method.upcase == 'POST' ? cgi.params['target'] : [])
  start_time = end_time = nil
  if targets.length > 0
    start_time = Time.now
    targets.each do |t|
      cache.send("cache_#{t}")
    end
    end_time = Time.now
  end
  cgi.out('charset' => 'UTF-8', 'language' => 'ja') do
    output(targets, start_time, end_time)
  end
rescue Exception => e
  puts 'Content-Type: text/plain'
  puts
  p e
  puts e.backtrace
ensure
  db.close if db
end
