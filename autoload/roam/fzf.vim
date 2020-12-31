
" Search all text that match pattern in files within dir
function! roam#fzf#rg_text(fullscreen, pattern, dir)
  call fzf#vim#grep(
  \   'rg --column --line-number --smart-case --no-heading --color=always ' . shellescape(a:pattern) . ' ' . fnameescape(a:dir), 1,
  \   a:fullscreen ? fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'up:60%')
  \           : fzf#vim#with_preview({'down': '40%', 'options': '--delimiter : --nth 4.. -e'}, 'right:50%', '?'),
  \   a:fullscreen)
endfunction
"
" Search all text that match pattern in files within dir
function! roam#fzf#rg_text_files(fullscreen, pattern, dir)
  call fzf#vim#grep(
  \   'rg --column --line-number --smart-case --no-heading --color=always ' . shellescape(a:pattern) . ' ' . fnameescape(a:dir), 1,
  \   a:fullscreen ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview({'down': '40%'}, 'right:50%', '?'),
  \   a:fullscreen)
endfunction


" Search for files in dir that match pattern
function! roam#fzf#rg_files(fullscreen, dir, pattern)
    call fzf#vim#files(a:dir, fzf#vim#with_preview({
               \ 'source': join(['rg', '--files', '--follow', '--smart-case', '--line-number', '--color never', '--no-messages',
                   \ a:pattern]),
               \ 'down': '40%',
               \ 'options': ['--layout=reverse', '--inline-info']
               \ }), a:fullscreen)
endfunction

function! s:insert_link_file(lines) abort
    if a:lines == [] || a:lines == [''] || a:lines == ['', '']
        call feedkeys('a', 'n')
        return
    endif
    let filename = split(a:lines[1], "\\.md")[0]
    let link = "[" . filename . "](" . a:lines[1] . ")"
    let @* = link
    silent! let @* = link
    silent! let @+ = link
    call feedkeys('pa', 'n')
endfunction

function! roam#fzf#insert_link(fullscreen) abort
      call fzf#vim#files(vimwiki#vars#get_wikilocal('path'), 
      \ {
              \ 'sink*': function('s:insert_link_file'),
              \ 'source': join([
                   \ 'rg',
                   \ '--files',
                   \ '--follow',
                   \ '--smart-case',
                   \ '--line-number',
                   \ '--color never',
                   \ '--no-messages',
                   \ '*'.vimwiki#vars#get_wikilocal('ext'),
                   \ ]),
              \ 'down': '40%',
              \ 'options': [
                  \ '--layout=reverse', '--inline-info',
                    \ '--preview=' . 'cat {}']
              \ }, a:fullscreen)
endfunction
