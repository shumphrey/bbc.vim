" bbc.vim - completions for GitHub, Jira, Emojis and more
" Maintainer:   Steven Humphrey

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
