" ==============================================================================
" File:        utest.vim
" Description: Vim-UTest, Vimscript unit testing plugin with mocking support
" Maintainer:  Carlo Delle Donne <https://github.com/cdelledonne>
" Version:     0.1.1
" License:     MIT
" ==============================================================================

if exists('g:loaded_utest') && g:loaded_utest
    finish
endif
let g:loaded_utest = 1

" Assign user/default values to coniguration variables.
" NOTE: must be done before loading other scripts.
let s:const = utest#const#Get()
for s:cvar in items(s:const.config_vars)
    if !has_key(g:, s:cvar[0])
        let g:[s:cvar[0]] = s:cvar[1]
    endif
endfor

" Configure logger.
let s:logger = libs#logger#Get(
    \ s:const.plugin_name,
    \ s:const.echo_prefix,
    \ g:utest_log_file,
    \ g:utest_log_level
    \ )

" Configure error reporter.
let s:error = libs#error#Get(s:const.plugin_name, s:logger)
call s:error.ExtendDatabase(s:const.errors)

call s:logger.LogInfo('Loading Vim-UTest')

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

command -nargs=* -complete=custom,utest#Complete UTest call utest#Run(<f-args>)

call s:logger.LogInfo('Commands defined')

call s:logger.LogInfo('Vim-UTest loaded')
