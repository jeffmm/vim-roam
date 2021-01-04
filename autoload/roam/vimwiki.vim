" Some functions in this script are modified/extended versions of
" functions from vim-zettel (https://github.com/michal-h21/vim-zettel)

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

" variables that depend on the wiki syntax
if vimwiki#vars#get_wikilocal('syntax') ==? 'markdown'
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
else
  let s:link_format = "[[%link|%title]]"
  let s:link_stub = "[[%link|%title]]"
  let s:header_format = "%%%s %s"
  let s:header_delimiter = ""
  let s:insert_mode_title_format = "h"
  let s:grep_link_pattern = '/\[%s[|#\]]/'
  let s:section_pattern = "= %s ="
end

" Default title format used when creating a note from a link
let s:title_format="%title"
" Default title format used when creating a new roam note
let s:new_title_format="%Y%m%d%H%M"
" Default date used in header
let s:date_format = "%Y%m%d"
" Default location for footer template
let s:template_path = expand("<sfile>:p:h:h:h") . "/templates/roam.tpl"
" Factor used to resize images when copying them to the wiki storage
let s:image_resize_factor = 0.5
" Directory name used to store copied images
let s:image_dir_name = "images"
" Custom variables to be used in template, to be defined by user
let s:custom_variables = {}
" Number of random characters to use when generating a random title
let s:random_char_number = 12

" Enable overriding of these variables
if exists("g:roam_link_format")
  let s:link_format = g:roam_link_format
endif
if exists('g:roam_new_title_format')
  let s:new_title_format=g:roam_new_title_format
endif
if exists('g:roam_title_format')
  let s:title_format=g:roam_title_format
endif
if exists('g:roam_date_format')
  let s:date_format = g:roam_date_format
endif
if exists("g:roam_template_path")
  let s:template_path = g:roam_template_path
endif
if exists("g:roam_image_dir_name")
  let s:image_dir_name = g:roam_image_dir_name
endif
if exists("g:roam_image_resize_factor")
  let s:image_resize_factor = g:roam_image_resize_factor
endif
if exists("g:roam_custom_variables")
  let s:custom_variables = g:roam_custom_variables
endif
if exists("g:roam_random_char_number")
  let s:random_char_number = g:roam_random_char_number
  " Ensure this value isn't nonsense
  let s:random_char_number = max([s:random_char_number, 1])
endif

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
    return s:numtoletter(float2nr(quotient)) . result
  endif 
  return result
endfunction

" sanitize title for filename
function! roam#vimwiki#escape_filename(name)
  let name = substitute(a:name, "[%.%,%?%!%:]", "", "g") " remove unwanted characters
  let schar = vimwiki#vars#get_wikilocal('links_space_char') " ' ' by default
  let name = substitute(name, " ", schar, "g") " change spaces to link_space_char
  return fnameescape(name)
endfunction

" count files that match pattern in the current wiki
function! roam#vimwiki#count_files(pattern) abort
  let cwd = vimwiki#vars#get_wikilocal('path')
  let filelist = split(globpath(cwd, a:pattern), '\n')
  return len(filelist)
endfunction

let s:alphanum = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
" Return a random alpha-numeric character
function! s:rand_alphanum(...)
    " Can pass a value that limits the range of characters to e.g. lowercase
    let max = a:0 > 0 ? a:1 : 62
    if max > 62
        let max = 62
    endif
    " For portability, use the current time in microseconds to generate the
    " random value (PS: this is NOT meant to be a secure random value!)
    let rand = str2nr(split(reltimestr(reltime()), '\.')[1]) % max 
    return s:alphanum[rand]
endfunction

" Get a string of random alpha-numeric characters
function! s:random_string(num) abort
    " Only allow letters as first values, to avoid upsetting OCD people who
    " hate filenames that are invalid variable names
    let rand_name = s:rand_alphanum(52)
    for i in range(a:num - 1)
        let rand_name = rand_name . s:rand_alphanum()
    endfor
    return rand_name
endfunction

