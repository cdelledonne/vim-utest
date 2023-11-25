" ==============================================================================
" Location:    autoload/utest/mock.vim
" Description: Mock class
" ==============================================================================

let s:id = 0

let s:mock = {}
let s:mock.expected_calls = []
let s:mock.autoload_funcs = []
let s:mock.current_test = v:null

let s:const = utest#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:report = utest#report#Get()
let s:system = libs#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:mock._MockFunction(funcname, ...) abort
    call s:logger.LogDebug(
        \ 'Invoked: mock._MockFunction(%s) (mock ID: %d)',
        \ a:funcname, self.id,
        \ )
    " If a call to this function matches the first entry in the list of
    " expected calls (same name, same args), remove entry from list and return
    " desired value.
    if len(self.expected_calls) > 0
        let call = self.expected_calls[0]
        if call.funcname ==# a:funcname &&
            \ (call.args is v:null || call.args == a:000)
            call remove(self.expected_calls, 0)
            return call.return
        endif
    endif
    " Otherwise, report a warning. Note that a call that matches an expected
    " call's name but does not have the expected args is considered missed.
    " Warning point is fourth function in the stack trace.
    let warn_point = s:system.GetStackTrace()[3]
    let relative_warn_lnum = matchlist(
        \ warn_point,
        \ '\m\C.*\[\(\d\+\)\]'
        \ )[1]
    " Extract line number and file name where the function (within a test) that
    " caused the missed call was invoked.
    if self.current_test.setup_running
        let func_lnum = self.current_test.setup_lnum
    elseif self.current_test.teardown_running
        let func_lnum = self.current_test.teardown_lnum
    else
        let func_lnum = self.current_test.start_lnum
    endif
    let warn_lnum = func_lnum + str2nr(relative_warn_lnum)
    let test_file = s:system.Path(self.current_test.file, v:true)
    " Report warning.
    let fmt = '%s:%d: Warning: Unexpected call to function ''%s(%s)'''
    let unpacked_args = string(a:000)[1:-2]
    let warn_args = [fmt, test_file, warn_lnum, a:funcname, unpacked_args]
    call call(funcref('s:report.ReportTestWarn'), warn_args, s:report)
    call call(funcref('s:logger.LogDebug'), warn_args, s:logger)
    return v:null
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
"
" Note: This are public functions, but their names start with an underscore to
" avoid naming conflicts with function names defined by the user.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:mock._SetCurrentTest(test) abort
    let self.current_test = a:test
endfunction

" Redefine mock's autoload functions to point to mock function. This is only
" successful after the actual autoload functions have been defined, that is,
" after the file that defines these functions has been sourced.
"
function! s:mock._RedefAutoloadFuncs() abort
    call s:logger.LogDebug(
        \ 'Invoked: mock._RedefAutoloadFuncs() (mock ID: %d)', self.id)
    for autoload_func in self.autoload_funcs
        " We only try to redefine an autoload function if it already exists and
        " if it hasn't been redefined already.
        if !exists('*' . autoload_func.funcname) || autoload_func.defined
            continue
        endif
        " This is somewhat ugly, but it's the only thing that works. Just
        " assigning a Funcref to the function's name does not work.
        call execute([
            \ printf('function! %s(...) abort closure', autoload_func.funcname),
            \ printf(
            \     'return call(self._MockFunction, [%s] + a:000)',
            \     string(autoload_func.funcname)
            \     ),
            \ 'endfunction',
            \ ])
        call s:logger.LogDebug(
            \ 'Redefined function %s (mock ID: %d)',
            \ string(autoload_func.funcname), self.id
            \ )
        let autoload_func.defined = v:true
    endfor
endfunction

" Expect future call to a mock function.
"
" Params:
"     funcname : String
"         function name, as passed to utest#NewMock()
"     args : List
"         list of function arguments or v:null - passing an empty list means the
"         function is expected to be called with no arguments, whilst passing
"         v:null means that the function is expected to be called with any
"         number of arguments
"     return : Any
"         object to be returned from the call to the mock function
"
function! s:mock._AddExpectedCall(funcname, args, return) abort
    call s:logger.LogDebug(
        \ 'Invoked: mock._AddExpectedCall(%s, %s, %s) (mock ID: %d)',
        \ a:funcname, a:args, a:return, self.id
        \ )
    " Expectation point is fourth-to-last in stack trace.
    let stack = s:system.GetStackTrace()
    let expectation_point = stack[-4]
    " Extract line number of expectation API call, relative to function start.
    let relative_expectation_lnum = matchlist(
        \ expectation_point,
        \ '\m\C.*\[\(\d\+\)\]'
        \ )[1]
    " Add expected call.
    let call = {
        \ 'funcname': a:funcname,
        \ 'args': a:args,
        \ 'return': a:return,
        \ 'relative_expectation_lnum': relative_expectation_lnum,
        \ }
    call add(self.expected_calls, call)
endfunction

" Get mock object's expected calls.
"
" Returns:
"     List
"         expected calls, a list of dictionaries of the following form:
"             funcname : String
"                 function name, as passed to _AddExpectCall()
"             args : List
"                 list of function arguments, as passed to _AddExpectCall()
"             return : Any
"                 object to be returned, as passed to _AddExpectCall()
"
function! s:mock._GetExpectedCalls() abort
    call s:logger.LogDebug(
        \ 'Invoked: mock._GetExpectedCalls() (mock ID: %d)', self.id)
    return self.expected_calls
endfunction

" Reset mock object's expectations.
"
function! s:mock._Reset() abort
    call s:logger.LogDebug('Invoked: mock._Reset() (mock ID: %d)', self.id)
    let self.expected_calls = []
endfunction

" Create new mock object. Mock objects represent dependencies of the component
" under test.
"
" Params:
"     functions : List
"         list of function names to mock, each item can be either an autoload
"         function (like 'plugin#component#SomeFunc') or a dictionary function
"         (like 'SomeFunc') - these function names can then be passed to
"         utest#ExpectCall()
"
" Returns:
"     Dictionary
"         mock object
"
" Notes:
"     - Function names that contain a '#' character are assumed to be autoload
"       functions, whilst those that do not contain any '#' character are
"       assumed to be dictionary functions
"     - When the function to be mocked is a dictionary function of the
"       component, like component.SomeFunc(), the name in the list of functions
"       must just be the name of the dictionary key, in this example 'SomeFunc'
"
function! utest#mock#New(functions) abort
    call s:logger.LogDebug('Invoked: utest#mock#New()')
    let mock = deepcopy(s:mock)
    for funcname in a:functions
        " Functions that contain at least a '#' character are assumed to be
        " autoload functions.
        if match(funcname, '#') != -1
            " Mock autoload functions can only be redefined after the actual
            " autoload function as been loaded, so we store the name of these
            " and redefine the functions in _RedefAutoloadFuncs().
            let autoload_func = {'funcname': funcname, 'defined': v:false}
            call add(mock.autoload_funcs, autoload_func)
        else
            " Mock dictionary functions are immediately defined instead.
            let mock[funcname] = funcref('mock._MockFunction', [funcname], mock)
        endif
    endfor
    let mock.id = s:id
    let s:id += 1
    return mock
endfunction
