if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
function! mildmenu#abbreviate#get_define() "{{{
  return s:define
endfunction
"}}}

let s:define = {'cmdtype': ':', 'lead_pattern': g:mildmenu#PRE_CMD_PATTERN. '\%(\w\{-1,}\ze\([;!]\|\d\+\)\|_\w\+\)$', 'use_matchlist_for_lead': 1}
function! s:define.get_items(leads) "{{{
  let items = map(__mildmenu#lim#misc#get_cmdresults(':command')[1:], 'matchstr(v:val, ''\u\w*'')')
  if a:leads[1] =~ '\d'
    let result = s:select_items(copy(items), a:leads[0]. a:leads[1])
    if result!=[]
      return result
    end
  end
  let result = s:select_items(items, a:leads[0])
  return {'items': result, 'appending': a:leads[1]=~'\d' ? ' '. a:leads[1] : a:leads[1]=='!' ? '!' : ''}
endfunction
"}}}

function! s:select_items(items, lead) "{{{
  let pat = '^'. substitute(substitute(a:lead, '\a', '\u\0\\a\\{-}', 'g'), '_', '.\\{-}', 'g')
  return filter(a:items, 'v:val =~# pat')
endfunction
"}}}
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
