#!/usr/local/bin/ruby
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

CacheRunningData = Struct.new(:cache, :db, :targets, :step, :offset)

def cache_each_refs(data, step)
  refs = data.db.refs
  size = refs.size
  cache = data.cache
  i = data.offset
  return if i < 0
  while i < size
    yield step, i
    cache.cache_ref(refs[i])
    i += 1
  end
end

def cache_each_docsams(data, step)
  docsams = data.db.docsams
  size = docsams.size
  cache = data.cache
  i = data.offset
  return if i < 0
  while i < size
    yield step, i
    cache.cache_doc(docsams[i])
    i += 1
  end
end

def cache_each(data, &b)
  step = data.step
  targets = data.targets
  size = targets.size
  cache = data.cache
  while step < size
    case targets[step]
    when 'refs'
      cache_each_refs data, step, &b
    when 'docsams'
      cache_each_docsams data, step, &b
    else
      yield step, 0
      cache.send "cache_#{targets[step]}"
    end
    data.offset = 0
    step += 1
  end
  data.step = step
end

def start_cache(cache, db, targets, step, offset)
  return targets.size, 0 unless (0...targets.size).include?(step)
  data = CacheRunningData.new(cache, db, targets, step, offset)
  start_time = Time.now
  count = 0
  cache_each(data) do |step, offset|
    if count != 0 and Time.now - start_time >= 5
      return step, offset
    end
    count += 1
  end
  return data.step, data.offset
end

def target_size(db, target)
  case target
  when 'refs'
    db.refs.size
  when 'docsams'
    db.docsams.size
  end
end

def h(s)
  CGI.escapeHTML(s.to_s)
end

def output(db, targets, step, offset, completed, start_time)
  if completed
    return output_completed(db, targets, start_time)
  end

  if targets.empty?
    return output_index(db)
  end
  
  s = StringIO.new
  s.puts '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">'
  url = File.basename($0)
  if step >= targets.size
    url << "?completed=1"
  else
    url << "?step=#{URI.escape(step.to_s)}&offset=#{URI.escape(offset.to_s)}"
  end
  url << "&start_time=#{URI.escape(start_time.to_f.to_s)}"
  targets.each {|t| url << "&target=#{URI.escape(t)}" }
  s.puts %Q!<meta http-equiv="Refresh" content="1;URL=#{h(url)}">!
  
  s.puts "<title>OHDL #{h(File.basename($0))}</title>"
  s.puts "<h1>OHDL #{h(File.basename($0))}</h1>"
  s.puts "<p>キャッシュ作成中...</p>"
  s.puts "<p>キャッシュ作成済み:</p>"
  s.puts "<ul>"
  step.times do |i|
    s.puts "<li>#{h(@targets_map[targets[i]])}</li>"
  end
  if offset > 0
    size = target_size(db, targets[step])
    s.puts "<li>#{h(@targets_map[targets[step]])} (#{h(offset)} / #{h(size)})</li>"
  end
  s.puts "</ul>"
  not_completed_start = step + (offset > 0 ? 1 : 0)
  if not_completed_start < targets.size
    s.puts '<p>キャッシュ待ち:</p>'
    s.puts '<ul>'
    (not_completed_start...targets.size).each do |i|
      s.puts "<li>#{h(@targets_map[targets[i]])}</li>"
    end
    s.puts '</ul>'
  end
  s.puts "開始時刻: #{h(start_time.strftime("%Y/%m/%d %H:%M:%S"))}</p>"
  now_time = Time.now
  s.puts "現在時刻: #{h(now_time.strftime("%Y/%m/%d %H:%M:%S"))}</p>"
  s.puts "<p>実行時間: #{h(now_time - start_time)} sec</p>"
  s.puts %Q!<p><a href="#{h(File.basename($0))}">中断</a></p>!
  s.string
end

def output_index(db)
  s = StringIO.new
  s.puts '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">'
  s.puts "<title>OHDL #{h(File.basename($0))}</title>"
  s.puts "<h1>OHDL #{h(File.basename($0))}</h1>"
  s.puts '<form method="get" action="">'
  s.puts '<fieldset>'
  s.puts '<legend>キャッシュ作成</legend>'
  s.puts '<input type="hidden" name="exc" value="1">'
  s.puts '<ul>'
  s.puts '<li><label><input type="checkbox" name="target" value="all">全て</label></li>'
  @all_targets.each do |t|
    s.print %Q!<li><label><input type="checkbox" name="target" value="#{h(t)}">#{h(@targets_map[t])}</label></li>!
  end
  s.puts '<p><input type="submit" value="作成"></p>'
  s.puts '</fieldset>'
  s.puts '</form>'
  s.string
end

def output_completed(db, targets, start_time)
  s = StringIO.new
  s.puts '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">'
  s.puts "<title>OHDL #{h(File.basename($0))}</title>"
  s.puts "<h1>OHDL #{h(File.basename($0))}</h1>"
  s.puts '<p>キャッシュの作成が完了しました</p>'
  s.puts '<ul>'
  targets.each do |t|
    s.puts "<li>#{h(@targets_map[t])}</li>"
  end
  s.puts '</ul>'
  s.puts "開始時刻: #{h(start_time.strftime("%Y/%m/%d %H:%M:%S"))}</p>"
  end_time = Time.now
  s.puts "終了時刻: #{h(end_time.strftime("%Y/%m/%d %H:%M:%S"))}</p>"
  s.puts "<p>実行時間: #{h(end_time - start_time)} sec</p>"
  s.puts %Q!<p><a href="#{h(File.basename($0))}">戻る</a></p>!
  s.string
end

begin
  config = OHDL::Config.new do
    @uripath = "#{File.dirname(File.dirname(ENV['SCRIPT_NAME']))}/".sub(/\/+/,'/')
  end
  db = OHDL::Database.new('hdlbase.xdb')
  screen_manager = OHDL::ScreenManager.new(config, db, :no_cache => true)
  cache = OHDL::CacheWriter.new(config, db, screen_manager)
  cgi = CGI.new
  targets = fix_targets(cgi.params['target'])
  step = (cgi.params['step'][0] || '').to_i
  offset = (cgi.params['offset'][0] || '').to_i
  completed = (cgi.params['completed'][0] || '').to_i != 0
  start_time = cgi.params['start_time'][0] ? Time.at(cgi.params['start_time'][0].to_f) : Time.now
  unless completed
    step, offset = start_cache(cache, db, targets, step, offset)
  end
  cgi.out('charset' => 'UTF-8', 'language' => 'ja') do
    output(db, targets, step, offset, completed, start_time)
  end
rescue Exception => e
  puts 'Content-Type: text/plain'
  puts
  p e
  puts e.backtrace
ensure
  db.close if db
end
