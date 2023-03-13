" At time of writing, rhubarb's completion of users doesn't work well for
" the BBC.
" The GitHub v3 API for collaborators doesn't support search and returns
" *everyone* with at least read access to the repository.
" For an organisation as large as the BBC, this doesn't produce usable
" results.
" Therefore bbc.vim does its own integration with the GitHub API
" It uses the v4 graphql api which can at least use a search parameter
" To further help the results, we push ADMINs to the top

if exists('g:autoloaded_bbc_github_api')
    finish
endif
let g:autoloaded_bbc_github_api = 1

" concat the buffer lines together
function! s:JobNvimCallback(lines, job, data, type) abort
    let a:lines[-1] .= remove(a:data, 0)
    call extend(a:lines, a:data)
endfunction

function! s:graphql_out_callback(cb, message) abort
    let data = json_decode(a:message)
    if has_key(data, 'errors')
        if type(data.errors) ==# type([])
            for error in data.errors
                echoerr error.message
            endfor
        else
            echoerr data.errors
        endif
        return
    endif
    call a:cb(data)
endfunction

function! bbc#github#request(query, variables, options) abort
    let url = 'https://api.github.com/graphql'

    if !executable('curl')
        call bbc#utils#throw('curl is required for GitHub API')
    endif
    if !has_key(a:options, 'cb') || type(a:options.cb) != type(function('tr'))
        call bbc#utils#throw('Need options.out_cb')
    endif

    let payload = json_encode({
        \'query': a:query,
        \'variables': a:variables,
        \})

    let tmpfile = tempname()
    call writefile([payload], tmpfile)

    let data = ['-sS', '--netrc', '-A', 'bbc/vim', '-X', 'POST', '--data', '@'.tmpfile, url]
    let cmd = extend(['curl'], data)

    if has('nvim')
        let lines = ['']
        let jopts = {
          \ 'on_stdout': function('s:JobNvimCallback', [lines]),
          \ 'on_stderr': function('s:JobNvimCallback', [lines]),
          \ 'on_exit': { j, code, _ -> s:graphql_out_callback(a:options.cb, join(lines, '')) }}

        return jobstart(cmd, jopts)
    endif
    let lines = ['']
    return job_start(cmd, {
        \'out_cb': { j, str -> add(lines, str) },
        \'err_cb': { j, str -> add(lines, str) },
        \'exit_cb': { j, code -> s:graphql_out_callback(a:options.cb, join(lines, '')) }})
endfunction

function! bbc#github#collaborators_async(owner, repo, query, options) abort
    let query = 'query RepoCollaborators($owner: String!, $repo: String!, $query: String!) { repository(owner: $owner, name: $repo) { collaborators(first: 100, query: $query) { edges { node { login,name,bio,location }, permission } } } }'
    let variables = { 'owner': a:owner, 'repo': a:repo, 'query': a:query }

    return bbc#github#request(query, variables, a:options)
endfunction

function! bbc#github#search_issues_async(owner, repo, query, options) abort
    let nodes = 'nodes { ... on Issue { body, title, number } ... on PullRequest { body, title, number } }'
    let query = 'query IssueSearch($search: String!) { search(first: 100, query: $search, type: ISSUE) { ' . nodes . ' } }'
    let variables = { 'search': 'repo:'.a:owner .'/'.a:repo .' is:open in:title ' . a:query }
    return bbc#github#request(query, variables, a:options)
endfunction


function! bbc#github#homepage_for_url(url) abort
    " [full_url, scheme, host_with_port, host, path]
    if a:url =~# '://'
        let match = matchlist(a:url, '^\(https\=://\|git://\|ssh://\)\%([^@/]\+@\)\=\(\([^/:]\+\)\%(:\d\+\)\=\)/\(.\{-\}\)\%(\.git\)\=/\=$')
    else
        let match = matchlist(a:url, '^\([^@/]\+@\)\=\(\([^:/]\+\)\):\(.\{-\}\)\%(\.git\)\=/\=$')
        if !empty(match)
            let match[1] = 'ssh://'
        endif
    endif

    if empty(match)
        return ''
    elseif match[3] ==# 'github.com' || match[3] ==# 'ssh.github.com'
        return 'https://github.com/' . match[4]
    else
        return ''
    endif
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
