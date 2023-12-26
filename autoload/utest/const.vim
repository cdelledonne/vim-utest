" ==============================================================================
" Location:    autoload/utest/const.vim
" Description: Constants and definitions
" ==============================================================================

let s:const = {}

let s:const.plugin_name = 'utest'
let s:const.plugin_version = '0.1.1'

let s:const.echo_prefix = '[Vim-UTest] '

let s:const.plugin_news = {}

let s:const.errors = {
    \ 'TOO_MANY_ARGS':
    \     'Too many arguments. Maximum is %d',
    \ 'TEST_DOES_NOT_EXIST':
    \     'Test with function %s does not exist',
    \ 'NO_SUCH_PATH':
    \     'Path %s is invalid, no such file or directory exist',
    \ 'NO_TEST_UNDER_CURSOR':
    \     'No test under cursor',
    \ 'CANT_USE_CURSOR_IN_HEADLESS':
    \     'Cannot use ''--cursor'' in headless/silent mode',
    \ 'UNEXPECTED_PATH_ARG':
    \     'Path argument not expected when ''--cursor'' is used',
    \ 'CONFLICTING_ARGS':
    \     'Cannot use both arguments %s and %s',
    \ 'COMMAND_RUNNING':
    \     'Another UTest command is already running',
    \ }

let s:const.config_vars = {}
let s:const.config_vars.utest_default_test_dir    = 'test'
let s:const.config_vars.utest_window_size         = 15
let s:const.config_vars.utest_window_position     = 'botright'
let s:const.config_vars.utest_focus               = v:false
let s:const.config_vars.utest_focus_on_completion = v:false
let s:const.config_vars.utest_focus_on_error      = v:true
let s:const.config_vars.utest_log_file            = ''
let s:const.config_vars.utest_log_level           = 'INFO'

" Get const 'object'.
"
function! utest#const#Get() abort
    return s:const
endfunction
