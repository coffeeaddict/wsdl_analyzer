require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require "sinatra/reloader" if development?
require 'logger'

require File.join(File.dirname(__FILE__),'lib','app.rb')

# write all that goes to STD(OUT|ERR) to log/rack.log
log = File.new(File.join(File.dirname(__FILE__), "log", "rack.log"), "a+")
$stdout.reopen(log)
$stderr.reopen(log)

run Sinatra::Application