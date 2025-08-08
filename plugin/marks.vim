" Vim global plugin for managing and interacting with marks
" Maintainer:   Eran Friedman
" License:      This file is placed in the public domain.


if exists("g:loaded_marks")
  finish
endif
let g:loaded_marks = 1


let s:save_cpo = &cpo
set cpo&vim


function s:CloseBuffer(bufnr)
  wincmd p
  execute "bwipe" a:bufnr
  redraw
endfunction


function s:ShowPopup()
    let l:selected_line = getline('.')
    let l:splitted_line = split(l:selected_line, ":")
    " can be <2 if the list of options is empty and Enter is pressed
    if len(l:splitted_line) < 2
      return
    endif
    let l:filename = l:splitted_line[1]
    let l:line_no = l:splitted_line[2]

    let l:lines = readfile(l:filename)
    let start = max([0, l:line_no - 5])
    let end = min([len(l:lines), l:line_no + 5])
    let preview = l:lines[start:end]
    let g:popup_id = popup_create(preview, #{
          \ line: 5,
          \ col: 10,
          \ minwidth: 60,
          \ minheight: len(preview),
          \ border: [],
          \ padding: [0,1,0,1],
          \ pos: 'topleft'
          \ })
endfunction


function s:IncludeMark(ranges, mark) abort
  if a:ranges is# v:null
    return v:true
  endif

  for range in a:ranges
    let l:start = range[0]
    let l:end = range[1]
    if l:start <= a:mark && a:mark <= l:end
      return v:true
    endif
  endfor

  return v:false
endfunction


function s:InteractiveMenu(ranges) abort
  " settings
  let l:marks_menu_height = get(g:, 'marks_menu_height', 15)
  let l:marks_file_color = get(g:, 'marks_file_color', "blue")

  let l:options = []

  " local marks
  let l:local_marks = getmarklist(bufnr('%'))
  for m in l:local_marks
    " take only a-z marks
    if s:IncludeMark(a:ranges, m["mark"][1])
      let l:line = getbufline(bufnr('%'), m["pos"][1])[0]
      call add(l:options, m["mark"] . ":" . expand('%:p') . ":" . m["pos"][1] . ":" . l:line)
    endif
  endfor

  " global marks
  let l:marks = getmarklist()
  for m in l:marks
    " take only A-Z marks
    if s:IncludeMark(a:ranges, m["mark"][1])
      let l:lines = readfile(expand(m["file"]))
      let l:line = l:lines[m["pos"][1]-1]
      call add(l:options, m["mark"] . ":" . expand(m["file"]) . ":" . m["pos"][1] . ":" . l:line)
    endif
  endfor

  if empty(l:options)
    return [0, v:null, v:null, v:null]
  endif

  bo new +setlocal\ buftype=nofile\ bufhidden=wipe\ nofoldenable\
    \ colorcolumn=0\ nobuflisted\ number\ norelativenumber\ noswapfile\ wrap\ cursorline

  exe 'highlight filename_group ctermfg=' . l:marks_file_color
  match filename_group /^.*:\d\+:/

  let l:cur_buf = bufnr('%')
  call setline(1, l:options)
  exe "res " . l:marks_menu_height
  call s:ShowPopup()
  redraw

  while 1
    try
      let ch = getchar()
    catch /^Vim:Interrupt$/ " CTRL-C
      if exists('g:popup_id')
        call popup_close(g:popup_id)
      endif
      call s:CloseBuffer(l:cur_buf)
      return [0, v:null]
    endtry

    if exists('g:popup_id')
      call popup_close(g:popup_id)
    endif

    if ch ==# 0x1B " ESC
      call s:CloseBuffer(l:cur_buf)
      return [0, v:null]
    elseif ch ==# 0x0D " Enter
      let l:selected_line = getline('.')
      call s:CloseBuffer(l:cur_buf)
      return [1, l:selected_line]
    elseif ch == "\<Up>"
      norm k
    elseif ch == "\<Down>"
      norm j
    elseif ch == "\<PageUp>"
      for i in range(1, l:marks_menu_height)
        norm k
      endfor
    elseif ch == "\<PageDown>"
      for i in range(1, l:marks_menu_height)
        norm j
      endfor
    " Backspace / delete buttons - delete the amrk
    elseif ch is# "\<BS>" || ch is# "\<Del>"
      let l:selected_line = getline('.')
      let l:mark_to_delete = split(l:selected_line, ":")[0][1]
      call s:CloseBuffer(l:cur_buf)
      return [2, l:mark_to_delete]
    endif

    call s:ShowPopup()
    redraw

  endwhile
endfunction


" Args:
" Optional `ranges`: a list of `start` and `end` pairs for filtering marks.
"   Example: to include only marks from a-z or A-Z, provide the following:
"            [["a", "z"], ["A", "Z"]]
function MarksMenu(...)
  let l:ranges = a:0 >= 1 ? a:1 : v:null
  while 1
    let res = s:InteractiveMenu(l:ranges)
    if res[0] == 0 " no selection - exit menu
      return
    elseif res[0] == 2 " delete mark and refresh menu (show menu again)
      execute 'delmarks ' . res[1]
    else " exit while loop and jump to selection
      break
    endif
  endwhile

  " process selection
  let l:selected_line = res[1]
  let l:splitted_line = split(l:selected_line, ":")
  " can be <2 if the list of options is empty and Enter is pressed
  if len(l:splitted_line) < 2
    return
  endif
  let l:filename = l:splitted_line[1]
  let l:line_no = l:splitted_line[2]

  " jump to selection
  execute 'edit +' . l:line_no l:filename
endfunction
