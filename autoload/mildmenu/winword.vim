if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
function! mildmenu#winword#get_define() "{{{
  return s:define
endfunction
"}}}

let s:define = {'lead_pattern': '\k*$'}
function! s:define.get_items(lead) "{{{
  let [items, seen] = [[], {}]
  let pat = a:lead=='' ? '\<\k\{3,}\>' : '\<'. a:lead. '.\{-}\>'
  for bufnr in s:get_winbufnrs()
    for line in getbufline(bufnr, 1, '$')
      let i = match(line, pat)
      while i != -1
        let s = matchstr(line, pat, i)
        if !has_key(seen, s)
          let seen[s] = add(items, s)
        end
        let i = match(line, pat, i+len(s))
      endwhile
    endfor
  endfor
  return sort(items, 1)
endfunction
"}}}

function! s:get_winbufnrs() "{{{
  let bufs = {}
  let i = winnr('$')
  while i > 0
    let bufnr = winbufnr(i)
    if !has_key(bufs, bufnr) && getbufvar(bufnr, '&bt')==''
      let bufs[bufnr] = bufnr
    end
    let i -= 1
  endwhile
  return values(bufs)
endfunction
"}}}
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
