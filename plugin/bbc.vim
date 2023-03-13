" bbc.vim - completions for GitHub, Jira, Emojis and more
" Maintainer:   Steven Humphrey

" Provides completions for GitHub and Jira
" Makes some assumptions about BBC setup, but might work for other situations
"
" See vim-rhubarb for a more standard GitHub integration

if exists("g:loaded_bbc") || v:version < 700 || &cp
  finish
endif
let g:loaded_bbc = 1

if !exists('g:fugitive_browse_handlers')
  let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('bbc#fugitive#browse_handler')) < 0
  call insert(g:fugitive_browse_handlers, function('bbc#fugitive#browse_handler'))
endif
