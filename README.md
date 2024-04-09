# TaggedFiles

## idea & inspiration
Original inspiration for this project was a post about [tag based file systems](https://garrit.xyz/posts/2024-04-02-fuck-trees-use-tags).
I wanted to make a way to access my files based on tags, but building an entire file system is out of my grasp for now, and i would also like some of my files to still be accesible from my normal file tree.

The current idea is to have everything i want to access via tags in a single directory (could be as a symlink to the the actual location), and access those files by tags using a script i will build.

The result will be quite similar to something like [zoxide](https://github.com/ajeetdsouza/zoxide).

## working

### the script itself
writen in ruby
TODO

### the extra part
Because we cant change the current shells directory from the script we need to be a little creative.
The script stores the command that should be run and returns it when called with the option 'getCommand'.
However this is kind of scary, if somehow my script returns `rm -rf ~` we are fucked so if possible i would like to find another solution.

This is the function i added to my fishrc.
```
  function tf
    /home/caspian/Projects/cli/TaggedFiles/taggedFiles.rb $argv
    eval (/home/caspian/Projects/cli/TaggedFiles/taggedFiles.rb getCommand)
    # eval (cd ~)
  end
```
