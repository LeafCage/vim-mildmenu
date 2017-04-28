if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_mildmenu')| finish| endif| let g:loaded_mildmenu = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:mildmenu_default_expand = exists('mildmenu_default_expand') ? mildmenu_default_expand : {':': 'abbreviate'}
cnoremap <expr><Plug>(mildmenu-default-expand)      mildmenu#default_expand()
cnoremap <expr><Plug>(mildmenu-abbreviate)  mildmenu#run('abbreviate')
cnoremap <expr><Plug>(mildmenu-winword)     mildmenu#run('winword')
cnoremap <expr><Plug>(mildmenu-camelsnake)  mildmenu#run('camelsnake')

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
