if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
function! mildmenu#camelsnake#get_define() "{{{
  return s:define
endfunction
"}}}

let s:define = {}
function! s:define.get_items(lead) "{{{
  let items = []
  if a:lead =~ '_'
    call add(items, substitute(a:lead, '_\(.\)', '\u\1', 'g'))
    call add(items, substitute(items[0], '^\a', '\u\0', ''))
  elseif a:lead =~ '^\u'
    call add(items, substitute(a:lead, '^\u', '\l\0', ''))
    call insert(items, substitute(items[0], '^\@<!\u', '_\l\0', 'g'))
  else
    call add(items, substitute(a:lead, '^\@<!\u', '_\l\0', 'g'))
    call add(items, substitute(a:lead, '^\l', '\u\0', ''))
  end
  return items
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
