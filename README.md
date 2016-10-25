# Automatic Directory Cleaning on macOS

This is a relatively simple `bash` script that helps automate the cleaning of
directories on macOS (or OS X).


## Why?

Is your `~/Downloads` directory overflowing with outdated and useless crap?
Are you lazy?  Wow, I just got goosebumps just thinking about how alike we are!


## Usage

Download [dirclean.sh](dirclean.sh?raw=true) and put it somewhere (e.g.
`~/bin/dirclean.sh`).  Then make it executable with:

```sh
$ chmod +x ~/bin/dirclean.sh
```

If you want files in `~/Downloads` to be moved to Trash after 5 days of
neglect:

```sh
$ ~/bin/dirclean.sh 5 ~/Downloads
```

The file `~/.config/dirclean.conf` will be created with the following entry:

```
432000;/Users/you/Downloads
```

Now, any time you run `~/bin/dirclean.sh --clean`, the top level directories
and files inside of `~/Downloads` will be checked to see if anything is at
least 5 days old and move them to Trash if they are.

To have this run automatically on a schedule, run `crontab -e` and add a line
such as:

```crontab
*/15 * * * * ~/bin/dirclean.sh --clean
```

Now, `~/bin/dirclean.sh --clean` will run every 15 minutes.


### "You wrote a cron script to delete old files.  This sounds stupid."

Glad you asked!  It works by scanning the configured directories for files and
using `mdls` to get the following dates from the file's metadata:

- `kMDItemFSContentChangeDate`: Date the file content was last changed
- `kMDItemFSCreationDate`: Date the file was created
- `kMDItemLastUsedDate`: Date when this item was last used
- `kMDItemDateAdded`: Date when this item was last moved

The most recent date is used to determine how old the file is.  This is
different from using `stat` which isn't reliable since the file's date could've
been set to some time in the past.  This usually happens from extracting files
from archives.

Additionally, files within subdirectories are not checked recursively and moved
to Trash individually.  Only the top level is evaluated.  When evaluating
directories, only the newest file within them is evaluated.  For example:

```
~/Downloads
├── file1.txt
├── file2.txt
└── more_files
    ├── file3.txt
    └── file4.txt
```

It's assumed that the files within `more_files` belong together.  This means if
any file within it has been recently added/changed/used, `more_files` and
anything under it shouldn't be moved to Trash.  The exception to this are
Applications and Bundles.  While they are technically directories, they are
treated as a single file by you and OS X, so only the directory itself is
checked.

You may have also noticed that **"moved to Trash"** is mentioned a lot.  The
files aren't *deleted*.  You are responsible for the ultimate destruction of
your files.


## Tips

### Cron schedule

- `crontab` is only used to run `~/bin/dirclean.sh --clean` so you don't have
  to.  It's not a requirement.
- Scheduling it to times when you will be using the computer will guarnatee
  that it runs.
  - It's otherwise flawed: [Effects of Sleeping and Powering Off][1]
- A short interval doesn't mean files will be deleted on every run, but you
  should keep it reasonable (especially if the scan directories have **a lot**
  of files).

### Get rid of your screenshots

`~/Desktop` is a dumb place for screenshots.  Change the screenshot location
where only the screenshots will exist, then schedule it for cleanup:

```sh
$ defaults write com.apple.screencapture location ~/Pictures/Screenshots
$ killall SystemUIServer
$ ~/bin/dirclean.sh 5 ~/Pictures/Screenshots
```

## License

[MIT](LICENSE)

[1]: https://developer.apple.com/library/content/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html#//apple_ref/doc/uid/10000172i-CH1-SW3
