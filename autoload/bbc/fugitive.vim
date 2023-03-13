if exists('g:autoloaded_bbc_fugtive')
    finish
endif
let g:autoloaded_bbc_fugitive = 1

function! bbc#fugitive#browse_handler(...) abort
    if a:0 == 1 || type(a:1) == type({})
        let opts = a:1
        let root = bbc#github#homepage_for_url(get(opts, 'remote', ''))
    else
        return ''
    endif

    if empty(root)
        return ''
    endif

    let path = substitute(opts.path, '^/', '', '')
    let ref = matchstr(opts.path, '^/\=\.git/\zsrefs/.*')
    if ref =~# '^refs/heads/'
        return root . '/commits/' . ref[11:-1]
    elseif ref =~# '^refs/tags/'
        return root . '/releases/tag/' . ref[10:-1]
    elseif ref =~# '^refs/remotes/[^/]\+/.'
        return root . '/commits/' . matchstr(ref,'remotes/[^/]\+/\zs.*')
    elseif opts.path =~# '^/\=\.git\>'
        return root
    endif

    let commit = opts.commit

    if get(opts, 'type', '') ==# 'tree' || opts.path =~# '/$'
        let url = substitute(root . '/tree/' . commit . '/' . path, '/$', '', 'g')
    elseif get(opts, 'type', '') ==# 'blob' || opts.path =~# '[^/]$'
        let escaped_commit = substitute(commit, '#', '%23', 'g')
        let url = root . '/blob/' . escaped_commit . '/' . path
        if get(opts, 'line2') > 0 && get(opts, 'line1') == opts.line2
            let url .= '#L' . opts.line1
        elseif get(opts, 'line1') > 0 && get(opts, 'line2') > 0
            let url .= '#L' . opts.line1 . '-L' . opts.line2
        endif
    else
        let url = root . '/commit/' . commit
    endif

    return url
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
