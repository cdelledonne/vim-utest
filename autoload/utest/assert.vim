" ==============================================================================
" Location:    autoload/utest/assert.vim
" Description: Assert and expect functions
" ==============================================================================

let s:assert = {}
let s:assert.current_test = v:null

let s:system = libs#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:AssertTrue(condition, error_msg, test, abort) abort
    if a:condition
        return v:null
    endif
    call remove(v:errors, -1)
    " Error point is fifth-to-last function in stack trace and the assert API is
    " the fourth-to-last.
    let stack = s:system.GetStackTrace()
    let error_point = stack[-5]
    let assert_api = stack[-4]
    " Extract line number of assert API call, relative to function start.
    let relative_error_lnum = matchlist(
        \ error_point,
        \ '\m\C\(<SNR>\d\+_\)\?.*\[\(\d\+\)\]'
        \ )[2]
    " Extract name of assert API call.
    let error_func_name = matchlist(
        \ assert_api,
        \ '\m\Cutest#\(.*\)\[\d\+\]'
        \ )[1]
    " Extract line number where the function that asserted was called.
    if a:test.setup_running
        let func_lnum = a:test.setup_lnum
    elseif a:test.teardown_running
        let func_lnum = a:test.teardown_lnum
    else
        let func_lnum = a:test.func_lnum
    endif
    let error_lnum = func_lnum + str2nr(relative_error_lnum)
    " Add error to list of errors to be reported.
    let error_msg = printf('%s (%s)', a:error_msg, error_func_name)
    call add(a:test.errors, {'msg': error_msg, 'lnum': error_lnum})
    if a:abort
        throw 'vim-utest-assert'
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:assert.SetCurrentTest(test) abort
    let self.current_test = a:test
endfunction

" Assert that a condition is true.
"
function! s:assert.AssertTrue(condition, abort) abort
    call s:AssertTrue(
        \ assert_true(a:condition) == 0,
        \ printf('Condition is not true'),
        \ self.current_test,
        \ a:abort
        \ )
endfunction

" Assert that a condition is false.
"
function! s:assert.AssertFalse(condition, abort) abort
    call s:AssertTrue(
        \ assert_false(a:condition) == 0,
        \ printf('Condition is not false'),
        \ self.current_test,
        \ a:abort,
        \ )
endfunction

" Assert that two values are equal.
"
function! s:assert.AssertEqual(lhs, rhs, abort) abort
    call s:AssertTrue(
        \ assert_equal(a:lhs, a:rhs) == 0,
        \ printf('%s and %s are not equal', string(a:lhs), string(a:rhs)),
        \ self.current_test,
        \ a:abort,
        \ )
endfunction

" Assert that two values are not equal.
"
function! s:assert.AssertNotEqual(lhs, rhs, abort) abort
    call s:AssertTrue(
        \ assert_notequal(a:lhs, a:rhs) == 0,
        \ printf('%s and %s are equal', string(a:lhs), string(a:rhs)),
        \ self.current_test,
        \ a:abort,
        \ )
endfunction

" Assert that a value is in a certain range of values, inclusive.
"
function! s:assert.AssertInRange(lower, upper, expr, abort) abort
    call s:AssertTrue(
        \ assert_inrange(a:lower, a:upper, a:expr) == 0,
        \ printf('%s is not in range [%s, %s]',
        \     string(a:expr), string(a:lower), string(a:upper)),
        \ self.current_test,
        \ a:abort,
        \ )
endfunction

" Assert that a pattern matches a value.
"
function! s:assert.AssertMatch(pattern, expr, abort) abort
    call s:AssertTrue(
        \ assert_match(a:pattern, a:expr) == 0,
        \ printf('Pattern %s does not match %s',
        \     string(a:pattern), string(a:expr)),
        \ self.current_test,
        \ a:abort,
        \ )
endfunction

" Assert that a pattern does not match a value.
"
function! s:assert.AssertNoMatch(pattern, expr, abort) abort
    call s:AssertTrue(
        \ assert_notmatch(a:pattern, a:expr) == 0,
        \ printf('Pattern %s matches %s', string(a:pattern), string(a:expr)),
        \ self.current_test,
        \ a:abort,
        \ )
endfunction

" Expect future call to a mock function.
"
" Params:
"     mock : Dictionary
"         mock object
"     funcname : String
"         function name
"     args : List
"         list of function arguments
"     return : Any
"         return object
"
function! s:assert.ExpectCall(mock, funcname, args, return) abort
endfunction

" Get assert 'object'.
"
function! utest#assert#Get() abort
    return s:assert
endfunction
