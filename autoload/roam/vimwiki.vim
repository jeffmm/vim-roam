" this function is useful for comands in plugin/roam.vim
" set number of the active wiki
function! roam#vimwiki#set_active_wiki(number)
  " this buffer value is used by vimwiki#vars#get_wikilocal to retrieve
  " the current wiki number
  call setbufvar("%","vimwiki_wiki_nr", a:number)
endfunction

" set default wiki number. it is set to -1 when no wiki is initialized
" we will set it to first wiki in wiki list, with number 0
function! roam#vimwiki#initialize_wiki_number()
  if getbufvar("%", "vimwiki_wiki_nr") == -1
    call roam#vimwiki#set_active_wiki(0)
  endif
endfunction
call roam#vimwiki#initialize_wiki_number()

" Set default user options if they are not defined
if !exists('g:roam_options')
    let g:roam_options = [{"front_matter" : [["tags", ""]],
       \ "template" :  expand("<sfile>:p:h:h:h") . "/templates/roam-template.tpl"}, {}]
endif

" get user option for the current wiki
" it seems that it is not possible to set custom options in g:vimwiki_list
" so we need to use our own options
function! roam#vimwiki#get_option(name)
  if !exists('g:roam_options')
    return ""
  endif
  " the options for particular wikis must be in the same order as wiki
  " definitions in g:vimwiki_list
  let idx = vimwiki#vars#get_bufferlocal('wiki_nr')
  let option_number = "g:roam_options[" . idx . "]"
  if exists(option_number)
    if exists(option_number . "." . a:name)
      return g:roam_options[idx][a:name]
    endif
  endif
  return ""
endfunction

" test for end of front matter -- markdown syntax
function! s:test_header_end_md(line, line_num)
  if a:line_num > 0 
    let pos = matchstrpos(a:line, "^\s*---")
    return pos[1]
  endif
  return -1
endfunction

" test for end of front matter -- vimwiki syntax
function! s:test_header_end_wiki(line, line_num)
  " return false for all lines that start with % character
  let pos = matchstrpos(a:line,"^\s*%")
  if pos[1] > -1 
    return -1
  endif
  " first line which is not a tag should be selected
  return 0
endfunction

" variables that depend on the wiki syntax
" add file extension when g:vimwiki_markdown_link_ext is set
if exists("g:vimwiki_markdown_link_ext") && g:vimwiki_markdown_link_ext == 1
    let s:link_format = "[%title](%link.md)"
else
    let s:link_format = "[%title](%link)"
endif

let s:header_format = "%s: %s"
let s:header_delimiter = "---"
let s:insert_mode_title_format = "``l"
let s:grep_link_pattern = '/\(%s\.\{-}m\{-}d\{-}\)/' " match filename in  parens. including optional .md extension
let s:section_pattern = "# %s"

" enable overriding of 
if exists("g:roam_link_format")
  let s:link_format = g:roam_link_format
endif

function! roam#vimwiki#update_listing(lines, title, links_rx)
  let generator = { 'data': a:lines }
  function generator.f() dict
        return self.data
  endfunction
  call vimwiki#base#update_listing_in_buffer(generator, a:title, a:links_rx, line('$')+1, 1, 1)
endfunction

" front matter can be disabled using disable_front_matter local wiki option
let g:roam_disable_front_matter = roam#vimwiki#get_option("disable_front_matter")
if empty(g:roam_disable_front_matter)
  let g:roam_disable_front_matter=0
end

if !exists('g:roam_backlinks_title')
  let g:roam_backlinks_title = "Backlinks"
endif

if exists("g:roam_title_format")
  let s:roam_format = g:roam_title_format
else
  let s:roam_format = fnamemodify("%title", ":r")
endif

" default title used for %title placeholder in g:roam_format if the title is
" empty
if !exists('g:roam_default_title')
  let g:roam_default_title="untitled"
endif

" default date format used in front matter for new roam
if !exists('g:roam_date_format')
  let g:roam_date_format = "%Y%m%d"
endif

if !exists("g:roam_template")
    let g:roam_template = expand("<sfile>:p:h:h:h") . "/templates/roam-template.tpl"
endif

" initialize new roam date. it should be overwritten in roam#vimwiki#create()
let s:roam_date = strftime(g:roam_date_format)


" find end of the front matter variables
function! roam#vimwiki#find_header_end(filename)
  let lines = readfile(a:filename)
  " Markdown and vimwiki use different formats for metadata header, select the
  " right one according to the file type
  let ext = fnamemodify(a:filename, ":e")
  " Funcref variable must start with a capital
  let HeaderTest = function(ext ==? 'md' ? '<sid>test_header_end_md' : '<sid>test_header_end_wiki')
  let i = 0
  for line in lines
    let res = HeaderTest(line, i)
    if res > -1 
      return i
    endif
    let i = i + 1
  endfor
  return 0
