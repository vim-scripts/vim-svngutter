if exists('g:loaded_svngutter') || !executable('svn') || &cp
  finish
endif
let g:loaded_svngutter = 1

" Initialisation {{{

if !exists('g:svngutter_enabled')
  let g:svngutter_enabled = 1
endif

if !exists('g:svngutter_highlights')
  let g:svngutter_highlights = 1
endif

function! s:init()
  if !exists('g:svngutter_initialised')
    let s:highlight_lines = 0
    call s:define_signs()

    if g:svngutter_highlights
      call s:define_highlights()
    endif

    " Vim doesn't namespace sign ids so every plugin shares the same
    " namespace.  Sign ids are simply integers so to avoid clashes with other
    " signs we guess at a clear run.
    "
    " Note also we currently never reset s:next_sign_id.
    let s:first_sign_id = 5000
    let s:next_sign_id = s:first_sign_id
    let s:sign_ids = {}  " key: filename, value: list of sign ids
    let s:other_signs = []

    " Global variable parameter for `svn diff` -- by default call it without context
    if !exists('g:svngutter_svndiffcmd')
      let g:svngutter_svndiffcmd = 'svn diff --diff-cmd=diff -x -U0'
    endif

    let g:svngutter_initialised = 1
  endif
endfunction

function! s:define_highlights()
  highlight lineAdded    guifg=#009900 guibg=NONE ctermfg=2 ctermbg=NONE
  highlight lineModified guifg=#bbbb00 guibg=NONE ctermfg=3 ctermbg=NONE
  highlight lineRemoved  guifg=#ff2222 guibg=NONE ctermfg=1 ctermbg=NONE
endfunction

function! s:define_signs()
  if s:highlight_lines
    sign define SvnGutterLineAdded           text=+  texthl=lineAdded    linehl=DiffAdd
    sign define SvnGutterLineModified        text=~  texthl=lineModified linehl=DiffChange
    sign define SvnGutterLineRemoved         text=_  texthl=lineRemoved  linehl=DiffDelete
    sign define SvnGutterLineModifiedRemoved text=~_ texthl=lineModified linehl=DiffChange
  else
    sign define SvnGutterLineAdded           text=+  texthl=lineAdded    linehl=NONE
    sign define SvnGutterLineModified        text=~  texthl=lineModified linehl=NONE
    sign define SvnGutterLineRemoved         text=_  texthl=lineRemoved  linehl=NONE
    sign define SvnGutterLineModifiedRemoved text=~_ texthl=lineModified linehl=NONE
  endif
endfunction

" }}}

" Utility {{{

function! s:is_active()
  return g:svngutter_enabled && s:exists_current_file() && s:is_in_a_svn_repo() && s:is_tracked_by_svn()
endfunction

function! s:update_line_highlights(highlight_lines)
  let s:highlight_lines = a:highlight_lines
  call s:define_signs()
  redraw!
endfunction

function! s:current_file()
  return expand("%:p")
endfunction

function! s:exists_current_file()
  return strlen(s:current_file()) > 0
endfunction

function! s:directory_of_current_file()
  return shellescape(expand("%:p:h"))
endfunction

function! s:discard_stdout_and_stderr()
  if !exists('s:discard')
    let null_dev = '/dev/null'
    if has("win32") || has("win16")
        let null_dev = 'null'
    endif
    if &shellredir ==? '>%s 2>&1'
      let s:discard = ' > ' . null_dev . ' 2>&1'
    else
      let s:discard = ' >& ' . null_dev
    endif
  endif
  return s:discard
endfunction

function! s:command_in_directory_of_current_file(cmd)
  return 'cd ' . s:directory_of_current_file() . ' && ' . a:cmd
endfunction

function! s:is_in_a_svn_repo()
  let cmd = 'svn log' . s:discard_stdout_and_stderr()
  call system(s:command_in_directory_of_current_file(cmd))
  return !v:shell_error
endfunction

function! s:is_tracked_by_svn()
  let cmd = 'svn info' . s:discard_stdout_and_stderr() . ' ' . shellescape(s:current_file())
  call system(s:command_in_directory_of_current_file(cmd))
  return !v:shell_error
endfunction

" }}}

" Diff processing {{{

function! s:run_diff()
  " Use variable for `svn diff`
  let cmd = g:svngutter_svndiffcmd . ' ' . shellescape(s:current_file()) .
        \ ' | grep -e "^@@ "'
  let diff = system(s:command_in_directory_of_current_file(cmd))
  return diff
