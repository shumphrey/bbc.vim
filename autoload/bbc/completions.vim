" This file provides a function suitable for completefunc or omnifunc
"   set completefunc=bbc#completions#completefunc
"
" The functions in this file are subject to change and not suitable for external use.
if exists('g:autoloaded_bbc_completions')
    finish
endif
let g:autoloaded_bbc_completions = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:jira_map_project(key, value)
    let info = a:value.key . ' - ' . a:value.name
    if has_key(a:value, 'description') && !empty(a:value.description)
        let info .= "\n\n" . a:value.description
    endif
    return {
        \'word': a:value.key . '-',
        \'abbr': a:value.key,
        \'menu': a:value.name,
        \'info': info,
    \}
endfunction

function! s:jira_map_issue(index, value)
    let info = a:value.fields.summary
    let info .= "\n\n" . substitute(a:value.fields.description, '^\s*', '', '')
    let info = substitute(info, "\r", '', 'g')
    return {
        \'word': a:value.key,
        \'abbr': a:value.key,
        \'menu': a:value.fields.summary[0:70],
        \'info': info,
    \}
endfunction

function! s:jira_sort_issue(i1, i2) abort
    let one = split(a:i1.key, '-')
    let two = split(a:i2.key, '-')

    return str2nr(one[1]) >= str2nr(two[1]) ? -1 : 1
endfunction

function! s:jira_err_callback(channel, message)
    echoerr a:message
endfunction

" Cannot get complete_add to work inside an async job
" Looks like complete/complete_add isn't for asynchronous completion
" Despite :help complete-functions implying it can be
" Instead, the async job will add to a buffer variable, and the parent job
" can wait
function! s:jira_issue_search_out_callback(channel, message)
    let data = json_decode(a:message)
    if !has_key(data, 'issues')
        return
    endif
    for issue in data.issues
        call extend(b:completions, [s:jira_map_issue(0, issue)])
    endfor
endfunction

function! s:jira_project_search_out_callback(base, channel, message)
    let data = json_decode(a:message)
    if type(data) != type([])
        return
    endif

    let res = filter(data, 'v:val.key =~? "^' . a:base . '" || v:val.name =~? "^' . a:base . '"')
    let res = map(res, function('s:jira_map_project'))

    call extend(b:completions, res)
endfunction

function! s:exit_cb(name, job, status) abort
    unlet b:async_doing[a:name]
endfunction

function! s:fetch_jira_projects(base) abort
    return bbc#jira#projects_async(a:base, {
        \'err_cb': function('s:jira_err_callback'),
        \'out_cb': function('s:jira_project_search_out_callback', [a:base]),
        \'exit_cb': function('s:exit_cb', ['jira_projects']),
    \})
endfunction

function! s:fetch_jira_issues(base) abort
    let match = matchlist(a:base, '\(\w\{2,\}\)-\(\w*\)$')
    if empty(match)
        return
    endif

    let project = match[1]
    let search = match[2]
    let jql = 'statusCategory != done'
    if empty(search)
        let jql .= ' AND project=' . toupper(project)
    else
        let jql .= ' AND project=' . toupper(project) . ' AND text ~ ' . search
    endif

    return bbc#jira#search_async(jql, {
        \'err_cb': function('s:jira_err_callback'),
        \'out_cb': function('s:jira_issue_search_out_callback'),
        \'exit_cb': function('s:exit_cb', ['jira_issues']),
    \})
endfunction

function! s:split_remote() abort
    let homepage = rhubarb#HomepageForUrl(FugitiveRemoteUrl())
    let path = matchstr(homepage, '[^/]\+/[^/]\+$')
    return split(path, '/')
endfunction

function! s:github_map_collaborator(index, value) abort
    let node = get(a:value, 'node')
    let info = ''
    let name = get(node, 'name', '-')
    if empty(name)
        let name = '-'
    endif
    if has_key(node, 'bio') && !empty(node.bio)
        let info = name
        let bio = substitute(node.bio, '\. \s*', "\.\n", 'g')
        let bio = substitute(bio, "\r", '', 'g')
        let bio = trim(bio)
        let info .= "\n\n" . bio
        if has_key(node, 'location') && !empty(node.location)
            let info .= "\n\n" . node.location
        endif
    endif

    return {
        \'word': '@' . node.login,
        \'abbr': '@' . node.login,
        \'menu': name,
        \'info': info,
    \}
endfunction

" We almost certainly want people with write access to be top of the list
" People with write access should be higher up also
function! s:github_sort_collaborator(item1, item2) abort
    if a:item1.permission ==? 'ADMIN'
        return -1
    endif
    if a:item2.permission ==? 'ADMIN'
        return 1
    endif
    return 0
endfunction

