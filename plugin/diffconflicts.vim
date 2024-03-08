" Two-way diff each side of a file with Git conflict markers
" Maintainer: Seth House <seth@eseth.com>
" License: MIT

if exists("g:loaded_diffconflicts")
    finish
endif
let g:loaded_diffconflicts = 1

let s:save_cpo = &cpo
set cpo&vim

" CONFIGURATION
if !exists("g:diffconflicts_vcs")
    " Default to git
    let g:diffconflicts_vcs = "git"
endif

let g:loaded_diffconflicts = 1
function! s:hasConflicts()
    try
        silent execute "%s/^<<<<<<< //gn"
        return 1
    catch /Pattern not found/
        return 0
    endtry
endfunction

function! s:diffconfl()
    let l:origBuf = bufnr("%")
    let l:origFt = &filetype

    if g:diffconflicts_vcs == "git"
        " Obtain the git setting for the conflict style.
        let l:conflictStyle = system("git config --get merge.conflictStyle")[:-2]
    else
        " Assume 2way conflict style otherwise.
        let l:conflictStyle = "diff"
    endif

    " Set up the right-hand side.
    rightb vsplit
    enew
    silent execute "read #". l:origBuf
    1delete
    silent execute "file RCONFL"
    silent execute "set filetype=". l:origFt
    diffthis " set foldmethod before editing
    silent execute "g/^<<<<<<< /,/^=======\\r\\?$/d"
    silent execute "g/^>>>>>>> /d"
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted

    " Set up the left-hand side.
    wincmd p
    diffthis " set foldmethod before editing
    if l:conflictStyle ==? "diff3" || l:conflictStyle ==? "zdiff3"
        silent execute "g/^||||||| \\?/,/^>>>>>>> /d"
    else
        silent execute "g/^=======\\r\\?$/,/^>>>>>>> /d"
    endif
    silent execute "g/^<<<<<<< /d"

    diffupdate
endfunction

function! s:showHistory()
    " 1: working, 2: base, 3: local, 4: remote
    let l:base_filename = bufname(2)
    let l:local_filename = bufname(3)
    let l:remote_filename = bufname(4)
    echo l:base_filename

    tabnew
    execute printf("terminal git diff --no-index %s %s", l:base_filename, l:local_filename)

    tabnew
    execute printf("terminal git diff --no-index %s %s", l:base_filename, l:remote_filename)
endfunction

function! s:checkThenShowHistory()
    if g:diffconflicts_vcs == "hg"
        let l:filecheck = 'v:val =~# "\\~base\\." || v:val =~# "\\~local\\." || v:val =~# "\\~other\\."'
    else
        let l:filecheck = 'v:val =~# "BASE" || v:val =~# "LOCAL" || v:val =~# "REMOTE"'
    endif
    let l:xs =
        \ filter(
        \   map(
        \     filter(
        \       range(1, bufnr('$')),
        \       'bufexists(v:val)'
        \     ),
        \     'bufname(v:val)'
        \   ),
        \   l:filecheck
        \ )

    if (len(l:xs) < 3)
        echohl WarningMsg
            \ | echo "Missing one or more of BASE, LOCAL, REMOTE."
            \   ." Was Vim invoked by a Git mergetool?"
            \ | echohl None
        return 1
    else
        call s:showHistory()
        return 0
    endif
endfunction

function! s:checkThenDiff()
    if (s:hasConflicts())
        redraw
        echohl WarningMsg
            \ | echon "Resolve conflicts leftward then save. Use :cq to abort."
            \ | echohl None
        return s:diffconfl()
    else
        echohl WarningMsg | echo "No conflict markers found." | echohl None
    endif
endfunction

command! DiffConflicts call s:checkThenDiff()
command! DiffConflictsShowHistory call s:checkThenShowHistory()
command! DiffConflictsWithHistory call s:checkThenShowHistory()
    \ | 1tabn
    \ | call s:checkThenDiff()

let &cpo = s:save_cpo
unlet s:save_cpo
