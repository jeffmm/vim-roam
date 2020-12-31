" vim:tabstop=2:shiftwidth=2:expandtab:textwidth=99
" Vim-Roam plugin file
" Home: https://github.com/jeffmm/roam.vim/

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
command! -nargs=* -bang RoamTags 
      \ call roam#fzf#rg_text(<bang>0, ':[a-zA-Z0-9]+:', s:get_default('path'))
nnoremap <silent><script><buffer> <Plug>RoamTags :RoamTags<CR>

" Search for text in wiki files
command! -nargs=* -bang RoamText 
      \ call roam#fzf#rg_text(<bang>0, '[a-zA-Z0-9]+', fnameescape(s:get_default('path')))
nnoremap <silent><script><buffer> <Plug>RoamText :RoamText<CR>

" Search for filenames in wiki
command! -nargs=* -bang RoamFiles 
      \ call roam#fzf#rg_files(<bang>0, s:get_default('path'), 
      \ "*" . s:get_default('ext'))
nnoremap <silent><script><buffer> <Plug>RoamFiles :RoamFiles<CR>

" Create a new note
command! -nargs=* -bang RoamNewNote call roam#vimwiki#roam_new_note()
nnoremap <silent><script><buffer> <Plug>RoamNewNote :RoamNewNote<CR>
"
" List unlinked notes and broken links
" TODO: simply uses vimwiki's check_links function for now
command! -nargs=* -bang RoamInbox call vimwiki#base#check_links()
nnoremap <silent><script><buffer> <Plug>RoamInbox :RoamInbox<CR>


"
" Set default global key mappings
if g:roam_default_mappings == 1
  " Get the user defined prefix for vimwikiwiki (default <leader>w)
  let s:map_prefix = vimwiki#vars#get_global('map_prefix')
  call vimwiki#u#map_key('n', s:map_prefix . 's', '<Plug>RoamText', 2)
  call vimwiki#u#map_key('n', s:map_prefix . 't', '<Plug>RoamTags', 2)
  call vimwiki#u#map_key('n', s:map_prefix . 'f', '<Plug>RoamFiles', 2)
  call vimwiki#u#map_key('n', s:map_prefix . 'n', '<Plug>RoamNewNote', 2)
  call vimwiki#u#map_key('n', s:map_prefix . 'i', '<Plug>RoamInbox', 2)
endif

let &cpoptions = s:old_cpo
