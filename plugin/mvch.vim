 " mvch.vim -- add simple tools to compare versions of a repository
 " @Author:      luffah
 " @License:     GPLv3
 " @Created:     01.10.2019
 " @Last Change: 31.10.2019
 " @Revision:    1
 "
 " @AsciiArt
 " ~ mVCH ~ (modest version control helper)
 "
 " @Overview
 " This plugin use version control system builtin commands to
 " add a generic comparison tools.
 " Support : git, mercurial
 " Add commands in Vim : AnnotateSplit, DiffRev

fu! s:predetectVCS()
 let l:mercurial_dir=systemlist('cd '.expand('%:p:h').'; hg root 2> /dev/null')
 let l:git_dir=systemlist('cd '.expand('%:p:h').'; git rev-parse --show-toplevel 2> /dev/null')
 if len(l:mercurial_dir)
   let l:typ_dir="mercurial"
   if len(l:git_dir) && match(l:mercurial_dir[0], '^'.l:git_dir[0], 0)
     let l:typ_dir="git"
   endif
 elseif len(l:git_dir)
   let l:typ_dir="git"
 else
   return 0
 endif
 exe 'let b:'.l:typ_dir.'_dir=l:'.l:typ_dir.'_dir[0]'
 exe 'let b:vcs_root=l:'.l:typ_dir.'_dir[0]'
endfu

augroup OutilsVCS
  au!
  au BufRead * call s:predetectVCS()
augroup END

fu! s:getVCS()
  if exists('b:mercurial_dir') && isdirectory(b:mercurial_dir)
    return 'hg'
  elseif exists('b:git_dir') && isdirectory(b:git_dir)
    return 'git'
  endif
  return 0
endfu

