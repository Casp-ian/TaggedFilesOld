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

  def deleteFiles(name)
    fileId = getFileId(name);
    @db.execute("delete from connections where fileId = ?", fileId)
    @db.execute("delete from files where id = ?", fileId)
  end
  
  def deleteTags(name)
    tagId = getTagId(name);
    @db.execute("delete from connections where tagId = ?", tagId)
    @db.execute("delete from tags where id = ?", tagId)
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
  
  def nameAndPathByTags(tagNames)
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
  
  def addFiles(names)
    names.each do |name|
      begin
        $storage.addFile(File.absolute_path(name), File.basename(File.absolute_path(name)));
      rescue
        puts("cant add to database")
        return
      end
    end
    puts("added succesfully")
  end

  def removeFiles(names)
    names.each do |name|
      begin
        $storage.deleteFiles(name)
        puts("probably succeeded")
      rescue
        puts("cant delete file")
      end
    end
  end

  def removeTags(names)
    names.each do |name|
      begin
        $storage.deleteTags(name)
        puts("probably succeeded")
      rescue
        puts("cant delete tags")
      end
    end
  end

  def assignTag(file, tag)
    begin
      $storage.assignTag(file, tag)
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
      setCommand("#{command} #{location[1]} #{inBackground ? "&":""}")
    else
      CLI::UI::Prompt.ask('which one?') do |handler|
        locations.each do |location|
          handler.option(location[0]) {setCommand("#{command} #{location[1]} #{inBackground ? "&":""}")}
        end
      end
    end
  end

  def changeDirectory(tags)
    locations = $storage.nameAndPathByTags(tags)

    setCommandForFile('cd', locations, false)
  end

  def openHelix(tags)
    locations = $storage.nameAndPathByTags(tags)

    setCommandForFile('hx', locations, false)
  end

  def openFiles(tags)
    locations = $storage.nameAndPathByTags(tags)

    setCommandForFile('nautilus', locations, true)
  end

  def addTags(tags)
    tags.each do |tag|
      $storage.addTag(tag)
    end
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
      addFiles(@arguments[1..-1])
    when "--remove-file"
      removeFiles(@arguments[1..-1])
    when "--add-tag", "-t"
      addTags(@arguments[1..-1])
    when "--remove-tag"
      removeTags(@arguments[1..-1])
    when "--assign", "-a"
      assignTag(@arguments[1], @arguments[2])
    when "--list", "-l"
      list()
    when "--cd"
      changeDirectory(@arguments[1..-1])
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
