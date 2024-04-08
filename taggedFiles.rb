#!/usr/bin/ruby

require "toml"
require "sqlite3"
require "cli/ui"

class Config
  def initialize()
    config = "/home/caspian/.config/tagf.toml"
    if !File.exists?(config)
      File.new(config, File::CREAT)
      File.write(config, "test")
    else
      contents = File.open(config).read()
      toml = TOML::Parser.new(contents).parsed()
    end

    # TODO actually read
    @directory = "/home/caspian/TaggedFiles/"
    
  end

  attr_accessor :directory
end

$config = Config.new


class Storage
  
  def initialize()
    @db = SQLite3::Database.new($config.directory + "taggedFiles.db")

    @db.execute <<-SQL
      create table if not exists tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    SQL
    @db.execute <<-SQL
      create table if not exists files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    SQL
    @db.execute <<-SQL
      create table if not exists connections (
        tagId Integer,
        fileId Integer
      )
    SQL
  end  
  
  # DATA METHODS -----
  def addFile(fileName)
    @db.execute("insert into files(name) values (?)", fileName)
  end
  
  def addTag(tagName)
    @db.execute("insert into tags(name) values (?)", tagName)
  end
  
  def getFileId(fileName)
    @db.execute("select id from files where name = ?", fileName)
  end
  
  def getTagId(tagName)
    @db.execute("select id from tags where name = ?", tagName)
  end
  
  def assignTag(fileName, tagName)
    # should probably make this a query with 2 sub queries instead of 3 queries
    tagId = getTagId(tagName)
    fileId = getFileId(fileName)
  
    if (tagId == [] || fileId == [])
      puts("tagId or fileId nil")
      return nil
    end
    
    @db.execute("insert into connections(tagId, fileId) values (?, ?)", tagId, fileId)
  end
  
  def getFilesByTag(tagName)
    tagId = getTagId(tagName)
    fileIds = @db.execute("select fileId from connections where tagId = ?", tagId)
    return @db.execute("select name from files where id in (?)", fileIds)  
  end
  
  def listFiles()
    @db.execute <<-SQL
      select f.name, group_concat(t.name)
      from files f
      left join connections c on
        f.id = c.fileId
      left join tags t on
        c.tagId = t.id
      group by f.name
    SQL
  end

end

$storage = Storage.new()


class Command
  def initialize(arguments)
    @command = arguments[0]
    @options = arguments[1..-1]
  end
  
  def resultSetToArray(set)
    result = []
    set.each do |item|
      result.push "#{item[0]}"
    end 
    return result
  end

  def addLink()

    begin
      File.symlink(File.absolute_path(@options[0]), $config.directory + File.basename(@options[0]))
    rescue
      puts("cant create symlink")
      return
    end
  
    begin
      $storage.addFile(File.basename(@options[0]));
    rescue
      puts("cant add to database")
      return
    end

    puts("added succesfully")
  end

  def assignTag()
    begin
      $storage.assignTag(@options[0], @options[1])
    rescue
      puts("cant assign tag")
      return
    end
    puts("assigned tag")
  end

  def changeDirectory()
    locations = resultSetToArray($storage.getFilesByTag(@options[0]))
    location = CLI::UI::Prompt.ask('which one?', options: locations)
    setCommand("cd #{$config.directory + location}")
  end

  def addTag()
    $storage.addTag(@options[0])
  end

  def list()
    list = $storage.listFiles()
    list.each do |file, tags|
      puts(file + " : (" + tags + ")")
    end
  end

  def openHelix()
    locations = resultSetToArray($storage.getFilesByTag(@options[0]))
    location = CLI::UI::Prompt.ask('which one?', options: locations)
    setCommand("hx #{$config.directory + location}")
  end

  def setCommand(command)
    File.new('./command', File::CREAT)
    File.write('./command', command)
  end

  def getCommand()
    if !File.exists?('./command')
      return
    end
    puts(File.read('./command'))
    File.delete('./command')
  end

  def help()
    puts(
      "taggedFiles <command> [options] \n"\
      "\n"\
      "commands: \n"\
      "al : add link \n"\
      "as : assign tag \n"\
      "ls : list files with their tags \n"\
      "cd : change directory to file \n"\
      "at : add tag \n"
    )
  end

  def run()

    case @command
    when "al"
      addLink()
    when "as"
      assignTag()
    when "ls"
      list()
    when "cd"
      changeDirectory()
    when "at"
      addTag()
    when "hx"
      openHelix()
    when "getCommand"
      getCommand()
    else
      help()
    end
        
  end
end

Command.new(ARGV).run()