" expected format is : name commit date: line
" to format names
let s:_spaces='                                                '
let s:_commitid='\([0-9A-Za-z -]\{10\}\)'
let s:_format='s/^'.s:_commitid.'[0-9A-Za-z-]*\s*/\1 /g;s/'.s:_spaces.'.*//'
" command to get annotation for each vcs
let s:vcs_annotate={
      \'hg': 'hg annotate -n -u -d -q %s',
      \'git': 'git annotate %s | sed ''s/^\([0-9a-z]\+\)\s*(\s*\([0-9A-Za-z -]\+[0-9a-z]\+\)\s*\(([^)]*)\)\?\s*\s\+'.s:_commitid.'\s[^)]\+)\(.*\)$/\2'.s:_spaces.'\1 \4: \5/;'.s:_format.'''',
      \}

let s:vcs_commit_msg={
      \'hg': 'hg log -T {desc} -r %s',
      \'git': 'git log -1 --format=%%B %s',
      \}

let s:vcs_detailled_commit_msg={
      \'hg': 'hg log -C -v -r %s',
      \'git': 'git log -1 %s',
      \}

let s:vcs_patch={
      \'hg': 'hg log -p -r %s',
      \'git': 'git format-patch -1 %s',   
      \}

let s:vcs_diff={
      \'hg': 'hg diff -r %s %s',
      \'git': 'git diff %s -- %s',
      \}

let s:vcs_cat={
      \'hg': 'hg cat -r %s %s',
      \'git': 'git show %s:%s',
      \}

let s:vcs_current_rev={
      \'hg': 'hg  id --num | tr -d +',
      \'git': 'git rev-parse HEAD',
      \}

fu! s:echo_commit_msg(commit, ...)
  echo 
  redraw
  let l:res=s:vcs_commit_msg
  if len(a:000) && a:1 == 'detailled'
    let l:res=s:vcs_detailled_commit_msg
  endif
  let l:msg=system('cd "'.b:_vcs_root.'";'.printf(l:res[b:_vcs],a:commit))
  echo l:msg
endfu

fu! s:show(commit, type)
  let l:vcs_root = b:_vcs_root
  let l:vcs = b:_vcs
  let l:path = b:_vcs_source_path
  call win_gotoid(b:_vcs_source_winid)
  split
  enew
  if a:type == 'patch'
    exe 'read !cd "'.l:vcs_root.'";'.printf(s:vcs_patch[l:vcs], a:commit)
  elseif a:type == 'diff'
    exe 'read !cd "'.l:vcs_root.'";'.printf(s:vcs_diff[l:vcs], a:commit, l:path)
  endif
  let l:panebuf=bufnr('%')
  map <buffer> q <ESC>:q<CR>
  exe 'au QuitPre,BufWinLeave <buffer> silent! bd '.l:panebuf
  setlocal nocursorbind buftype=nofile
  0delete
  0
  setf diff
endfu

fu! s:AnnotateSplit()
  let l:vcs=s:getVCS()
  let l:vcs_root=get(b:, 'vcs_root', '')
  if len(l:vcs)
    try
      let l:win=win_getid(winnr())
      let l:line=line('.')
      let l:path=expand('%:p')
      let l:name=expand('%:t')
      let l:pathdir=expand('%:p:h')
      vnew
      let l:panebuf=bufnr('%')
      map <buffer> q <ESC>:q<CR>
      hi def link AnnotateCurrentCommit LineNr

      exe 'au QuitPre,BufWinLeave <buffer> silent! bd '.l:panebuf
      au BufEnter,CursorMoved <buffer> silent! syn clear AnnotateCurrentCommit
        \ | let b:_cur_line=split(getline('.'),':')[0]
        \ | exe "syn match AnnotateCurrentCommit '".b:_cur_line."'"
      map <buffer> <Cr> :call <SID>echo_commit_msg(split(b:_cur_line, ' ')[-2])<CR>
      map <buffer> v :call <SID>echo_commit_msg(split(b:_cur_line, ' ')[-2], 'detailled')<CR>
      map <buffer> p :call <SID>show(split(b:_cur_line, ' ')[-2], 'patch')<CR>
      map <buffer> d :call <SID>show(split(b:_cur_line, ' ')[-2], 'diff')<CR>
      map <buffer> n :silent! call search(b:_cur_line)<CR>
      map <buffer> N :silent! call search(b:_cur_line, 'b')<CR>
      " TODO
      " map <buffer> <C-n> :silent! call <SID>next_commit(b:_cur_line)<CR>
      " map <buffer> <C-p> :silent! call <SID>next_commit(-1)<CR>
      map <buffer> <F1> :echo "Enter: show message\nv : show detailled message\np : show patch\nd : show diff\nn/N : next/previous change related to the commit\nq: close"<CR>
      let b:_vcs=l:vcs
      let b:_vcs_source_winid=l:win
      let b:_vcs_source_path=l:path
      let b:_vcs_root=l:vcs_root
      setlocal cursorline nowrap
      setlocal buftype=nofile
      setlocal nobuflisted

      exe 'file '.l:name.' Annotations['.l:vcs.']'
      exe 'setlocal statusline=Annotations\ (F1\ =\ help)'
      setlocal listchars=nbsp:¤
      exe 'read !cd '.l:pathdir.'; '.printf(s:vcs_annotate[l:vcs], l:path)
      0delete
      let l:width=len(split(getline('.'),':')[0])
      %s/:.*//
      exe 'vertical resize '.l:width
      call execute(l:line)
      set cursorbind scrollbind scrollopt=hor
      call win_gotoid(l:win)
      exe 'au QuitPre,BufWinLeave,BufUnload,BufHidden <buffer> silent! set nocursorbind | silent! bd! '.l:panebuf
      call execute(l:line)
      set cursorbind scrollbind scrollopt=hor
    endtry
  endif
endfu

fu! s:DiffSplit(rev)
  let l:vcs=s:getVCS()
  let l:vcs_root=get(b:, 'vcs_root', '')
  if len(l:vcs)
    try
      let l:win=win_getid(winnr())
      let l:line=line('.')
      let l:path=expand('%:p')
      let l:path = substitute(l:path, l:vcs_root.'/', '','')
      let l:name=expand('%:t')
      let l:pathdir=expand('%:p:h')
      let l:rev=a:rev
      if !len(l:rev)
        let l:rev=systemlist('cd '.l:pathdir.'; '.s:vcs_current_rev[l:vcs])[0]
      endif
      echo l:rev
      diffthis
      vnew
      let l:panebuf=bufnr('%')
      map <buffer> q <ESC>:q<CR>
      exe 'au QuitPre,BufWinLeave <buffer> silent! bd '.l:panebuf
      exe 'file '.l:name.' Diff['.l:vcs.'] '.l:rev
      exe 'setlocal statusline='.l:name.'\ '.l:rev.'\ (q\ =\ quit)'
      exe 'read !cd '.l:pathdir.'; '.printf(s:vcs_cat[l:vcs], l:rev, l:path)
      0delete
      set buftype=nofile
      call execute(l:line)
      diffthis
      redraw
      call win_gotoid(l:win)
      exe 'au QuitPre,BufWinLeave,BufUnload,BufHidden <buffer> silent! set nocursorbind | silent! bd! '.l:panebuf
    endtry
  endif
endfu

" @mapping F1
" Short help

" @mapping q
" In annotation & diff pane, close.

" @mapping d
" In annotation pane, show diff since revision under cursor (current file).

" @mapping p
" In annotation pane, show patch associated to the changeset.
"
" @mapping n
" In annotation pane, jump to next line with same commit.

" @mapping N
" In annotation pane, jump to previous line with same commit.

" @mapping Enter
" In annotation pane, show commit message

" @mapping v
" In annotation pane, show detailled commit (changeset, files...)

" @command AnnotateSplit
" Open a pane indicating <user, commit, date> for each line
command! AnnotateSplit silent! call s:AnnotateSplit()

" @command DiffRev
" Open split containing diff from previous version
command! DiffRev silent! call s:DiffSplit(<q-args>)
