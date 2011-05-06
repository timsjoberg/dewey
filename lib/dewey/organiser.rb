require 'fileutils'
require 'tvdb_party'

module Dewey
  class Organiser
    
    attr_accessor :pretend, :delete_nfo, :show_name_separator, :file_name_separator, :http_post_url
    attr_reader = :extensions
    
    def initialize(input_dir, base_tv_dir)
      @input_dir = input_dir || "/tmp/input"
      @base_tv_dir = base_tv_dir || "tmp/output"
      
      @pretend = false
      @delete_nfo = true
      @extensions = ['avi', 'mkv']
      @show_name_separator = "."
      @file_name_separator = "."
      @http_post_url = nil
      
      @client = TvdbParty::Search.new('2453AFC9C8A5C8C3')
      @tvdb_hash = {}
      
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
            unless @pretend
              puts "ERROR: NOT moving #{possible_file} to #{target_file} because target already exists"
            else
              puts "ERROR: Would NOT move #{possible_file} to #{target_file} because target already exists"
            end
          else
            unless @pretend
              puts "Moving #{possible_file} to #{target_file}"
              FileUtils.mkdir_p(target_directory) 
              FileUtils.mv(possible_file, target_file)
              
              if @http_post_url
                begin
                  HTTParty.post(@http_post_url, :body => { :episode => { :series_id => thing[5], :season => season.to_i, :episode => episode.to_i, :location => target_file } })
                rescue Exception => e
                  puts "ERROR: Failed to post to #{@http_post_url} #{e.message}"
                end
              end
              
              cleanup!(File.dirname(possible_file))
            else
              puts "Would move #{possible_file} to #{target_file}"
            end
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
      
      if filename =~ /.*\.#{@extension_regex}$/i
        extension = $1.downcase
        
        working = filename.downcase.gsub(/\-/, " ").gsub(/\./, " ").gsub(/ +/, " ").strip.split(/ /)
        
        found = false
        position = -1
        season = nil
        episode = nil
        
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
        
        unless found
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
            
            show = normalize_series_name(tvdb_series["SeriesName"]).gsub(/ /, @show_name_separator)
            
            unless @client.get_series_by_id(tvdb_series["seriesid"]).get_episode(season.to_i, episode.to_i).nil?
              return [show, season.to_i, episode.to_i, other_stuff, extension, tvdb_series["seriesid"]]
            end
          end
        end
        
        if possible_files_in_folder.size == 1 && (filename =~ /sample/i).nil? && dirname.downcase =~ /^(.+)(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))(?:\.| )(.+)$/
          show = $1
          season = $2
          episode = $3
          season ||= $4
          episode ||= $5
          other_stuff = $6
          
          show = normalize_series_name(show)
          
          tvdb_series = find_tvdb_result_for_series_name(show)
          
          unless tvdb_series.nil?
            other_stuff = other_stuff.gsub(/\./, " ").gsub(/\-/, " ").split(" ")
            temp = other_stuff.pop
            other_stuff = other_stuff.join(@file_name_separator)
            other_stuff << "-#{temp}" unless temp.nil? || temp.empty?
            
            show = show.gsub(/\./, @show_name_separator).gsub(/ /, @show_name_separator)
            
            unless @client.get_series_by_id(tvdb_series["seriesid"]).get_episode(season.to_i, episode.to_i).nil?
              return [show, season.to_i, episode.to_i, other_stuff, extension, tvdb_series["seriesid"]]
            end
          end
        end
        
        puts "Unidentified file of the correct type found: #{path}"
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
        if normalized_series_name == normalize_series_name(result["SeriesName"])
          @tvdb_hash[normalized_series_name] = result
          return result
        end
      end
      
      if normalized_series_name.split(/ /).size > 1
        asdasd = normalized_series_name.sub(/ \w+$/, "")
        
        if asdasd.length > 4
          tvdb_search(asdasd).each do |result|
            normalized_result_name = normalize_series_name(result["SeriesName"])
            
            if normalized_series_name == normalized_result_name
              @tvdb_hash[normalized_series_name] = result
              return result
            end
            
            if asdasd == normalized_result_name
              @tvdb_hash[normalized_series_name] = result
              return result
            end
            
            if normalized_result_name.split(/ /).size > 1
              if normalized_series_name == normalized_result_name.sub(/ \w+$/, "")
                @tvdb_hash[normalized_series_name] = result
                return result
              end
            end
          end
        end
        
        #last ditch effort. we search using the longest word in the title.
        #we are still quite strict with matches
        if normalized_series_name =~ /(\w+)/
          longest_word = $1
          
          if longest_word.length > 4
            tvdb_search(longest_word).each do |result|
              normalized_result_name = normalize_series_name(result["SeriesName"])
              
              if normalized_series_name == normalized_result_name
                @tvdb_hash[normalized_series_name] = result
                return result
              end
              
              if normalized_result_name.split(/ /).size > 1
                if normalized_series_name == normalized_result_name.sub(/ \w+$/, "")
                  @tvdb_hash[normalized_series_name] = result
                  return result
                end
              end
            end
          end
        end
      end
      
      return nil
    end
    
    def normalize_series_name(series_name)
      series_name.gsub(/\$\#\*\!/, "shit").gsub(/[\(\)\:\!\']/, "").gsub(/\-/, " ").gsub(/\&/, "and").gsub(/ +/, " ").strip.downcase
    end
    
    def tvdb_search(series_name)
      better_search = series_name.gsub(/ and /, " ").gsub(/^the /, "").gsub(/^shit /, "").gsub(/ \& /, " ")
      
      retries = 0
      begin
        @client.search(better_search)
      rescue Timeout::Error, Errno::ETIMEDOUT => e
        if retries >= 3
          raise e
        else
          retries += 1
          retry
        end
      end
    end
    
  end
end
