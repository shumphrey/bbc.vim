if exists('g:autoloaded_bbc')
    finish
endif
let g:autoloaded_bbc = 1

function! bbc#complete(findstart, base)
    return bbc#completions#completefunc(a:findstart, a:base)
endfunction