endfunction

" helper function to insert a text line to a new roam
function! s:add_line(text)
  " don't append anything if the argument is empty string
  if len(a:text) > 0
    call append(line("1"), a:text)
  endif
endfunction

" enable functions to be passed as front_matter values
" this can be useful to dynamic value setting 
function! s:expand_front_matter_value(value)
  " enable execution of functions that expands to the correct value
  if type(a:value) == v:t_func
    return a:value()
  else
    return a:value
  endif
endfunction

function! s:make_header_item(key, value)
  let val = <sid>expand_front_matter_value(a:value)
  return printf(s:header_format, a:key, val)
endfunction

" add a variable to the roam header
function! s:add_to_header(key, value)
  call <sid>add_line(s:make_header_item(a:key, a:value))
endfunction

let s:letters = "abcdefghijklmnopqrstuvwxyz"

" convert number to str (1 -> a, 27 -> aa)
function! s:numtoletter(num)
  let numletter = strlen(s:letters)
  let charindex = a:num % numletter
  let quotient = a:num / numletter
  if (charindex-1 == -1)
    let charindex = numletter
    let quotient = quotient - 1
  endif

  let result =  strpart(s:letters, charindex - 1, 1)
  if (quotient>=1)
    return <sid>numtoletter(float2nr(quotient)) . result
  endif 
  return result
endfunction

" title and date to a new roam note
function! roam#vimwiki#template(title, date)
  if g:roam_disable_front_matter == 0 
    call <sid>add_line(s:header_delimiter)
    call <sid>add_to_header("date", a:date)
    call <sid>add_to_header("title", a:title)
    call <sid>add_line(s:header_delimiter)
  endif
endfunction


" sanitize title for filename
function! roam#vimwiki#escape_filename(name)
  let name = substitute(a:name, "[%.%,%?%!%:]", "", "g") " remove unwanted characters
  let schar = vimwiki#vars#get_wikilocal('links_space_char') " ' ' by default
  let name = substitute(name, " ", schar, "g") " change spaces to link_space_char

  " JMM - Removing to match with VimRoam
  " let name = tolower(name)
  return fnameescape(name)
endfunction

" count files that match pattern in the current wiki
function! roam#vimwiki#count_files(pattern)
  let cwd = vimwiki#vars#get_wikilocal('path')
  let filelist = split(globpath(cwd, a:pattern), '\n')
  return len(filelist)
endfunction

function! roam#vimwiki#next_counted_file()
  " count notes in the current wiki and return 
  let ext = vimwiki#vars#get_wikilocal('ext')
  let next_file = roam#vimwiki#count_files("*" . ext) + 1
  return next_file
endfunction

