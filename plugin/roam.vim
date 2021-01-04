" vim:tabstop=2:shiftwidth=2:expandtab:textwidth=99
" Vim-Roam plugin file
" Home: https://github.com/jeffmm/vim-roam/

if exists("g:loaded_roam") || &compatible
  finish
endif
let g:loaded_roam = 1

if !exists("g:roam_default_mappings")
  let g:roam_default_mappings = 1
endif

" Get the directory the script is installed in
let s:plugin_dir = expand('<sfile>:p:h:h')

let s:old_cpo = &cpoptions
set cpoptions&vim
"
function! s:get_default(val)
  let idx = vimwiki#vars#get_bufferlocal('wiki_nr')
  if idx > 0
    return vimwiki#vars#get_wikilocal(a:val, idx)
  endif
  return vimwiki#vars#get_wikilocal(a:val, 0)
endfunction

" Search note tags, which is any word surrounded by colons (vimwiki style tags)
command! -bang RoamSearchTags 
      \ call roam#fzf#rg_text(<bang>0, ':[a-zA-Z0-9]+:', s:get_default('path'))
nnoremap <silent><script> <Plug>RoamSearchTags :RoamSearchTags<CR>

" Search for text in wiki files
command! -bang RoamSearchText 
      \ call roam#fzf#rg_text(<bang>0, '[a-zA-Z0-9]+', fnameescape(s:get_default('path')))
nnoremap <silent><script> <Plug>RoamSearchText :RoamSearchText<CR>

" Search for filenames in wiki
command! -bang RoamSearchFiles 
      \ call roam#fzf#rg_files(<bang>0, s:get_default('path'), 
      \ "*" . s:get_default('ext'))
nnoremap <silent><script> <Plug>RoamSearchFiles :RoamSearchFiles<CR>

" Create a new note
command! RoamNewNote call roam#vimwiki#roam_new_note()
nnoremap <silent><script> <Plug>RoamNewNote :RoamNewNote<CR>
"
" List unlinked notes and broken links
" TODO: simply uses vimwiki#base#check_links function for now
command! RoamInbox execute "VimwikiCheckLinks"
nnoremap <silent><script> <Plug>RoamInbox :RoamInbox<CR>

function! s:map_roam_key(mode, keymap, command)
    execute a:mode . 'map ' . a:keymap . ' ' . a:command
endfunction

" Set default global key mappings
if g:roam_default_mappings == 1
  " Get the user defined prefix for vimwiki commands (default <leader>w)
  let s:map_prefix = vimwiki#vars#get_global('map_prefix')
  call s:map_roam_key('n', s:map_prefix . 's', '<Plug>RoamSearchText')
  call s:map_roam_key('n', s:map_prefix . 't', '<Plug>RoamSearchTags')
  call s:map_roam_key('n', s:map_prefix . 'f', '<Plug>RoamSearchFiles')
  call s:map_roam_key('n', s:map_prefix . 'n', '<Plug>RoamNewNote')
  call s:map_roam_key('n', s:map_prefix . 'i', '<Plug>RoamInbox')
endif

let &cpoptions = s:old_cpo
