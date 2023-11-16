" ==============================================================================
" Location:    autoload/utest/mock.vim
" Description: Mocking support
" ==============================================================================

let s:mock = {}

let s:const = utest#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get mock 'object'.
"
function! utest#mock#Get() abort
    return s:mock
endfunction