function! roam#vimwiki#new_roam_name(title) abort
  " Allow title formatting to change depending on context
  let new_name = s:title_format
  " expand title in s:roam_format
  let new_name = substitute(new_name, "%title", a:title, "")
  if matchstr(new_name, "%date") != ""
    let new_name = substitute(new_name, "%date", s:date_format, "")
  endif
  if matchstr(new_name, "%random") != ""
    let new_name = substitute(new_name, "%random", 
                \ s:random_string(s:random_char_number), "")
  endif
  " Allow users to use standard strftime variables, e.g. %Y%m%d%H%M
  let new_name =  strftime(new_name)
  if !s:wiki_file_not_exists(new_name)
    " if the current file name is used, increase counter and add it as a
    " letter to the file name. this ensures that we don't reuse the filename
    let file_count = roam#vimwiki#count_files(new_name . "*")
    let new_name = new_name . s:numtoletter(file_count)
  endif
  let new_name = roam#vimwiki#escape_filename(new_name)
  return new_name
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

function! roam#vimwiki#format_link(file, title)
  let link = substitute(s:link_format, "%title", a:title, "")
  let link = substitute(link, "%link", a:file, "")
  return link
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
  " detect if the wiki file exists
  let wiki_not_exists = s:wiki_file_not_exists(format)
  " let vimwiki open the wiki file. this is necessary to support the vimwiki navigation commands.
  call vimwiki#base#open_link(':e ', format)
  if wiki_not_exists
    return format
  endif
  return -1
endfunction

function! roam#vimwiki#roam_new(...)
  let filename = roam#vimwiki#create(a:1)
  " the wiki file already exists
  if filename ==? -1
    return 0
  endif
  " insert the template text from a template file
  let template = s:template_path
  if !empty(template)
    let variables = get(a:, 2, 0)
    " If there are no variables, this implies where are creating a note from
    " scratch, so generate variables using the new roam file
    if empty(variables)
      " save file, in order to prevent errors in variable reading
      execute "w"
      let variables = roam#vimwiki#prepare_template_variables(expand("%"), a:1)
      " backlink contains link to new note itself, so we will just disable it
      let variables.backlink = ""
    endif
    " overwrite date since parent date may be wrong by now
    let variables.date = strftime(s:date_format)
    call roam#vimwiki#expand_template(template, variables)
  endif
  " save the new wiki file
  execute "w"
endfunction
"
" expand custom variables defined by users: useful for dynamic values
function! s:expand_custom_variable(value)
  " enable execution of functions that expands to the correct value
  if type(a:value) == v:t_func
    return a:value()
  else
    return a:value
  endif
endfunction

" prepare variables that will be available to expand in the new note template
function! roam#vimwiki#prepare_template_variables(filename, title)
  let variables = {}
  let variables.title = a:title
  let variables.date = strftime(s:date_format)
  " add variables from custom_variables dict, making them available to template
  if !empty(s:custom_variables)
    for key in keys(s:custom_variables)
      let variables[key] = s:expand_custom_variable(s:custom_variables[key])
    endfor
  endif
  let variables.backlink = s:get_link(a:filename)
  return variables
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
  " split the template into lines and add it
  for xline in split(text, "\n")
    " the minus 1 ignores empty line before start of the inserted template
    call append(line('$') - 1, xline)
  endfor
endfunction

" Function for creating a new roam note from scratch
function! roam#vimwiki#roam_new_note() abort
    let idx = vimwiki#vars#get_bufferlocal('wiki_nr')
    if idx > 0
      call vimwiki#base#goto_index(idx)
    else
      call vimwiki#base#goto_index(0)
    endif
    let title = input("New note name: ", roam#vimwiki#new_roam_name(s:new_title_format))
    if title == ""
        return
    endif
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
    let directory = expand("%:p:h") . "/" . s:image_dir_name . "/"
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
                    \ -thumbnail ' . float2nr(round(s:image_resize_factor * width))
                    \ . ' -unsharp 0.25x0.25+8.3+0.065
                    \ -dither None -posterize 136 -quality 82 -define
                    \ jpeg:fancy-upsampling=off -interlace none 
                    \ -colorspace sRGB ' . output
    endif
    execute ":'<,'>s#" . fnameescape(text) . "#![" . name . "](". s:image_dir_name . "/" . name . ".jpg)#"
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

