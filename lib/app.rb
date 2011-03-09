require 'sinatra'
require 'sinatra/logger'
require 'fileutils'
require 'open-uri'
require 'digest'
require File.join(File.dirname(__FILE__),'wsdl_analyzer.rb')

include FileUtils

# configure sinatra
set :environment, ENV['RACK_ENV'] || :development
set :sessions, true
set :root, File.dirname(__FILE__)

disable :run, :reload

before do
  response.header['Cache-control'] = 'no-store'
end

get '/' do
  erb :index
end

post '/post' do
  if params[:wsdl_file]
    if (tmpfile = params[:wsdl_file][:tempfile]) &&
       (name = params[:wsdl_file][:filename])

      File.open("/tmp/#{name}" ,File::CREAT|File::TRUNC|File::WRONLY) do |f|
        while line = tmpfile.gets
          f.puts line
        end
      end

      session[:file] = "/tmp/#{name}"
    end

  elsif (url = params[:wsdl_url])
    file_name = Digest::SHA1.hexdigest("#{$$} #{Time.now} #{url}")[0..8]
    file = File.open("/tmp/#{file_name}.wsdl", File::CREAT|File::TRUNC|File::WRONLY)

    open(url) do |u|
      file.puts u.gets
    end

    session[:file] = "/tmp/#{file_name}.wsdl"

  else
    redirect '/'
  end

  erb :post
end

get '/analyze' do
  analyzer = WsdlAnalyzer.new(session[:file])

  @operations = []
  analyzer.get_operations.each do |name, info|
    @operations << [name, info]
  end

  erb :analyze
end

get '/operation/:name' do
  analyzer = WsdlAnalyzer.new session[:file]

  @operation = analyzer.get_operation params[:name]

  @output = ""
  @operation[:output].each do |out|
    @output += html_output(out)
  end
  @output.gsub! /^\s+$/, ''

  @input = ""
  @operation[:input].each do |inp|
    @input += html_output(inp, 1)
  end
  @input.gsub! /^[\s\b]+$/m, ''
  @input.chomp!

  @name = params[:name]

  erb :operation
end

get '/raw' do
  if !session[:file]
    redirect '/' and return
  end

  response.header['Content-type'] = "text/plain"
  File.read(session[:file])
end

def html_output complex, depth=0
  output = ""
  indent = ""
  depth.times { indent += "  " }
  output += indent unless complex.is_a?(Array)

  if complex.is_a? Hash
    complex.each do |k,v|
      if v.is_a? String
        output += "#{k} => #{type_to_class v}\n"

      else
        if v.is_a?(Hash)
          ob = "{\n"
          cb = "}"
          next_depth = depth + 1
        else
          next_depth = depth
          ob = cb = " "
        end

        output += "#{k} => #{ob}#{html_output(v, next_depth)}\n"
        output += indent if cb != ""
        output += "#{cb}\n"
      end

      output += indent
    end

    output.sub!(/ +$/, "\n")

  elsif complex.is_a? Array
    complex.each do |item|
      output += "[\n#{html_output(item, depth + 1).chomp}\n"
      output += indent
      output += "]"
    end

  else
    output += complex + "\n"

  end

  return output.chomp
end

def type_to_class type
  case type
  when "string"; "String"
  when "int"; "Integer"
  when "double"; "Float"
  when "boolean"; "TrueClass"
  else
    type
  end
end