function! roam#vimwiki#new_roam_name(...)
  let newformat = "%title"
  if a:0 > 0 && a:1 != "" 
    " title contains safe version of the original title
    " raw_title is exact title
    let title = roam#vimwiki#escape_filename(a:1)
    let raw_title = a:1 
  else
    let title = roam#vimwiki#escape_filename(g:roam_default_title)
    let raw_title = g:roam_default_title
  endif
  " expand title in s:roam_format
  let newformat = substitute(s:roam_format, "%title", title, "")
  let newformat = substitute(newformat, "%raw_title", raw_title, "")
  if matchstr(newformat, "%file_no") != ""
    " file_no counts files in the current wiki and adds 1
    let next_file = roam#vimwiki#next_counted_file()
    let newformat = substitute(newformat,"%file_no", next_file, "")
  endif
  if matchstr(newformat, "%file_alpha") != ""
    " same as file_no, but convert numbers to letters
    let next_file = s:numtoletter(roam#vimwiki#next_counted_file())
    let newformat = substitute(newformat,"%file_alpha", next_file, "")
  endif
  let final_format =  strftime(newformat)
  if !s:wiki_file_not_exists(final_format)
    " if the current file name is used, increase counter and add it as a
    " letter to the file name. this ensures that we don't reuse the filename
    let file_count = roam#vimwiki#count_files(final_format . "*")
    let final_format = final_format . s:numtoletter(file_count)
  endif
  let g:roam_current_id = final_format
  return final_format
endfunction

" the optional argument is the wiki number
function! roam#vimwiki#save_wiki_page(format, ...)
  let defaultidx = vimwiki#vars#get_bufferlocal('wiki_nr')
  let idx = get(a:, 1, defaultidx)
  let newfile = vimwiki#vars#get_wikilocal('path',idx ) . a:format . vimwiki#vars#get_wikilocal('ext',idx )
  " copy the captured file to a new roam
  execute "w! " . newfile
  return newfile
endfunction

" find title in the roam file and return correct link to it
function! s:get_link(filename)
  let title =roam#vimwiki#get_title(a:filename)
  let wikiname = fnamemodify(a:filename, ":t:r")
  if title == ""
    " use the filename as a title if it is empty
    let title = wikiname
  endif
  let link= roam#vimwiki#format_link(wikiname, title)
  return link
endfunction

function! roam#vimwiki#wiki_yank_name()
  let filename = expand("%")
  let link = s:get_link(filename)
  let clipboardtype=&clipboard
  if clipboardtype=="unnamed"  
    let @* = link
  elseif clipboardtype=="unnamedplus"
    let @+ = link
  else
    let @@ = link
  endif
  return link
endfunction


function! roam#vimwiki#format_file_title(format, file, title)
  let link = substitute(a:format, "%title", a:title, "")
  let link = substitute(link, "%link", a:file, "")
  return link
endfunction

" use different link style for wiki and markdown syntaxes
function! roam#vimwiki#format_link(file, title)
  return roam#vimwiki#format_file_title(s:link_format, a:file, a:title)
endfunction

function! roam#vimwiki#format_search_link(file, title)
  return roam#vimwiki#format_file_title(s:link_format, a:file, a:title)
endfunction

" This function is executed when the page referenced by the inserted link
" doesn't contain  title. The cursor is placed at the position where title 
" should start, and insert mode is started
function! roam#vimwiki#insert_mode_in_title()
  execute "normal! " .s:insert_mode_title_format | :startinsert
endfunction

function! roam#vimwiki#get_title(filename)
  let filename = a:filename
  let title = ""
  let lsource = readfile(filename)
  " this code comes from vimwiki's html export plugin
  for line in lsource 
    if line =~# '^\s*%\=title'
      let title = matchstr(line, '^\s*%\=title:\=\s\zs.*')
      return title
    endif
  endfor 
  return ""
endfunction


" check if the file with the current filename exits in wiki
function! s:wiki_file_not_exists(filename)
  let link_info = vimwiki#base#resolve_link(a:filename)
  return empty(glob(link_info.filename)) 
endfunction

" create new roam note
" there is one optional argument, the roam title
function! roam#vimwiki#create(...)
  " name of the new note
  let format = roam#vimwiki#new_roam_name(a:1)
  let date = strftime(g:roam_date_format)
  let s:roam_date = date " save roam date
  " detect if the wiki file exists
  let wiki_not_exists = s:wiki_file_not_exists(format)
  " let vimwiki open the wiki file. this is necessary to support the vimwiki navigation commands.
  call vimwiki#base#open_link(':e ', format)
  " add basic template to the new file
  if wiki_not_exists
    call roam#vimwiki#template(a:1, date)
    return format
  endif
  return -1
endfunction

" front_matter can be list or dict. if it is a dict, then convert it to list
function! s:front_matter_list(front_matter)
  if type(a:front_matter) ==? v:t_list
    return a:front_matter
  endif
  " it is prefered to use a list for front_matter, as it keeps the order of
  " keys. but it is possible to use dict, to keep the backwards compatibility
  let newlist = []
  for key in keys(a:front_matter)
    call add(newlist, [key, a:front_matter[key]])
  endfor
  return newlist
endfunction

function! roam#vimwiki#roam_new(...)
  let filename = roam#vimwiki#create(a:1)
  " the wiki file already exists
  if filename ==? -1
    return 0
  endif
  let front_matter = roam#vimwiki#get_option("front_matter")
  if g:roam_disable_front_matter == 0
    if !empty(front_matter)
      let newfile = roam#vimwiki#save_wiki_page(filename)
      let last_header_line = roam#vimwiki#find_header_end(newfile)
      " ensure that front_matter is a list
      let front_list = s:front_matter_list(front_matter)
      " we must reverse the list, because each line is inserted before the
      " ones inserted earlier
      for values in reverse(copy(front_list))
        call append(last_header_line, <sid>make_header_item(values[0], values[1]))
      endfor
    endif
  endif

  " insert the template text from a template file if it is configured in
  " g:roam_options for the current wiki
  let template = roam#vimwiki#get_option("template")
  if !empty(template)
    let variables = get(a:, 2, 0)
    if empty(variables)
      " save file, in order to prevent errors in variable reading
      execute "w"
      let variables = roam#vimwiki#prepare_template_variables(expand("%"), a:1)
      " backlink contains link to new note itself, so we will just disable it
      let variables.backlink = ""
    endif
    " we may reuse varaibles from the parent roam. date would be wrong in this case,
    " so we will overwrite it with the current roam date
    let variables.date = s:roam_date 
    call roam#vimwiki#expand_template(template, variables)
  endif
  " save the new wiki file
  execute "w"
endfunction

" prepare variables that will be available to expand in the new note template
function! roam#vimwiki#prepare_template_variables(filename, title)
  let variables = {}
  let variables.title = a:title
  let variables.date = s:roam_date
  " add variables from front_matter, to make them available in the template
  let front_matter = roam#vimwiki#get_option("front_matter")
  if !empty(front_matter)
    let front_list = s:front_matter_list(front_matter)
    for entry in copy(front_list)
      let variables[entry[0]] = <sid>expand_front_matter_value(entry[1])
    endfor
  endif
  let variables.backlink = s:get_link(a:filename)
  " we want to save footer of the parent note. It can contain stuff that can
  " be useful in the child note, like citations,  etc. Footer is everything
  " below last horizontal rule (----)
  let variables.footer = s:read_footer(a:filename)
  return variables
endfunction

" find and return footer in the file
" footer is content below last horizontal rule (----)
function! s:read_footer(filename)
  let lines = readfile(a:filename)
  let footer_lines = []
  let found_footer = -1
  " return empty footer if we couldn't find the footer
  let footer = "" 
  " process lines from the last one and try to find the rule
  for line in reverse(lines) 
    if match(line, "^ \*----") == 0
      let found_footer = 0
      break
    endif
    call add(footer_lines, line)
  endfor
  if found_footer == 0
    let footer = join(reverse(footer_lines), "\n")
  endif
  return footer
endfunction

" populate new note using template
function! roam#vimwiki#expand_template(template, variables)
  " readfile returns list, we need to convert it to string 
  " in order to do global replace
  let template_file = expand(a:template)
  if !filereadable(template_file) 
    return 
  endif
  let content = readfile(template_file)
  let text = join(content, "\n")
  for key in keys(a:variables)
    let text = substitute(text, "%" . key, a:variables[key], "g")
  endfor
  " when front_matter is disabled, there is an empty line before 
  " start of the inserted template. we need to ignore it.
  let correction = 0
  if line('$') == 1 
    let correction = 1
  endif
  " add template at the end
  " we must split it, 
  for xline in split(text, "\n")
    call append(line('$') - correction, xline)
  endfor
endfunction


" Function for creating a new roam note from scratch
function! roam#vimwiki#roam_new_note()
    let idx = vimwiki#vars#get_bufferlocal('wiki_nr')
    if idx > 0
      call vimwiki#base#goto_index(idx)
    else
      call vimwiki#base#goto_index(0)
    endif
    let title = input("New note name: ", strftime(g:roam_date_format))
    let title = roam#vimwiki#get_title(title)
    call roam#vimwiki#roam_new(title)
endfunction

function! s:convert_to_image_link(url)
    let text = trim(a:url)
    if empty(glob(expand(text)))
        return
    endif
    let extension = fnamemodify(text, ":e")
    let name = fnamemodify(text, ":t:r")
    if extension !=? "png" && extension[:2] !=? "tif" && extension !=? "bmp" && extension !=? "jpg" && extension !=? "jpeg"
        return
    endif
    let directory = expand("%:p:h") . "/images/"
    if empty(glob(directory))
        silent! execute "!mkdir " . directory
    endif
    let name = substitute(name, " ", "_", "g")
    let output = directory . name . ".jpg"
    if extension !=? "png" && extension[:2] !=? "tif" && extension !=? "bmp"
        silent! execute "!convert " . text . " " . output
    else
        silent! execute "!cp " . text . " " . output
    endif
    " Reduce file size if ImageMagick is installed
    if executable("mogrify")
        let width = system("identify -format '%w' " . output)
        silent! execute '!mogrify -filter Triangle -define filter:support=2 
                    \ -thumbnail ' . float2nr(round(width/2))
                    \ . ' -unsharp 0.25x0.25+8.3+0.065
                    \ -dither None -posterize 136 -quality 82 -define
                    \ jpeg:fancy-upsampling=off -interlace none 
                    \ -colorspace sRGB ' . output
    endif
    execute ":'<,'>s#" . fnameescape(text) . "#![" . name . "](images/" . name . ".jpg)#"
endfunction


" Normalize link in visual mode Enter keypress
function! roam#vimwiki#normalize_link_visual() abort
  " Get selection content (this isn't a builtin, unfortunately)
  let visual_selection = vimwiki#u#get_selection()
  let extension = fnamemodify(trim(visual_selection), ":e")
  if extension ==? "png" || extension[:2] ==? "tif" || extension ==? "bmp" || extension ==? "jpg" || extension ==? "jpeg"
    call s:convert_to_image_link(visual_selection)
    return
  else
    call vimwiki#base#normalize_link(1)
  endif
endfunction

