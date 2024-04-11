#!/usr/bin/ruby

require "sqlite3"
require "cli/ui"

$dbLocation = "/home/caspian/TaggedFiles/taggedFiles.db"

class Storage
  
  def initialize()
    @db = SQLite3::Database.new($dbLocation)

    @db.execute <<-SQL
      create table if not exists tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    SQL
    @db.execute <<-SQL
      create table if not exists files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT,
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
  def addFile(path, name)
    @db.execute("insert into files(path, name) values (?, ?)", path, name)
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
  
  def getFilesByTags(tagNames)
    placeholders = (['?'] * tagNames.length).join(',')
    @db.execute("
      select f.name as name, f.path as path from files f
      join connections c on f.id = c.fileId
      join tags t on c.tagId = t.id
      where t.name in (#{placeholders})
      group by f.id, f.name
      having count(*) = (select count(*) from tags where name in (#{placeholders}))
    ", tagNames + tagNames)
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
    @arguments = arguments
  end
  
  def addFile()

    begin
      $storage.addFile(File.absolute_path(@options[0]), File.basename(File.absolute_path(@options[0])));
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

  def setCommandForFile(command, locations, inBackground)
    if locations.length == 0
      puts("no files match tags")
      return
    elsif locations.length == 1
      location = locations[0]
      puts("going to #{location[0]}")
    else
      CLI::UI::Prompt.ask('which one?') do |handler|
        locations.each do |location|
          handler.option(location[0]) {setCommand("#{command} #{location[1]} #{inBackground ? "&":""}")}
        end
      end
    end
  end

  def changeDirectory(tags)
    locations = $storage.getFilesByTags(tags)

    setCommandForFile('cd', locations, false)
  end

  def openHelix(tags)
    locations = $storage.getFilesByTags(tags)

    setCommandForFile('hx', locations, false)
  end

  def openFiles(tags)
    locations = $storage.getFilesByTags(tags)

    setCommandForFile('nautilus', locations, true)
  end

  def addTag()
    $storage.addTag(@options[0])
  end

  def list()
    list = $storage.listFiles()
    list.each do |file, tags|
      puts("#{file} : (#{tags})")
    end
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
      "af : add file \n"\
      "as : assign tag \n"\
      "ls : list files with their tags \n"\
      "cd : change directory to file \n"\
      "at : add tag \n"
    )
  end

  def version()
    puts("0.0.1")
  end

  def run()
    case @arguments[0]
    when "--add-file", "-f"
      addFile(@arguments[1..-1])
    when "--assign", "-a"
      assignTag(@arguments[1], @arguments[2])
    when "--list", "-l"
      list()
    when "--cd"
      changeDirectory(@arguments[1..-1])
    when "--add-tag", "-t"
      addTag(@arguments[1..-1])
    when "--hx"
      openHelix(@arguments[1..-1])
    when "--nautilus"
      openFiles(@arguments[1..-1])
    when "--getCommand"
      getCommand()
    when "--help", "-h"
      help()
    when "--version", "-v"
      version()
    else
      changeDirectory(@arguments[0..-1])
    end
  end
end

Command.new(ARGV).run()
