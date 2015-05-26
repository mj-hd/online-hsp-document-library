#!/usr/bin/env ruby

# ドキュメントのパスの変更のデータを作る
# 古いパスから新しいパスへリダイレクトするために使う
# Old, New ともに URL エンコードせずに登録

require 'pathname'
require 'uri'
Dir.chdir Pathname(File.dirname($0)).parent
require './ohdl/database'

def main
  add_all_files 'docs', 'doclib'
  add_dir 'sample/d3m', 'sample/d3module'
  add_doclib_path 'HS_BIBLE.txt', 'HSP Document Library/HS_BIBLE.txt'
  add_path 'sample/basic/modtest1.hsp', 'sample/module/modtest1.hsp'
  add_path 'sample/basic/modtest2.hsp', 'sample/module/modtest2.hsp'
  add_path 'sample/basic/modtest3.hsp', 'sample/module/modtest3.hsp'
  add_path 'sample/basic/modtest4.hsp', 'sample/module/modtest4.hsp'
  #add_path 'sample/easy3d/e3dhsp3_alpha.hsp', 'sample/Easy3D/e3dhsp3_alpha2.hsp'
  #add_path 'sample/easy3d/e3dhsp3_texturechange.hsp', 'sample/Easy3D/e3dhsp3_TextureChange2.hsp'
  add_path 'sample/game/bom.bmp', 'sample/module/bom.bmp'
  add_path 'sample/game/bom.wav', 'sample/module/bom.wav'
  add_path 'sample/game/defcfunc.hsp', 'sample/module/defcfunc.hsp'
  add_path 'sample/game/grotate.hsp', 'sample/basic/grotate.hsp'
  add_path 'sample/game/shoot.hsp', 'sample/module/shoot.hsp'
  add_path 'sample/game/shootchr.bmp', 'sample/module/shootchr.bmp'
  add_path 'sample/new/ahtman_kw.hsp', 'sample/misc/ahtman_kw.hsp'
  add_path 'sample/new/arraynote.hsp', 'sample/basic/arraynote.hsp'
  add_path 'sample/new/atan_grect.hsp', 'sample/basic/atan_grect.hsp'
  add_path 'sample/new/dirinfo.hsp', 'sample/basic/dirinfo.hsp'
  add_path 'sample/new/dragdrop.hsp', 'sample/misc/dragdrop.hsp'
  add_path 'sample/new/emes.hsp', 'sample/basic/emes.hsp'
  add_path 'sample/new/grect.hsp', 'sample/basic/grect.hsp'
  add_path 'sample/new/groll.hsp', 'sample/basic/groll.hsp'
  add_path 'sample/new/gsquare.hsp', 'sample/basic/gsquare.hsp'
  add_path 'sample/new/hsptv_test.hsp', 'sample/misc/hsptv_test.hsp'
  add_path 'sample/new/hsv.hsp', 'sample/basic/hsv.hsp'
  add_path 'sample/new/imgload.hsp', 'sample/comobj/imgload.hsp'
  add_path 'sample/new/label_type.hsp', 'sample/misc/label_type.hsp'
  add_path 'sample/new/libptr.hsp', 'sample/misc/libptr.hsp'
  add_path 'sample/new/macro.hsp', 'sample/misc/macro.hsp'
  add_path 'sample/new/menusample.hsp', 'sample/basic/menusample.hsp'
  add_path 'sample/new/mkpack.hsp', 'sample/misc/mkpack.hsp'
  add_path 'sample/new/modvar.hsp', 'sample/module/modvar.hsp'
  add_path 'sample/new/mouse.hsp', 'sample/basic/mouse2.hsp'
  add_path 'sample/new/nkfcnv.hsp', 'sample/misc/nkfcnv.hsp'
  add_path 'sample/new/rssload.hsp', 'sample/comobj/rssload.hsp'
  add_path 'sample/new/star.hsp', 'sample/basic/star.hsp'
  add_path 'sample/new/starmove.hsp', 'sample/basic/starmove.hsp'
  add_path 'sample/new/strf.hsp', 'sample/basic/strf.hsp'
  add_path 'sample/new/sysinfo.hsp', 'sample/basic/sysinfo.hsp'
  add_path 'sample/new/web.hsp', 'sample/comobj/web.hsp'
  add_path 'sample/new/winmove.hsp', 'sample/misc/winmove.hsp'
  add_path 'sample/new/winobj.hsp', 'sample/misc/winobj.hsp'
  #add_refcat 'Easy3D(HSP3)', 'Easy3D For HSP3'
  
  add_path 'opensearch.xml', 'opensearch/'
end

def add_all_files(old, new)
  Dir.chdir(new) do
    Dir['**/*'].each do  |path|
      next unless File.file?(path)
      add_path File.join(old, path), File.join(new, path)
    end
  end
end

def add_dir(old, new)
  old = remove_last_separator(old)
  new = remove_last_separator(new)

  add_path old, new
  add_path old + '/', new + '/'
  add_all_files old, new
end

def remove_last_separator(path)
  path.sub(/\/\z/, '')
end

def add_doclib_path(old, new)
  add_path "docs/" + old, "doclib/" + new
  add_path "doclib/" + old, "doclib/" + new
end

def add_path(old, new)
  return if old == new
  printf "%p -> %p\n", old, new
  @sqdb.execute 'REPLACE INTO Moved (Old, New) VALUES(lower(?), ?)', old, new
end

def add_refcat(old, new)
  add_path "reference/#{old}/", "reference/#{new}/"
  category = @db.refcats.find_by_name(new)
  raise "category %p not found" % new unless category
  category.each do |ref|
    add_path "reference/#{old}/#{ref.name}/", "reference/#{new}/#{ref.name}/"
  end
end

begin
  @db = OHDL::Database.new('hdlbase.xdb')
  @sqdb = @db.sqdb

  @sqdb.execute 'DROP TABLE IF EXISTS Moved'
  @sqdb.execute 'CREATE TABLE Moved (ID INTEGER PRIMARY KEY, Old UNIQUE, New)'
  @sqdb.execute 'CREATE INDEX IX_Moved1 ON Moved (Old)'

  @sqdb.transaction do
    main
  end
  
ensure
  @db.close if @db
end
