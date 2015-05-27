#!/usr/bin/env ruby
# encoding: utf-8

print 'account name: '
account_name = $stdin.gets.chomp
if account_name == ''
  account_name = ENV['USER']
end

print 'password: '
system 'stty -echo'
password = $stdin.gets.chomp
system 'stty echo'
puts

open('.htaccess', 'wb') do |f|
  f.puts "AuthUserFile #{File.expand_path(File.dirname($0))}/.htpasswd"
  f.puts "AuthGroupFile /dev/null"
  f.puts "AuthName \"OHDL admin\""
  f.puts "AuthType Basic"
  f.puts "require valid-user"
end

salt = [rand(64),rand(64)].pack("C*").tr("\x00-\x3f","A-Za-z0-9./")
open('.htpasswd', 'wb') do |f|
  f.puts "#{account_name}:#{password.crypt(salt)}"
end
