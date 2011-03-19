#!/usr/bin/env ruby

module Dewey
  class Cli

    require "optparse"
    require "fileutils"
    require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'dewey', 'organiser'))
    
    RC_OK = 0
    RC_USAGE = 1
    
    DEFAULT_EXTS = %w(avi mkv)
    
    def initialize()
      @input_dir = "."
      @tv_dir = "dewey/tv.series"
      @tv_extensions = DEFAULT_EXTS
      @archive = true
      @verbose = 0
    end


    def parse_opts(argv)
      optparser = OptionParser.new() do |o|
        o.banner = "dewey [options] [directory]"

        o.separator("")
        o.separator("options")

        o.on("--tv-dir=DIRECTORY",
             "Place to store archived tv series",
             "Default: " + @tv_dir.inspect()) do |v|
          @tv_dir = v
        end

        o.on("--tv-extensions=ARRAY",
             "Comma-seperated list of extensions that should be considered tv series",
             "Default: " + @tv_extensions.inspect()) do |v|
          @tv_extensions = v.split(",")
        end

        o.on("--[no]-archive",
             "Disable this if you want a pretend run",
             "Default: #{@archive}") do |v|
          @archive = v
        end

        o.on("--verbose",
             "How noisy do you want us to be? Call multiple times",
             "Default: " + @verbose.inspect()) do |v|
          @verbose += 1
        end

        o.separator("")
        o.on_tail("-h", "--help", "You're reading it :-)") do
          puts(o)
          Kernel.exit(RC_USAGE)
        end
      end

      rest = optparser.parse(argv)
      case rest.size
      when 0; # Nothing, use default +@input_dir+
      when 1
        @input_dir = rest.first
      else
        STDERR.puts("Unknown argument(s) " + rest.inspect())
        Kernel.exit(RC_USAGE)
      end

      self
    end

    def run()
      @input_dir = File.expand_path(@input_dir) rescue nil
      FileUtils.mkdir_p(@tv_dir) rescue nil
      validate_opts!
      
      organiser = Organiser.new(@input_dir, @tv_dir)
      
      organiser.organise!
    end

    def validate_opts!
      valid_directory_proc = proc { |d| d and File.directory? d }
      valid_extensions_proc = proc { |a| Array === a and not a.empty? }
      
      [
       ["input-directory", @input_dir, valid_directory_proc, "%s is not a directory"],
       ["--tv-dir", @tv_dir, valid_directory_proc, "%s is not a directory"],
       ["--tv-extensions", @tv_extensions, valid_extensions_proc, "%s is not a valid list of extensions"],
      ].each do |arg, v, proc, error|
        unless proc.call(v)
          STDERR.puts(arg + " is not correctly set: " + error % v.inspect())
          Kernel.exit(RC_USAGE)
        end
      end
    end
    
  end
end

if __FILE__ == $0
  Dewey::Cli.new().parse_opts(ARGV).run()
end
