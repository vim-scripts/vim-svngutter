## Vim Svn Gutter

A Vim plugin which shows a svn diff in the 'gutter' (sign column).  It shows whether each line has been added, modified, and where lines have been removed.

This is a port of the https://github.com/airblade/vim-gitgutter gitgutter plugin by AirBlade
All help text and documentation has been copied verbatim (except for swapping Git|git for Svn|svn).

### Installation

Before installation, please check your Vim supports signs by running `:echo has('signs')`.  `1` means you're all set; `0` means you need to install a Vim with signs support.  If you're compiling Vim yourself you need the 'big' or 'huge' feature set.  [MacVim][] supports signs.

If you don't have a preferred installation method, I recommend installing [pathogen.vim][pathogen], and then simply copy and paste:

```
cd ~/.vim/bundle
svn clone svn://github.com/airblade/vim-svngutter.svn
```

Or for [Vundle](https://github.com/gmarik/vundle) users:

Add `Bundle 'airblade/vim-svngutter'` to your `~/.vimrc` and then:

* either within Vim: `:BundleInstall`
* or in your shell: `vim +BundleInstall +qall`


### Usage

You don't have to do anything: it just works.

With one exception the plugin diffs your saved buffers, i.e. the files on disk.  It produces the same result as running `svn diff` on the command line.  The exception is realtime updating: in this case the plugin diffs the (unsaved) buffer contents against the version in svn.

You can explicitly turn vim-svngutter off and on (defaults to on):

* turn off with `:SvnGutterDisable`
* turn on with `:SvnGutterEnable`
* toggle with `:SvnGutterToggle`.

And you can turn line highlighting on and off (defaults to off):

* turn on with `:SvnGutterLineHighlightsEnable`
* turn off with `:SvnGutterLineHighlightsDisable`
* toggle with `:SvnGutterLineHighlightsToggle`.

Furthermore you can jump between hunks:

* jump to next hunk: `]h`
* jump to previous hunk: `[h`.

Both of those take a preceding count.

To set your own mappings for these, for example `gh` and `gH`:

```viml
nmap gh <Plug>SvnGutterNextHunk
nmap gH <Plug>SvnGutterPrevHunk
```

Finally, you can force vim-svngutter to update its signs across all visible buffers with `:SvnGutterAll`.

See the customisation section below for how to change the defaults.


### When are the signs updated?

By default the signs are updated when you:

* Stop typing
* Change buffer
* Change tab
* Save a buffer
* Change a file outside Vim
* Focus the GUI.

This can cause a noticeable lag on some systems so you can configure the plugin to update less often.  See the customisation section below.


### Customisation

You can customise:

* The sign column's colours
* Whether or not the sign column is shown when there aren't any signs (defaults to no)
* The signs' colours and symbols
* Line highlights
* Extra arguments for `svn diff`
* Whether or not to escape `grep` (default to no)
* Whether or not vim-svngutter is on initially (defaults to on)
* Whether or not signs are shown (defaults to yes)
* Whether or not line highlighting is on initially (defaults to off)
* Whether or not vim-svngutter runs in "realtime" (defaults to yes)
* Whether or not vim-svngutter runs eagerly (defaults to yes)

Please note that vim-svngutter won't override any colours or highlights you've set in your colorscheme.


#### Sign column

The background colour of the sign column is controlled by the `SignColumn` highlight group.  This will be either set in your colorscheme or Vim's default.

To find out where it's set, and to what it's set, use `:verbose highlight SignColumn`.

If your `SignColumn` is not set (`:highlight SignColumn` gives you `SignColumn xxx cleared`), vim-svngutter will set it to the same as your line number column (i.e. the `LineNr` highlight group).

To change your sign column's appearance, update your colorscheme or `~/.vimrc` like this:

* For the same appearance as your line number column: `highlight clear SignColumn`
* For a specific appearance on terminal Vim: `highlight SignColumn ctermbg=whatever`
* For a specific appearance on gVim/MacVim: `highlight SignColumn guibg=whatever`

By default the sign column will appear when there are signs to show and disappear when there aren't.  If you would always like the sign column to be there, add `let g:svngutter_sign_column_always = 1` to your `~/.vimrc`.


#### Signs' colours and symbols

To customise the colours, set up the following highlight groups in your colorscheme or `~/.vimrc`:

```viml
SvnGutterAdd          " an added line
SvnGutterChange       " a changed line
SvnGutterDelete       " at least one removed line
SvnGutterChangeDelete " a changed line followed by at least one removed line
```

You can either set these with `highlight SvnGutterAdd {key}={arg}...` or link them to existing highlight groups with, say, `highlight link SvnGutterAdd DiffAdd`.

To customise the symbols, add the following to your `~/.vimrc`:

```viml
let g:svngutter_sign_added = 'xx'
let g:svngutter_sign_modified = 'yy'
let g:svngutter_sign_removed = 'zz'
let g:svngutter_sign_modified_removed = 'ww'
```

#### Whether or not signs are shown

If you never want signs to be shown (presumably you only want the line highlights), add this to your `~/.vimrc`:

```viml
let g:svngutter_signs = 0
```

#### Line highlights

Similarly to the signs' colours, set up the following highlight groups in your colorscheme or `~/.vimrc`:

```viml
SvnGutterAddLine          " default: links to DiffAdd
SvnGutterChangeLine       " default: links to DiffChange
SvnGutterDeleteLine       " default: links to DiffDelete
SvnGutterChangeDeleteLine " default: links to SvnGutterChangeLineDefault, i.e. DiffChange
```

#### Extra arguments for `svn diff`

If you want to pass extra arguments to `svn diff`, for example to ignore whitespace, do so like this:

```viml
let g:svngutter_diff_args = '-w'
```

#### Whether or not to escape `grep`

If you have `grep` aliased to something which changes its output, for example `grep --color=auto -H`, you will need to tell vim-svngutter to use raw grep:

```viml
let g:svngutter_escape_grep = 1
```

#### To turn off vim-svngutter by default

Add `let g:svngutter_enabled = 0` to your `~/.vimrc`.


#### To turn on line highlighting by default

Add `let g:svngutter_highlight_lines = 1` to your `~/.vimrc`.


#### To stop vim-svngutter running in realtime

By default the plugin runs when you stop typing.  The delay is governed by `updatetime` (Vim's default is `4000`ms, i.e. 4 seconds; I prefer `750`.)

To turn this off, add the following to your `~/.vimrc`:

```viml
let g:svngutter_realtime = 0
```


#### To stop vim-svngutter running eagerly

By default the plugin also runs every time you read a file, on `BufEnter`, `TabEnter` and `FocusGained`.

This can cause a noticeable lag for some people so you can set the plugin to run instead only when you read or write a file.

To turn off eager execution, add this to your `~/.vimrc`:

```viml
let g:svngutter_eager = 0
```

Note that `FocusGained` cannot be used with gVim on Windows due to a Vim/shell bug causing an infinite loop.


### FAQ

> Why are the colours in the sign column weird?

Your colorscheme is configuring the `SignColumn` highlight group weirdly.  Please see the section above on customising the sign column.

> There's a noticeable lag when vim-svnter runs; how can I avoid it?

By default vim-svngutter runs often so the signs are as accurate as possible.  However on some systems this causes a noticeable lag.  If you would like to trade a little accuracy for speed, add this to your `~/.vimrc`:

```viml
let g:svngutter_realtime = 0
let g:svngutter_eager = 0
```

> Why is no sign shown if I delete the first line(s) in a file?

vim-svngutter shows removed lines with a sign on the line above.  In this case there isn't a line above so vim-svngutter can't show the sign.

> What happens if I also use another plugin which uses signs (e.g. Syntastic)?

Vim only allows one sign per line.  Before adding a sign to a line, vim-svngutter checks whether a sign has already been added by somebody else.  If so it doesn't do anything.  In other words vim-svngutter won't overwrite another plugin's signs.  It also won't remove another plugin's signs.

> Why aren't any signs showing at all?

Here are some things you can check:

* Your svn config is compatible with the version of svn which your Vim is calling (`:echo system('svn --version')`).
* Your Vim supports signs (`:echo has('signs')` should give `1`).
* Your file is being tracked by svn and has unstaged, saved changes.
* If you use the Fish shell, add `set shell=/bin/bash` to your `~/.vimrc`.


### Alternatives

Related:

* [textobj-svngutter][togg] (lets you treat diff hunks as text objects)
* [vim-svngutter][mercurial] - Mercurial fork

Vim alternatives:

* [svn-gutter-vim][ggv]
* [vim-svn-inline-diff][vgid]
* [quickfixsigns_vim][qf] (a superset of this functionality)
* [iwilldiffer][iwd]
* [svndiff][svndiff]
* [sign-diff][signdiff]
* [changesPlugin][changes]

Other editors:

* [Svn Gutter][st2gg] for Sublime Text 2
* [svn-gutter.el][gge] for Emacs

Also, this may be of interest:

* [fusvnive.vim][fusvnive] is a full-on Svn wrapper.  It doesn't show svn diffs in the gutter (ha!) but it does a bazillion other svn things.


### Shameless Plug

If this plugin has helped you, or you'd like to learn more about Vim, why not check out these two screencasts I wrote for PeepCode:

* [Smash Into Vim I][siv1]
* [Smash Into Vim II][siv2]

You can read reviews at PeepCode and also on my [portfolio][].


### Intellectual Property

Copyright Andrew Stewart, AirBlade Software Ltd.  Released under the MIT licence.


  [st2gg]: https://github.com/jisaacks/SvnGutter
  [pathogen]: https://github.com/tpope/vim-pathogen
  [qf]: https://github.com/tomtom/quickfixsigns_vim
  [fusvnive]: https://github.com/tpope/vim-fusvnive
  [siv1]: https://peepcode.com/products/smash-into-vim-i
  [siv2]: https://peepcode.com/products/smash-into-vim-ii
  [portfolio]: http://airbladesoftware.com/portfolio#vim
  [vgid]: https://github.com/luxflux/vim-svn-inline-diff
  [gge]: https://github.com/syohex/emacs-svn-gutter
  [iwd]: https://bitbucket.org/sirpengi/iwilldiffer
  [svndiff]: http://www.vim.org/scripts/script.php?script_id=1881
  [signdiff]: http://www.vim.org/scripts/script.php?script_id=2712
  [changes]: http://www.vim.org/scripts/script.php?script_id=3052
  [ggv]: https://github.com/akiomik/svn-gutter-vim
  [togg]:https://github.com/gilligan/textobj-svngutter
  [mercurial]: https://github.com/safetydank/vim-svngutter
  [macvim]: http://code.google.com/p/macvim/
