" vim:tabstop=2:shiftwidth=2:expandtab:textwidth=99
" Vimwiki filetype plugin file
" Home: https://github.com/jeffmm/vim-roam/

" Load ftplugin only once per buffer
if exists('b:roam_ftplugin')
  finish
endif
let b:roam_ftplugin = 1

" Create function for inserting a link to another note
" default format of a new roam note name, from vimwiki link
" if exists("g:roam_title_format")
  " let s:roam_title_format = g:roam_title_format
" else
  " let s:roam_title_format = fnamemodify("%title", ":r")
" endif

command! -buffer -bang RoamInsertLink call roam#fzf#insert_link(<bang>0)
inoremap <silent><script><buffer> <Plug>RoamInsertLink
    \ <ESC>:RoamInsertLink<CR>

" Search for notes that link to current note
command! -buffer -bang RoamBacklinks 
      \ call roam#fzf#rg_text_files(<bang>0, '('.expand("%:t").')',
      \ s:get_default('path'))
nnoremap <silent><script><buffer> <Plug>RoamBacklinks :RoamBacklinks<CR>

" Yank current note name
command! -buffer RoamYankName call roam#vimwiki#wiki_yank_name()
nnoremap <silent><script><buffer> <Plug>RoamYankName :RoamYankName<CR>

command! -buffer RoamNormalizeLinkVisual call roam#vimwiki#normalize_link_visual()
vnoremap <silent><script><buffer> <Plug>RoamNormalizeLinkVisual
      \ :<C-U>RoamNormalizeLinkVisual<CR>
function! s:map_roam_key(mode, keymap, command)
    execute a:mode . 'map <buffer> ' . a:keymap . ' ' . a:command
endfunction

" default links key mappings
if g:roam_default_mappings == 1
  let s:map_prefix = vimwiki#vars#get_global('map_prefix')
  call s:map_roam_key('n', s:map_prefix.'y', '<Plug>RoamYankName')
  call s:map_roam_key('n', s:map_prefix.'b', '<Plug>RoamBacklinks')
  call s:map_roam_key('i', '[]', '<Plug>RoamInsertLink')
  call s:map_roam_key('v', '<CR>', '<Plug>RoamNormalizeLinkVisual')

endif

" Function for overriding the default vimwiki link handler:
" generates a new Roam-style note from link
function! VimwikiLinkHandler(link)
  let link_info = vimwiki#base#resolve_link(a:link)
  " First check that the scheme is an inter-wiki file
  if link_info.scheme ==# 'wiki0'
      if empty(glob(link_info.filename)) 
          let title = fnamemodify(a:link, ":r")
          let name = roam#vimwiki#new_roam_name(title)
          " prepare_template_variables needs the file saved on disk
          execute "w"
          " make variables that will be available in the new page template
          let variables = roam#vimwiki#prepare_template_variables(expand("%"), title)
          " replace the visually selected text with a link to the new roam note
          call roam#vimwiki#roam_new(title, variables)
          " Tell vimwiki that the link has already been handled
          return 1
      endif
  endif
  " Tell vimwiki to follow link as usual
  return 0
endfunction
