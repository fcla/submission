#!/usr/bin/env ruby

require 'optparse'
require 'uri'
require 'ostruct'
require 'digest/md5'
require 'fileutils'
require 'pp'

# option parsing

def get_options(args)
  config = OpenStruct.new("url" => nil, "package" => nil, "package_name" => nil)  

  begin
    opts = OptionParser.new do |opt|

      opt.banner << "\nSubmits a SIP to the DAITSS Submission Service"
      opt.on_tail("--help", "Show this message")  { puts opts; exit }

      opt.on("--url URL", String, "URL of service to submit package to, required") { |key|   config.url = key }      
      opt.on("--package PATH", String, "Path to SIP to submit, required") { |path|  config.package = path }
      opt.on("--name PACKAGE_NAME", String, "Package name of package being submitted, required") { |name|  config.package_name = name }
    end

    opts.parse!(args)

    raise StandardError, "URL not specified" unless config.url
    raise StandardError, "Package not specified" unless config.package
    raise StandardError, "Package name not specified" unless config.package_name

    url_obj = URI.parse(config.url)

    raise StandardError, "Specified URL #{config.url} does not look like an HTTP URL" unless url_obj.scheme == "http"
    raise StandardError, "Specified package path is not a directory" unless File.directory? config.package

  rescue => e         # catch the error from opts.parse! and display
    STDERR.puts "Error parsing command line options:\n#{e.message}\n#{opts}"
    return nil
  end

  return config
end

# zips directory at path_to_package. Returns string with path to zip file

def zip_package path_to_package
  dest_dir = File.join(File.dirname(__FILE__), "tempsubmit.zip")

  output = `zip -r #{dest_dir} #{path_to_package}` 

  raise "zip returned non-zero exit status: #{output}" if $?.exitstatus != 0

  return dest_dir
end

# returns md5 checksum sum of file at path_to_zip

def md5 path_to_zip
  md5 = Digest::MD5.new
  
  File.open(path_to_zip) do |file|
    md5 << file.read
  end

  return md5.hexdigest
end

# calls curl to submit package to service

def submit_to_svc url, path_to_zip, package_name, md5
  output = `curl -X POST -H "CONTENT_MD5:#{md5}" -H "X_PACKAGE_NAME:#{package_name}" -H "X_ARCHIVE_TYPE:zip" -T "#{path_to_zip}" -v #{url} 2>&1`

  return output
end



config = get_options(ARGV) or exit
zipfile = zip_package config.package
md5_of_zipfile = md5 zipfile
curl_output = submit_to_svc config.url, zipfile, config.package_name, md5_of_zipfile
FileUtils.rm_rf zipfile

puts curl_output 