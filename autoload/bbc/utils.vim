if exists('g:autoloaded_bbc_vim_utils')
    finish
endif
let g:autoloaded_bbc_vim_utils = 1

function! bbc#utils#throw(string) abort
    let v:errmsg = 'BBC: '.a:string
    throw v:errmsg
endfunction

function! bbc#utils#config() abort
    let config = get(g:, 'bbc', {})
    if type(config) != type({})
        call bbc#utils#throw('Missing or invalid g:bbc')
    endif
    if has_key(g:, 'jira_url')
        let config.jira_url = g:jira_url
    endif
    if !has_key(config, 'jira_url')
        call bbc#utils#throw('Missing g:bbc.jira_url')
    endif
    return config
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