endfunction

function! s:parse_diff(diff)
  let hunk_re = '^@@ -\(\d\+\),\?\(\d*\) +\(\d\+\),\?\(\d*\) @@'
  let hunks = []
  for line in split(a:diff, '\n')
    let matches = matchlist(line, hunk_re)
    if len(matches) > 0
      let from_line  = str2nr(matches[1])
      let from_count = (matches[2] == '') ? 1 : str2nr(matches[2])
      let to_line    = str2nr(matches[3])
      let to_count   = (matches[4] == '') ? 1 : str2nr(matches[4])
      call add(hunks, [from_line, from_count, to_line, to_count])
    endif
  endfor
  return hunks
endfunction

function! s:process_hunks(hunks)
  let modified_lines = []
  for hunk in a:hunks
    call extend(modified_lines, s:process_hunk(hunk))
  endfor
  return modified_lines
endfunction

function! s:process_hunk(hunk)
  let modifications = []
  let from_line  = a:hunk[0]
  let from_count = a:hunk[1]
  let to_line    = a:hunk[2]
  let to_count   = a:hunk[3]

  if s:is_added(from_count, to_count)
    call s:process_added(modifications, from_count, to_count, to_line)

  elseif s:is_removed(from_count, to_count)
    call s:process_removed(modifications, from_count, to_count, to_line)

  elseif s:is_modified(from_count, to_count)
    call s:process_modified(modifications, from_count, to_count, to_line)

  elseif s:is_modified_and_added(from_count, to_count)
    call s:process_modified_and_added(modifications, from_count, to_count, to_line)

  elseif s:is_modified_and_removed(from_count, to_count)
    call s:process_modified_and_removed(modifications, from_count, to_count, to_line)

  endif
  return modifications
endfunction

" }}}

" Diff utility {{{

function! s:is_added(from_count, to_count)
  return a:from_count == 0 && a:to_count > 0
endfunction

function! s:is_removed(from_count, to_count)
  return a:from_count > 0 && a:to_count == 0
endfunction

function! s:is_modified(from_count, to_count)
  return a:from_count > 0 && a:to_count > 0 && a:from_count == a:to_count
endfunction

function! s:is_modified_and_added(from_count, to_count)
  return a:from_count > 0 && a:to_count > 0 && a:from_count < a:to_count
endfunction

function! s:is_modified_and_removed(from_count, to_count)
  return a:from_count > 0 && a:to_count > 0 && a:from_count > a:to_count
endfunction

function! s:process_added(modifications, from_count, to_count, to_line)
  let offset = 0
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'added'])
    let offset += 1
  endwhile
endfunction

function! s:process_removed(modifications, from_count, to_count, to_line)
  call add(a:modifications, [a:to_line, 'removed'])
endfunction

function! s:process_modified(modifications, from_count, to_count, to_line)
  let offset = 0
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'modified'])
    let offset += 1
  endwhile
endfunction

function! s:process_modified_and_added(modifications, from_count, to_count, to_line)
  let offset = 0
  while offset < a:from_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'modified'])
    let offset += 1
  endwhile
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'added'])
    let offset += 1
  endwhile
endfunction

function! s:process_modified_and_removed(modifications, from_count, to_count, to_line)
  let offset = 0
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'modified'])
    let offset += 1
  endwhile
  call add(a:modifications, [a:to_line + offset - 1, 'modified_removed'])
endfunction

" }}}

" Sign processing {{{

function! s:clear_signs(file_name)
  if exists('s:sign_ids') && has_key(s:sign_ids, a:file_name)
    for id in s:sign_ids[a:file_name]
      exe ":sign unplace " . id . " file=" . a:file_name
    endfor
    let s:sign_ids[a:file_name] = []
  endif
endfunction

" This assumes there are no GitGutter signs in the current file.
" If this is untenable we could change the regexp to exclude GitGutter's
" signs.
function! s:find_other_signs(file_name)
  redir => signs
  silent exe ":sign place file=" . a:file_name
  redir END
  let s:other_signs = []
  for sign_line in split(signs, '\n')
    if sign_line =~ '^\s\+line'
      let matches = matchlist(sign_line, '^\s\+line=\(\d\+\)')
      let line_number = str2nr(matches[1])
      call add(s:other_signs, line_number)
    endif
  endfor
endfunction

