require 'fileutils'

INPUTDIR = "/home/bedlamp/marc"
BASETVDIR = "/home/bedlamp/series"

EXTENSIONS = ['avi', 'mkv']

$SHOWNAMESEPARATOR = "."
$FILENAMESEPARATOR = "."

$DELETENFO = true
$PRETEND = true

$EXTENSIONREGEX = "(#{EXTENSIONS.join("|")})"

def valid_file?(path)
  filename = File.basename(path)
  if filename.downcase =~ /^([\w\s\. ]+)(?:\.| )(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))(?:\.| )(.+)\.#{$EXTENSIONREGEX}$/
        
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
    other_stuff = other_stuff.join($FILENAMESEPARATOR)
    
    show = show.gsub(/\./, $SHOWNAMESEPARATOR).gsub(/ /, $SHOWNAMESEPARATOR)
    
    return [show, season.to_i, episode.to_i, other_stuff, extension]
  elsif filename =~ /.*\.#{$EXTENSIONREGEX}$/
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
      other_stuff = other_stuff.join($FILENAMESEPARATOR)
      
      show = show.gsub(/\./, $SHOWNAMESEPARATOR).gsub(/ /, $SHOWNAMESEPARATOR)
      
      return [show, season.to_i, episode.to_i, other_stuff, extension]
    else
      puts "Unidentified file of the correct type found: #{path}"
    end
  end
  
  return nil
end

def cleanup!(folder)
  other_files = Dir[File.join(folder, "*")]
  if $DELETENFO
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

def organise!
  Dir[File.join(File.expand_path(INPUTDIR),"**", "*")].each do |possible_file|
    if thing = valid_file?(possible_file)
      show = thing.first.gsub(/#{Regexp.escape($SHOWNAMESEPARATOR)}/, ".")
      season = thing[1].to_s.rjust(2,'0')
      episode = thing[2].to_s.rjust(2, '0')
      target_directory = File.join(File.expand_path(BASETVDIR), thing.first, season)
      target_file = File.join(target_directory, "#{show}.s#{season}e#{episode}.#{thing[3]}.#{thing[4]}")
      
      puts "Moving #{possible_file} to #{target_file}"
      FileUtils.mkdir_p(target_directory) unless $PRETEND
      FileUtils.mv(possible_file, target_file) unless $PRETEND
      
      cleanup!(File.dirname(possible_file)) unless $PRETEND
    end
  end
end

organise!