function! s:github_collaborator_callback(base, response) abort
    let collabs = a:response.data.repository.collaborators.edges
    call sort(collabs, function('s:github_sort_collaborator'))
    let res = map(collabs, function('s:github_map_collaborator'))
    call extend(b:completions, res)
endfunction

function! s:fetch_github_users(base) abort
    let [org, repo] = s:split_remote()
    let query = substitute(a:base, '^@', '', '')

    return bbc#github#collaborators_async(org, repo, query, {
        \'out_cb': function('s:github_collaborator_callback', [a:base]),
        \'exit_cb': function('s:exit_cb', ['github_users']),
        \})
endfunction

function! s:github_map_issues(index, value) abort
    let info = substitute(a:value.body, "\r", '', 'g')
    let info = trim(info)

    return {
        \'word': '#' . a:value.number,
        \'abbr': '#' . a:value.number,
        \'menu': a:value.title,
        \'info': info,
    \}
endfunction

function! s:github_issue_callback(base, response) abort
    let nodes = a:response.data.search.nodes
    let res = filter(nodes, 'has_key(v:val, "title")')
    let res = map(res, function('s:github_map_issues'))
    call extend(b:completions, res)
endfunction

function! s:fetch_github_issues(base) abort
    let [org, repo] = s:split_remote()
    let query = substitute(a:base, '^#', '', '')

    return bbc#github#search_issues_async(org, repo, query, {
        \'out_cb': function('s:github_issue_callback', [a:base]),
        \'exit_cb': function('s:exit_cb', ['github_issues']),
        \})
endfunction

" Relies on junegunn/emojis
function! s:fetch_emojis(base) abort
    try
        return emoji#complete(0, a:base)
    endtry
endfunction


function! s:find_start(findstart, base) abort
    let line = getline('.')[0:col('.')-1]

    " A Jira project is always at least 2 characters of upper case letters
    " followed by a hyphen, followed by numbers
    " [A-Z]{2,}-\d+
    " To omnicomplete Jira issues, the full project name must be provided
    " with a hyphen, but case won't matter.
    " The second term after the hyphen will be a search term to provide to
    " Jira /search API
    let existing = matchstr(line, '[a-zA-Z]\{2,\}-\w*$')

    " If it starts with an @, we want to complete GitHub users
    if empty(existing)
        let existing = matchstr(line, '@\w*$')
    endif

    " If it starts with a #, we want to complete GitHub issues
    if empty(existing)
        let existing = matchstr(line, '#\w*$')
    endif

    " If it starts with a :, we want to complete emojis
    " Requires junegunn/vim-emoji
    if empty(existing)
        let existing = matchstr(line, ':\w*$')
    endif

    " Otherwise, we want to complete Jira projects or GitHub issues.
    " Jira projects should appear first.
    if empty(existing)
        let existing = matchstr(line, '\w*$')
    endif

    return col('.') - 1 - strlen(existing)
endfunction

function! s:wait_for_jobs(jobs) abort
    if empty(a:jobs)
        return
    endif
    while v:true
        let still_running = v:true
        for job in a:jobs
            let status = job_status(job)
            if status !=# 'run'
                let still_running = v:false
            endif
        endfor
        if !still_running
            break
        endif
        sleep 1m
    endwhile
endfunction

" Completions - completefunc (ctrl-x ctrl-u)
" Asynchronously complete
"   \w{2,}-\w*             - A Jira project and search term
"   @\w                    - A GitHub user who has access to this project
"   #\w+                   - A GitHub issue
"   \w{2,}                 - A Jira Project or GitHub issue
function! bbc#completions#completefunc(findstart, base) abort
    if a:findstart
        return s:find_start(a:findstart, a:base)
    endif

    let async_jobs = []
    let completions = []
    let b:completions = []
    let b:async_doing = {}

    if a:base =~? '^\w\{2,\}-'
        let b:async_doing.jira_issues = v:true
        call extend(async_jobs, [s:fetch_jira_issues(a:base)])
    elseif a:base =~? '^@'
        let b:async_doing.github_users = v:true
        call extend(async_jobs, [s:fetch_github_users(a:base)])
    elseif a:base =~? '^#'
        let b:async_doing.github_issues = v:true
        call extend(async_jobs, [s:fetch_github_issues(a:base)])
    elseif a:base =~? '^:'
        call extend(completions, s:fetch_emojis(a:base))
    elseif len(a:base) > 1
        let b:async_doing.jira_projects = v:true
        let b:async_doing.github_issues = v:true
        call extend(async_jobs, [s:fetch_jira_projects(a:base)])
        call extend(async_jobs, [s:fetch_github_issues(a:base)])
    endif

    call s:wait_for_jobs(async_jobs)
    let i=0
    while i < 500
        if empty(b:async_doing)
            break
        endif
        sleep 1m
        let i = i + 1
    endwhile
    call extend(completions, b:completions)

    return completions
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
