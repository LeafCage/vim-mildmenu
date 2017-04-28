if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
if !exists('g:mildmenu#PRE_CMD_PATTERN')
  let g:mildmenu#PRE_CMD_PATTERN = '^\s*[,;]*\%(\%(\d\+\|[.$%]\|/.\{-}/\|?.\{-}?\|\\[/?&]\|''[''`"^.<>()[\]{}[:alnum:]]\)\s*\%([+-]\d*\s*\)\?[,;]*\s*\)*\zs'
  lockvar g:mildmenu#PRE_CMD_PATTERN
end
let s:LISTMODE_MAX_HEIGHT = 19
let s:LISTMODE_MAX_PRINTF = 18
function! s:eval_define(cmdline, cmdpos, cmdtype, definename) "{{{
  if a:definename==''
    return {}
  end
  try
    let define = deepcopy(mildmenu#{a:definename}#get_define())
  catch /E117:/
    echoerr 'mildmenu: failed to call mildmenu#'. a:definename. '#get_define().'
    return {}
  endtry
  if get(define, 'cmdtype', ':/?@-') !~# a:cmdtype
    return {}
  end
  let leftline = a:cmdline[: a:cmdpos-2]
  let lead_pattern = get(define, 'lead_pattern', '\w*$')
  let leads = matchlist(leftline, lead_pattern)
  if leads==[]
    return {}
  end
  let ret = {'definename': a:definename, 'leadbgn': match(leftline, lead_pattern), 'lead': leads[0], 'complete_single_item': get(define, 'complete_single_item', 1)}
  let ret.lead_orig = leftline[ret.leadbgn :]
  try
    let items = call(define.get_items, [get(define, 'use_matchlist_for_lead', 0) ? leads : ret.lead], define)
  catch
    echoerr 'Error detected while "'. a:definename. '".get_items(): '. v:throwpoint. ' '. v:exception
    return {}
  endtry
  let [ret.items, ret.appending] = type(items)==type({}) ? [get(items, 'items', []), get(items, 'appending', '')] : [items, '']
  if type(ret.items) != type([])
    echoerr 'mildmenu: get_items() should return LIST.'
    return {}
  end
  return ret
endfunction
"}}}
function! s:get_listmode_height(len, lane) "{{{
  let height = a:len / a:lane
  if a:len % a:lane
    let height += 1
  end
  return height > s:LISTMODE_MAX_HEIGHT ? s:LISTMODE_MAX_HEIGHT : height
endfunction
"}}}
function! s:is_valid_mildmenu_mode(mildmenu_mode) "{{{
  return type(a:mildmenu_mode)==type('') && a:mildmenu_mode =~# '^\%(\|\%(\%(full\|longest\|list\)\%(:\%(full\|longest\|list\)\)*\)\%(,\%(full\|longest\|list\)\%(:\%(full\|longest\|list\)\)*\)*\)$'
endfunction
"}}}

function! s:call_builtin_wildmode() "{{{
  cnoremap <Plug>(mildmenu:tab)  <Tab>
  cnoremap <expr><Plug>(mildmenu:rest-wcm)   mildmenu#_call_builtin__rest_wcm()
  let s:save_wcm = &wcm
  set wildcharm=<Tab>
  call feedkeys("\<Plug>(mildmenu:tab)\<Plug>(mildmenu:rest-wcm)", 'm')
endfunction
"}}}
function! mildmenu#_call_builtin__rest_wcm() "{{{
  cunmap <Plug>(mildmenu:tab)
  cunmap <Plug>(mildmenu:rest-wcm)
  let &wcm = s:save_wcm
  unlet s:save_wcm
  let s:save_builtin_expand_context = [getcmdline(), getcmdpos()]
  return ''
endfunction
"}}}

let s:OnReservedOptHolder = {}
function! s:newOnReservedOptSaver() "{{{
  let obj = copy(s:OnReservedOptHolder)
  let obj.cmdheight = &l:cmdheight
  let obj.updatetime = &updatetime
  let obj.more = &more
  return obj
endfunction
"}}}
function! s:OnReservedOptHolder.rest() "{{{
  let &l:cmdheight = self.cmdheight
  let &updatetime = self.updatetime
  let &more = self.more
endfunction
"}}}

let s:Mng = {}
function! s:newMng(cmdline, cmdpos, define_result) "{{{
  let obj = copy(s:Mng)
  let obj.cmdline = a:cmdline "現在のカーソルラインを表す。カーソルライン変更時にはこれも変更させる
  let obj.cmdpos = a:cmdpos
  let obj.definename = a:define_result.definename
  let obj._leadbgn = a:define_result.leadbgn
  let obj.lead_orig = a:define_result.lead_orig
  let obj.appending = a:define_result.appending
  let obj.complete_single_item = a:define_result.complete_single_item
  let obj.itemHolder = s:newItemHolder(a:define_result.items)
  let obj.wildmodes = s:newWildModes()
  let obj.listMode = {}
  let obj._is_finished = 0
  return obj
endfunction
"}}}
function! s:Mng.is_succeeded(cmdline, cmdpos, ...) "{{{
  if !((a:0 ? a:1 ==# self.definename : 1) && !self._is_finished && self.wildmodes.is_continuable())
    return 0
  elseif self.cmdline ==# a:cmdline && self.cmdpos == a:cmdpos
    return 1
  end
  let self.lead_orig = a:cmdline[self._leadbgn : a:cmdpos-2]
  if self.itemHolder.is_invalid_by_narrowing(self.lead_orig)
    return 0
  end
  let self.cmdline = a:cmdline
  let self.cmdpos = a:cmdpos
  return 1

  "TEMP
  echom 'succeed' (a:0 ? a:1 ==# self.definename : 1)  !self._is_finished  self.wildmodes.is_continuable()  self.cmdline ==# a:cmdline  self.cmdpos == a:cmdpos
  return (a:0 ? a:1 ==# self.definename : 1) && !self._is_finished && self.wildmodes.is_continuable() && self.cmdline ==# a:cmdline && self.cmdpos == a:cmdpos
endfunction
"}}}
function! s:Mng.fire() "{{{
  let mode = self.wildmodes.next()
  if mode=='' || self.complete_single_item && self.itemHolder.is_only()
    let self._is_finished = 1
    let item = self.itemHolder.get_first()
    return item=='' ? '' : self.replace_lead_by(item)
  end
  if self.complete_single_item && mode =~# 'longest'
    let ret = self.itemHolder.get_longest()
    if ret =~ '^\V'. escape(self.lead_orig, '\')
      call histadd(getcmdtype(), self.cmdline)
    else
      let ret = self.lead_orig
    end
  else
    let ret = self.lead_orig
  end
  if mode =~# 'list' && self.listMode=={}
    let self.listMode = self.itemHolder.newListMode(self.cmdline)
  end
  if mode =~# 'full'
    let self._is_finished = 1
    let fmItems = self.itemHolder.newFullModeItems(self.lead_orig)
    let fullMode = self.newFullMode(fmItems, self.listMode)
    let mappingdef = fullMode.get_mappingdef(self.definename)
    try
      let [ret, surplus] = fullMode.loop(mappingdef)
      let ret .= self.appending
    catch /E523:/
      return self.replace_lead_by(fmItems.get_crrlead())
    finally
      call fullMode.finalize()
    endtry
    if surplus!=''
      call feedkeys(substitute(surplus, "\<Esc>", "\<C-c>", "g"), 'm')
    end
  end
  if self.listMode!={}
    call self.listMode.reserve()
  end
  return self.replace_lead_by(ret)
endfunction
"}}}
function! s:Mng.showlist() "{{{
  call self.listMode.set_cmdheight()
  let &l:cmdheight = self.listMode.height + 1
  redraw
  echo self.listMode.get_liststr(). ":". getcmdline()
  let &l:cmdheight = 1
  call feedkeys(" \<BS>", 'n')
endfunction
"}}}
function! s:Mng.append(str) "{{{
  let str = a:str=='' ? self.lead_orig : a:str
  let self.cmdline = self.get_left(). str. self.get_right()
  let self.cmdpos = self._leadbgn + len(str) + 1
  return str
endfunction
"}}}
function! s:Mng.replace_lead_by(str) "{{{
  if a:str==#self.lead_orig
    return ''
  end
  let bs = substitute(self.lead_orig, '.', "\<BS>", 'g')
  let self.lead_orig = a:str
  let self.cmdline = self.get_left(). a:str. self.get_right()
  let self.cmdpos = self._leadbgn + len(a:str) + 1
  return bs. self.lead_orig
endfunction
"}}}
function! s:Mng.get_left() "{{{
  return self._leadbgn==0 ? '' : self.cmdline[: self._leadbgn-1]
endfunction
"}}}
function! s:Mng.get_right() "{{{
  return self.cmdline[self.cmdpos-1 :]
endfunction
"}}}

let s:ItemHolder = {}
function! s:newItemHolder(items) "{{{
  let obj = copy(s:ItemHolder)
  let obj.items = a:items
  let obj.len = len(a:items)
  return obj
endfunction
"}}}
function! s:ItemHolder.is_invalid_by_narrowing(lead) "{{{
  call filter(self.items, 'v:val =~ "^". a:lead')
  let self.len = len(self.items)
  return self.len==0
endfunction
"}}}
function! s:ItemHolder.is_only() "{{{
  return self.len < 2
endfunction
"}}}
function! s:ItemHolder.get_first() "{{{
  return self.items==[] ? '' : self.items[0]
endfunction
"}}}
function! s:ItemHolder.get_longest() "{{{
  let i = 0
  while self.items[0][i] ==# self.items[1][i]
    let i += 1
  endwhile
  if i==0
    return ''
  end
  let longest = self.items[0][: i-1]
  let j = 2
  while j < self.len && longest!=''
    let longest = matchstr(self.items[j], '^\V\%['. escape(longest, '\'). ']')
    let j += 1
  endwhile
  return longest
endfunction
"}}}

let s:WildModes = {}
function! s:newWildModes() "{{{
  let obj = copy(s:WildModes)
  let obj.modes = split(exists('g:mildmenu_mode') && s:is_valid_mildmenu_mode(g:mildmenu_mode) ? g:mildmenu_mode : &wildmode, ',')
  let obj.len = len(obj.modes)
  let obj.i = -1
  return obj
endfunction
"}}}
function! s:WildModes.is_continuable() "{{{
  return self.i+1 < self.len
endfunction
"}}}
function! s:WildModes.next() "{{{
  let self.i += 1
  return get(self.modes, self.i, '')
endfunction
"}}}

let s:ListMode = {}
function! s:ItemHolder.newListMode(cmdline) "{{{
  let lanewidth = 0
  for item in self.items
    let w = strwidth(item)
    let lanewidth = w > lanewidth ? w : lanewidth
  endfor
  let lanewidth += 2
  let lane = (&columns-1) / lanewidth
  let lane = lane > s:LISTMODE_MAX_PRINTF ? s:LISTMODE_MAX_PRINTF : lane
  let height = s:get_listmode_height(self.len, lane)
  let [fmt, eachmax, items] = [repeat('%-'. lanewidth . 's', lane), height * (lane-1), self.items]
  let row = 0
  let str = ':'. a:cmdline. "\n"
  while row < height
    let str .= call('printf', [fmt] + map(range(row, row + eachmax, height), 'get(items, v:val, "")')). "\n"
    let row += 1
  endwhile
  let obj = copy(s:ListMode)
  let obj.height = height
  let obj.str = str
  return obj
endfunction
"}}}
function! s:ListMode.set_cmdheight() "{{{
  set nomore
  let &l:cmdheight = 1
  let &l:cmdheight = self.height + 2
endfunction
"}}}
function! s:ListMode.get_liststr() "{{{
  return self.str
endfunction
"}}}
function! s:ListMode.reserve() "{{{
  cnoremap <expr><Plug>(mildmenu:showlist)   mildmenu#_reserved__showlist()
  call feedkeys("\<Plug>(mildmenu:showlist)", 'm')
endfunction
"}}}
function! mildmenu#_reserved__showlist() "{{{
  cunmap <Plug>(mildmenu:showlist)
  let s:optSaver = exists('s:optSaver') ? s:optSaver : s:newOnReservedOptSaver()
  call s:mng.showlist()
  set updatetime=1
  aug mildmenu-on_leave_cmdline
    autocmd!
    autocmd CursorHold  * call mildmenu#_rest_cmdheight()
    autocmd CursorHoldI * call mildmenu#_rest_cmdheight()
  aug END
  return ''
endfunction
"}}}
function! mildmenu#_rest_cmdheight() "{{{
  call s:optSaver.rest()
  unlet! s:optSaver s:mng s:save_builtin_expand_context
  autocmd! mildmenu-on_leave_cmdline
endfunction
"}}}

let s:FullMode = {}
function! s:Mng.newFullMode(fmItems, listMode) "{{{
  let obj = copy(s:FullMode)
  let obj._left = self.get_left()
  let obj._right = self.get_right()
  let obj._appending = self.appending
  let obj.lead_orig = self.lead_orig
  let obj._listMode = a:listMode
  let obj.fmItems = a:fmItems
  let obj._save_lastwinnr = winnr('$')
  let obj._save_stl = getwinvar(obj._save_lastwinnr, '&stl')
  let obj._save_cmdheight = &l:cmdheight
  let obj._save_guicursor = &gcr
  let obj._save_t_ve = &t_ve
  let obj._save_more = &more
  return obj
endfunction
"}}}
function! s:FullMode.get_mappingdef(definename) "{{{
  let def = {"\<Left>": '_prev', "\<C-p>": '_prev', "\<S-Tab>": '_prev', "\<Right>": '_next', "\<C-n>": '_next'}
  let def[nr2char(&wildchar)] = '_next'
  let pat = '^\S\s\+\S\+\s\+\*\?<Plug>(mildmenu-'. a:definename. '.\{-})$'
  for mapping in map(filter(__mildmenu#lim#misc#get_cmdresults(':cmap'), 'v:val =~# pat'), '__mildmenu#lim#misc#expand_keycodes(matchstr(v:val, ''^\S\s\+\zs\S\+''))')
    let def[mapping] = '_next'
    let def[split(mapping, '\zs')[-1]] = '_next'
  endfor
  return def
endfunction
"}}}
function! s:FullMode.loop(mappingdef) abort "{{{
  if self._listMode!={}
    call self._listMode.set_cmdheight()
  end
  if self._right!=''
    setl gcr=a:block-blinkon0-NONE t_ve=
  end
  call self._draw()
  while 1
    let input = __mildmenu#lim#cap#keymappings(a:mappingdef, {'transit': 1})
    if !(v:version>704 || v:version==704 && has('patch870')) && get(input, 'surplus', '')[0]=="\x80" && input.surplus[1]=="\xfc"
      continue
    elseif input=={} || !has_key(self, input.action)
      return [self.fmItems.get_crrlead(), get(input, 'surplus', '')]
    end
    call self[input.action]()
    call self._draw()
  endwhile
endfunction
"}}}
function! s:FullMode.finalize() "{{{
  call setwinvar(self._save_lastwinnr, '&stl', self._save_stl)
  let &l:cmdheight = self._save_cmdheight
  let &l:gcr = 1
  let &l:gcr = self._save_guicursor
  let &l:t_ve = self._save_t_ve
  let &more = self._save_more
  redraw
endfunction
"}}}
function! s:FullMode._draw() "{{{
  call setwinvar(self._save_lastwinnr, '&stl', self.fmItems.get_stl())
  redraw
  let crrlead = self.fmItems.get_crrlead()
  let str = self._left. (crrlead ==# self.lead_orig ? crrlead : crrlead. self._appending)
  echo (self._listMode=={} ? '' : self._listMode.get_liststr()). ":". str
  if self._right==''
    return
  end
  echoh Cursor
  echon self._right[0]
  echoh NONE
  echon self._right[1:]
endfunction
"}}}
function! s:FullMode._prev() "{{{
  call self.fmItems.prev()
endfunction
"}}}
function! s:FullMode._next() "{{{
  call self.fmItems.next()
endfunction
"}}}

let s:FullModeItems = {}
function! s:ItemHolder.newFullModeItems(lead_orig) "{{{
  let last = self.len-1
  let origitems = self.items
  let items = []
  let [i, j] = [0, 0]
  while j <= last
    call add(items, i==0 ? [a:lead_orig] : [])
    let width = i==0 ? 0 : 2
    while j <= last
      let width += strwidth(origitems[j]) + 2
      if !(items[i]==[] || (j>=last ? width-2 : width) < &co)
        break
      end
      call add(items[i], origitems[j])
      let j += 1
    endwhile
    let i += 1
  endwhile
  let obj = copy(s:FullModeItems)
  let obj.items = items
  let obj.last = len(items)-1
  let obj.i = 0
  let obj.j = 1
  return obj
endfunction
"}}}
function! s:FullModeItems.get_stl() "{{{
  let items = self.items[self.i]
  let stl = '%#StatusLine#'
  if self.i > 0
    let stl .= '< '
    if self.j > 0
      let stl .= join(items[: self.j-1], '  '). '  '
    end
    let stl .= '%#WildMenu#'. items[self.j]. '%#StatusLine#'
    if self.j < len(items)-1
      let stl .= '  '. join(items[self.j+1 :], '  ')
    end
  else
    let stl .= join(items[1 : self.j-1], '  ')
    if self.j > 0
      let stl .= (self.j==1 ? '' : '  '). '%#WildMenu#'. items[self.j]. '%#StatusLine#'
      if self.j < len(items)-1
        let stl .= '  '. join(items[self.j+1 :], '  ')
      end
    end
  end
  if self.i != self.last
    let stl .= ' >'
  end
  return stl
endfunction
"}}}
function! s:FullModeItems.get_crrlead() "{{{
  return self.items[self.i][self.j]
endfunction
"}}}
function! s:FullModeItems.prev() "{{{
  if self.j > 0
    let self.j -= 1
  elseif self.i > 0
    let self.i -= 1
    let self.j = len(self.items[self.i])-1
  else
    let self.i = self.last
    let self.j = len(self.items[self.i])-1
  end
endfunction
"}}}
function! s:FullModeItems.next() "{{{
  if self.j < len(self.items[self.i])-1
    let self.j += 1
  elseif self.i < self.last
    let self.i += 1
    let self.j = 0
  else
    let self.i = 0
    let self.j = 0
  end
endfunction
"}}}

"======================================
"Main:
function! mildmenu#default_expand() abort "{{{
  let [cmdline, cmdpos] = [getcmdline(), getcmdpos()]
  if exists('s:mng') && s:mng.is_succeeded(cmdline, cmdpos)
    return s:mng.fire()
  end
  let cmdtype = getcmdtype()
  let define_result = s:eval_define(cmdline, cmdpos, cmdtype, exists('g:mildmenu_default_expand') ? get(g:mildmenu_default_expand, cmdtype, '') : 'abbreviate')
  if (exists('s:save_builtin_expand_context') && s:save_builtin_expand_context ==# [cmdline, cmdpos]) || define_result=={}
    call s:call_builtin_wildmode()
    return ''
  end
  unlet! s:save_builtin_expand_context
  let s:mng = s:newMng(cmdline, cmdpos, define_result)
  return s:mng.fire()
endfunction
"}}}
function! mildmenu#run(definename) abort "{{{
  unlet! s:save_builtin_expand_context
  let [cmdline, cmdpos] = [getcmdline(), getcmdpos()]
  if exists('s:mng') && s:mng.is_succeeded(cmdline, cmdpos, a:definename)
    return s:mng.fire()
  end
  let define_result = s:eval_define(cmdline, cmdpos, getcmdtype(), a:definename)
  if define_result=={}
    return ''
  end
  let s:mng = s:newMng(cmdline, cmdpos, define_result)
  return s:mng.fire()
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
