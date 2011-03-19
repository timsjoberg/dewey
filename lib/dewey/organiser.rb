require 'fileutils'

module Dewey
  class Organiser
    
    attr_accessor :pretend, :delete_nfo, :show_name_separator, :file_name_separator
    attr_reader = :extensions
    
    def initialize(input_dir, base_tv_dir)
      @input_dir = input_dir || "/tmp/input"
      @base_tv_dir = base_tv_dir || "tmp/output"
      
      @pretend = pretend || false
      @delete_nfo = delete_nfo || true
      @extensions = extensions || ['avi', 'mkv']
      @show_name_separator = show_name_separator || "."
      @file_name_spearator = file_name_separator || "."
      
      update_extension_regex
    end
    
    def extensions=(array)
      @extensions = array
      update_extension_regex
    end
  
    def organise!
      Dir[File.join(File.expand_path(@input_dir),"**", "*")].each do |possible_file|
        if thing = valid_file?(possible_file)
          show = thing.first.gsub(/#{Regexp.escape(@show_name_separator)}/, ".")
          season = thing[1].to_s.rjust(2,'0')
          episode = thing[2].to_s.rjust(2, '0')
          target_directory = File.join(File.expand_path(@base_tv_dir), thing.first, season)
          target_file = File.join(target_directory, "#{show}.s#{season}e#{episode}.#{thing[3]}.#{thing[4]}")
          
          puts "Moving #{possible_file} to #{target_file}"
          FileUtils.mkdir_p(target_directory) unless @pretend
          FileUtils.mv(possible_file, target_file) unless @pretend
          
          cleanup!(File.dirname(possible_file)) unless @pretend
        end
      end
    end
    
    protected
    
    def update_extension_regex
      @extension_regex = "(#{@extensions.join("|")})"
    end
    
    def valid_file?(path)
      filename = File.basename(path)
      if filename.downcase =~ /^([\w\s\. ]+)(?:\.| )(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))(?:\.| )(.+)\.#{@extension_regex}$/
            
        show = $1
        season = $2
        episode = $3
        season ||= $4
        episode ||= $5
        other_stuff = $6
        extension = $7
        
        other_stuff = other_stuff.gsub(/\./, " ").gsub(/\-/, " ").split(" ")
        temp = other_stuff.pop
        temp = "#{other_stuff.pop}-#{temp}"
        other_stuff.push temp
        other_stuff = other_stuff.join(@file_name_separator)
        
        show = show.gsub(/\./, @show_name_separator).gsub(/ /, @show_name_separator)
        
        return [show, season.to_i, episode.to_i, other_stuff, extension]
      elsif filename =~ /.*\.#{@extension_regex}$/
        extension = $1
        dirname = File.basename(File.dirname(path)).downcase
        if dirname =~ /^([\w\s\. ]+)(?:\.| )(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))(?:\.| )(.+)$/
          show = $1
          season = $2
          episode = $3
          season ||= $4
          episode ||= $5
          other_stuff = $6
          
          other_stuff = other_stuff.gsub(/\./, " ").gsub(/\-/, " ").split(" ")
          temp = other_stuff.pop
          temp = "#{other_stuff.pop}-#{temp}"
          other_stuff.push temp
          other_stuff = other_stuff.join(@file_name_separator)
          
          show = show.gsub(/\./, @show_name_separator).gsub(/ /, @show_name_separator)
          
          return [show, season.to_i, episode.to_i, other_stuff, extension]
        else
          puts "Unidentified file of the correct type found: #{path}"
        end
      end
      
      return nil
    end

    def cleanup!(folder)
      other_files = Dir[File.join(folder, "*")]
      if @delete_nfo
        if other_files.size == 1
          file = other_files.first
          if file =~ /.*\.nfo$/i
            puts "Deleting nfo: #{file}"
            FileUtils.rm(file)
            other_files.clear
          end
        end
      end
      if other_files.empty?
        puts "Deleting empty folder: #{folder}"
        FileUtils.rmdir(folder)
      end
    end
    
  end
end