function! s:show_signs(file_name, modified_lines)
  for line in a:modified_lines
    let line_number = line[0]
    let type = line[1]
    " TODO: eugh
    if type ==? 'added'
      let name = 'SvnGutterLineAdded'
    elseif type ==? 'removed'
      let name = 'SvnGutterLineRemoved'
    elseif type ==? 'modified'
      let name = 'SvnGutterLineModified'
    elseif type ==? 'modified_removed'
      let name = 'SvnGutterLineModifiedRemoved'
    endif
    call s:add_sign(line_number, name, a:file_name)
  endfor
endfunction

function! s:add_sign(line_number, name, file_name)
  let id = s:next_sign_id()
  if !s:is_other_sign(a:line_number)  " Don't clobber other people's signs.
    exe ":sign place " . id . " line=" . a:line_number . " name=" . a:name . " file=" . a:file_name
    call s:remember_sign(id, a:file_name)
  endif
endfunction

function! s:next_sign_id()
  let next_id = s:next_sign_id
  let s:next_sign_id += 1
  return next_id
endfunction

function! s:remember_sign(id, file_name)
  if has_key(s:sign_ids, a:file_name)
    let sign_ids_for_current_file = s:sign_ids[a:file_name]
    call add(sign_ids_for_current_file, a:id)
  else
    let sign_ids_for_current_file = [a:id]
  endif
  let s:sign_ids[a:file_name] = sign_ids_for_current_file
endfunction

function! s:is_other_sign(line_number)
  return index(s:other_signs, a:line_number) == -1 ? 0 : 1
endfunction

" }}}

" Public interface {{{

function! SvnGutter()
  if s:is_active()
    call s:init()
    let diff = s:run_diff()
    let s:hunks = s:parse_diff(diff)
    let modified_lines = s:process_hunks(s:hunks)
    let file_name = s:current_file()
    call s:clear_signs(file_name)
    call s:find_other_signs(file_name)
    call s:show_signs(file_name, modified_lines)
  endif
endfunction
command SvnGutter call SvnGutter()

function! DisableSvnGutter()
  let g:svngutter_enabled = 0
  call s:clear_signs(s:current_file())
endfunction
command DisableSvnGutter call DisableSvnGutter()

function! EnableSvnGutter()
  let g:svngutter_enabled = 1
  call SvnGutter()
endfunction
command EnableSvnGutter call EnableSvnGutter()

function! ToggleSvnGutter()
  if g:svngutter_enabled
    call DisableSvnGutter()
  else
    call EnableSvnGutter()
  endif
endfunction
command ToggleSvnGutter call ToggleSvnGutter()

function! DisableSvnGutterLineHighlights()
  call s:update_line_highlights(0)
endfunction
command DisableSvnGutterLineHighlights call DisableSvnGutterLineHighlights()

function! EnableSvnGutterLineHighlights()
  call s:update_line_highlights(1)
endfunction
command EnableSvnGutterLineHighlights call EnableSvnGutterLineHighlights()

function! ToggleSvnGutterLineHighlights()
  call s:update_line_highlights(s:highlight_lines ? 0 : 1)
endfunction
command ToggleSvnGutterLineHighlights call ToggleSvnGutterLineHighlights()

function! SvnGutterNextHunk()
  if s:is_active()
    let current_line = line('.')
    for hunk in s:hunks
      if hunk[2] > current_line
        execute 'normal! ' . hunk[2] . 'G'
        break
      endif
    endfor
  endif
endfunction
command SvnGutterNextHunk call SvnGutterNextHunk()

function! SvnGutterPrevHunk()
  if s:is_active()
    let current_line = line('.')
    for hunk in reverse(copy(s:hunks))
      if hunk[2] < current_line
        execute 'normal! ' . hunk[2] . 'G'
        break
      endif
    endfor
  endif
endfunction
command SvnGutterPrevHunk call SvnGutterPrevHunk()

" Returns the svn diff hunks for the current file or an empty list if there
" aren't any hunks.
"
" The return value is a list of lists.  There is one inner list per hunk.
"
"   [
"     [from_line, from_count, to_line, to_count],
"     [from_line, from_count, to_line, to_count],
"     ...
"   ]
"
" where:
"
" `from`  - refers to the staged file
" `to`    - refers to the working tree's file
" `line`  - refers to the line number where the change starts
" `count` - refers to the number of lines the change covers
function! SvnGutterGetHunks()
  return s:is_active() ? s:hunks : []
endfunction

augroup svngutter
  autocmd!
  autocmd BufReadPost,BufWritePost,FileReadPost,FileWritePost * call SvnGutter()
augroup END

" }}}

" vim:set et sw=2 fdm=marker:
