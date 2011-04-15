require 'fileutils'
require 'tvdb'

module Dewey
  class Organiser
    
    attr_accessor :pretend, :delete_nfo, :show_name_separator, :file_name_separator
    attr_reader = :extensions
    
    def initialize(input_dir, base_tv_dir)
      @input_dir = input_dir || "/tmp/input"
      @base_tv_dir = base_tv_dir || "tmp/output"
      
      @pretend = false
      @delete_nfo = true
      @extensions = ['avi', 'mkv']
      @show_name_separator = "."
      @file_name_separator = "."
      
      @client = TVdb::Client.new('2453AFC9C8A5C8C3')
      @tvdb_hash = {}
      @cached_searches = {}
      
      yield(self) if block_given?
      
      update_extension_regex
    end
    
    def extensions=(array)
      @extensions = array
      update_extension_regex
    end
  
    def organise!
      Dir[File.join(File.expand_path(@input_dir),"**", "*")].each do |possible_file|
        if thing = valid_file?(possible_file)
          show = thing.first.gsub(/#{Regexp.escape(@show_name_separator)}/, @file_name_separator)
          season = thing[1].to_s.rjust(2,'0')
          episode = thing[2].to_s.rjust(2, '0')
          target_directory = File.join(File.expand_path(@base_tv_dir), thing.first, season)
          target_file = File.join(target_directory, "#{show}.s#{season}e#{episode}")
          target_file << ".#{thing[3]}" unless thing[3].nil? || thing[3].empty?
          target_file << ".#{thing[4]}"
          
          if File.file?(target_file)
            puts "ERROR: NOT moving #{possible_file} to #{target_file} because target already exists"
          else
            puts "Moving #{possible_file} to #{target_file}"
            FileUtils.mkdir_p(target_directory) unless @pretend
            FileUtils.mv(possible_file, target_file) unless @pretend
            
            cleanup!(File.dirname(possible_file)) unless @pretend
          end
        end
      end
    end
    
    protected
    
    def update_extension_regex
      @extension_regex = "(#{@extensions.join("|")})"
    end
    
    def valid_file?(path)
      filename = File.basename(path)
      dirname = File.basename(File.dirname(path))
      possible_files_in_folder = []
      @extensions.each do |extension|
        possible_files_in_folder.concat Dir[File.join(File.dirname(path), "*.#{extension}")]
      end
      
      if filename =~ /.*\.#{@extension_regex}$/
        extension = $1
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
          other_stuff = other_stuff.join(@file_name_separator)
          other_stuff << "-#{temp}" unless temp.nil? || temp.empty?
          
          show = show.gsub(/\./, @show_name_separator).gsub(/ /, @show_name_separator)
          
          return [show, season.to_i, episode.to_i, other_stuff, extension]
        elsif possible_files_in_folder.size == 1 && (filename =~ /sample/).nil? && dirname.downcase =~ /^([\w\s\. ]+)(?:\.| )(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))(?:\.| )(.+)$/
          show = $1
          season = $2
          episode = $3
          season ||= $4
          episode ||= $5
          other_stuff = $6
          
          other_stuff = other_stuff.gsub(/\./, " ").gsub(/\-/, " ").split(" ")
          temp = other_stuff.pop
          other_stuff = other_stuff.join(@file_name_separator)
          other_stuff << "-#{temp}" unless temp.nil? || temp.empty?
          
          show = show.gsub(/\./, @show_name_separator).gsub(/ /, @show_name_separator)
          
          return [show, season.to_i, episode.to_i, other_stuff, extension]
        else
          working = filename.downcase.gsub(/\-/, " ").gsub(/\./, " ").gsub(/ +/, " ").strip.split(/ /)
          
          found = false
          position = -1
          season = nil
          episode = nil
          
          working.each_with_index do |term, i|
            if term =~ /^(\d{1,2})(\d{2})$/
              found = true
              position = i
              season = $1
              episode = $2
            else
              break if found == true
            end
          end
          
          unless found
            working.each_with_index do |term, i|
              if term =~ /^(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))$/
                found = true
                position = i
                season = $1
                episode = $2
                season ||= $3
                episode ||= $4
                break
              end
            end
          end
          
          series_name = working.slice(0, position).join(" ") if found
          
          if found && !series_name.nil? && !series_name.empty?
            tvdb_series = find_tvdb_result_for_series_name(series_name)
            
            unless tvdb_series.nil?
              (position + 1).times { working.shift }
              extension = working.pop
              temp = working.pop
              other_stuff = working.join(@file_name_separator) 
              other_stuff << "-#{temp}" unless temp.nil? || temp.empty?
              
              show = normalize_series_name(tvdb_series.seriesname).gsub(/ /, @show_name_separator)
              
              return [show, season.to_i, episode.to_i, other_stuff, extension]
            end
          end
          
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
        begin
          FileUtils.rmdir(folder)
        rescue Errno::ENOTEMPTY
          puts "ERROR deleting folder #{folder} It is not empty. Most likely it has hidden files or folders in it"
        end
      end
    end
    
    def find_tvdb_result_for_series_name(series_name)
      normalized_series_name = normalize_series_name(series_name)
      
      return @tvdb_hash[normalized_series_name] unless @tvdb_hash[normalized_series_name].nil?
      
      tvdb_search(normalized_series_name).each do |result|
        if normalized_series_name == normalize_series_name(result.seriesname)
          @tvdb_hash[normalized_series_name] = result
          return result
        end
      end
      
      return nil
    end
    
    def normalize_series_name(series_name)
      series_name.gsub(/\$\#\*\!/, "shit").gsub(/[\(\)\:\!\']/, "").gsub(/\-/, " ").gsub(/\&/, "and").gsub(/ +/, " ").strip.downcase
    end
    
    def tvdb_search(series_name)
      better_search = series_name.gsub(/ and /, " ").gsub(/^the /, "").gsub(/^shit /, "").gsub(/ \& /, " ")
      
      if @cached_searches[better_search].nil?
        @cached_searches[better_search] = @client.search(better_search)
      end
      
      @cached_searches[better_search] 
    end
    
  end
end
