require 'fileutils'

INPUTDIR = "/home/bedlamp/marc"
BASETVDIR = "/home/bedlamp/series"

EXTENSIONS = ['avi', 'mkv']

$SHOWNAMESEPARATOR = "."
$FILENAMESEPARATOR = "."

$PRETEND = true

$EXTENSIONREGEX = "(#{EXTENSIONS.join("|")})"

def valid_file?(path)
  filename = File.basename(path).downcase
  if filename =~ /^([\w\s\. ]+)(?:\.| )(?:s([0-9]{2,})e([0-9]{2,})|([0-9]{1,})x([0-9]{2,}))(?:\.| )(.+)\.#{$EXTENSIONREGEX}$/
    puts File.basename(File.dirname(path))
    
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
    return nil 
  else
    return nil
  end
end

def organise!
  Dir[File.join(File.expand_path(INPUTDIR),"**", "*")].each do |possible_file|
    if thing = valid_file?(possible_file)
      puts thing.join " | "
      show = thing.first.gsub(/#{Regexp.escape($SHOWNAMESEPARATOR)}/, ".")
      season = thing[1].to_s.rjust(2,'0')
      episode = thing[2].to_s.rjust(2, '0')
      target_directory = File.join(File.expand_path(BASETVDIR), thing.first, season)
      target_file = File.join(target_directory, "#{show}.s#{season}e#{episode}.#{thing[3]}.#{thing[4]}")
      puts "Moving #{possible_file} to #{target_file}"
      puts show
      puts season
      puts episode
      puts target_directory
      puts target_file
      FileUtils.mkdir_p(target_directory) unless $PRETEND
      FileUtils.mv(possible_file, target_file) unless $PRETEND
    end
  end
end

organise!
