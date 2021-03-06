if exists('g:autoloaded_bbc_jira_api')
    finish
endif
let g:autoloaded_bbc_jira_api = 1

function! s:url_encode(text) abort
    return substitute(a:text, '[?@=&<>%#/:+[:space:]]', '\=submatch(0)==" "?"+":printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

" :call setreg('+', b:jira_last_curl)
function! bbc#jira#request(path, ...) abort
    let domain = get(b:, 'jira_domain', get(g:, 'jira_domain'))
    let root = get(b:, 'jira_api_path', get(g:, 'jira_api_path', '/rest/api/2'))

    if empty(domain) || empty(root)
        call jira#utils#throw('Missing g:jira_domain config')
    endif

    if !executable('curl')
        call jira#utils#throw('curl is required for jira')
    endif

    let data = ['-sS', '-A', 'bbc/vim']

    let url = domain . root . a:path

    call extend(data, [url])

    let mapped = map(copy(data), 'shellescape(v:val)')
    let curl_options = join(mapped, ' ')
    let b:jira_last_curl = 'curl '.curl_options

    let options = a:0 ? a:1 : {}
    if has_key(options, 'async')
        let cmd = extend(['curl'], data)
        return job_start(cmd, options.async)
    endif

    silent let raw = system('curl '.options)
    let b:jira_last_raw = raw

    if !empty(v:shell_error)
        if !empty(b:jira_last_raw)
            echoerr b:jira_last_raw
        endif
        call bbc#utils#throw('Error running curl command. See b:jira_last_curl')
    endif

    return json_decode(raw)
endfunction

function! bbc#jira#search(jql, ...)
    try
        return bbc#jira#request('/search?fields=summary,project,issuetype,description,assignee,reporter,components&maxResults=1000&jql='.s:url_encode(a:jql))
    catch /^BBC:/
        echoerr v:errmsg
    endtry
    return []
endfunction

" Note this is deprecated in v3 api
" We'll want to change this to /project/search?query=<term>
" For now, the v2 api just returns everything
function! bbc#jira#projects_async(search, async)
    return bbc#jira#request('/project', { 'async': a:async })
endfunction

function! bbc#jira#search_async(jql, async)
    let path = '/search?fields=summary,project,issuetype,description,assignee,reporter,components&maxResults=1000&jql='.s:url_encode(a:jql)

    return bbc#jira#request(path, { 'async': a:async })
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
