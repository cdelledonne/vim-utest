" ==============================================================================
" Location:    autoload/utest/report.vim
" Description: Report test results
" ==============================================================================

let s:report = {}
let s:report.buffer = -1

let s:buffer_options = {
    \ 'bufhidden': 'hide',
    \ 'buflisted': v:false,
    \ 'buftype': 'nofile',
    \ 'modifiable': v:false,
    \ 'swapfile': v:false,
    \ 'filetype': 'utest',
    \ }

let s:window_options = {
    \ 'number': v:false,
    \ 'relativenumber': v:false,
    \ 'signcolumn': 'auto',
    \ }

let s:const = utest#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:system = libs#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:report._Report(msg, ...) abort
    if s:system.VimIsStarting()
        call call(funcref('s:logger.Echo'), [a:msg] + a:000, s:logger)
    else
        let line = call('printf', [a:msg] + a:000)
        let mod = s:system.BufferGetOption(self.buffer, 'modifiable')
        call s:system.BufferSetOptions(self.buffer, {'modifiable': v:true})
        call s:system.BufferAppendLines(self.buffer, [line])
        call s:system.BufferSetOptions(self.buffer, {'modifiable': mod})
    endif
endfunction

function! s:report._OpenWindow() abort
    " If a Vim-UTest window does not exist, create it.
    if s:system.BufferGetWindowID(self.buffer) != -1
        let utest_win_id = s:system.BufferGetWindowID(self.buffer)
    else
        let utest_win_id = s:system.WindowCreate(
            \ g:utest_window_position,
            \ g:utest_window_size,
            \ ['winfixheight', 'winfixwidth']
            \ )
        call s:logger.LogDebug('Created window')
    endif
    " Create a new buffer if none exist.
    if self.buffer == -1
        let Function = funcref('s:system.BufferCreate', [v:false], s:system)
        let ids = s:system.WindowRun(utest_win_id, Function)
        let self.buffer = ids['buffer_id']
        call s:system.BufferSetOptions(self.buffer, s:buffer_options)
        call s:system.WindowSetOptions(utest_win_id, s:window_options)
        call s:logger.LogDebug('Created buffer')
    endif
    " Show buffer.
    call s:system.WindowSetBuffer(utest_win_id, self.buffer)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Reset report subsystem and open report buffer (only when running from within
" Vim/Neovim, not in headless or silent mode).
"
function! s:report.Reset() abort
    call s:logger.LogDebug('Invoked: report.Reset()')
    if !s:system.VimIsStarting()
        call self._OpenWindow()
        let mod = s:system.BufferGetOption(self.buffer, 'modifiable')
        call s:system.BufferSetOptions(self.buffer, {'modifiable': v:true})
        call s:system.BufferClear(self.buffer)
        call s:system.BufferSetOptions(self.buffer, {'modifiable': mod})
    endif
endfunction

" Focus the window with the report buffer (only when running from within
" Vim/Neovim, not in headless or silent mode).
"
function! s:report.Focus() abort
    call s:logger.LogDebug('Invoked: report.Focus()')
    if s:system.BufferExists(self.buffer)
        call s:system.WindowGoToID(s:system.BufferGetWindowID(self.buffer))
    endif
endfunction

" Report a general information message - on the stdout when running in headless
" or silent mode, otherwise in the report buffer.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:report.ReportInfo(fmt, ...) abort
    call call(funcref('self._Report'), ['[=========] ' . a:fmt] + a:000, self)
endfunction

" Report an information message related to a specific test - on the stdout when
" running in headless or silent mode, otherwise in the report buffer.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:report.ReportTestInfo(fmt, ...) abort
    call call(funcref('self._Report'), ['[ - - - - ] ' . a:fmt] + a:000, self)
endfunction

" Report a warning message related to a specific test - on the stdout when
" running in headless or silent mode, otherwise in the report buffer.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:report.ReportTestWarn(fmt, ...) abort
    call call(funcref('self._Report'), ['[ ~ ~ ~ ~ ] ' . a:fmt] + a:000, self)
endfunction

" Report an error message related to a specific test - on the stdout when
" running in headless or silent mode, otherwise in the report buffer.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:report.ReportTestError(fmt, ...) abort
    call call(funcref('self._Report'), ['[ X X X X ] ' . a:fmt] + a:000, self)
endfunction

" Get report 'object'.
"
function! utest#report#Get() abort
    return s:report
endfunction
