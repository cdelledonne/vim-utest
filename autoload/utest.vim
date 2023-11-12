" ==============================================================================
" Location:    autoload/utest.vim
" Description: API functions and global data for Vim-UTest
" ==============================================================================

let s:const = utest#const#Get()
let s:logger = utest#logger#Get()
let s:mock = utest#mock#Get()
let s:test = utest#test#Get()

" Print news of new Vim-UTest versions.
call utest#util#PrintNews(s:const.plugin_version, s:const.plugin_news)

" Log config options.
call s:logger.LogInfo('Configuration options:')
for s:cvar in sort(keys(s:const.config_vars))
    call s:logger.LogInfo('> g:%s: %s', s:cvar, string(g:[s:cvar]))
endfor

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General API functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Create new test fixture.
"
" Define Setup() and Teardown() methods on the returned fixture. Also use the
" fixture to store mock objects and runtime data. Pass fixture to
" utest#AddTest().
"
" Returns:
"     Dictionary
"         test fixture
"
function! utest#NewFixture() abort
    call s:logger.LogDebug('API invoked: utest#NewFixture()')
    return s:test.NewFixture()
endfunction

" Create new mock object.
"
" Mock objects represent dependencies of the component under test. Store the
" returned mock object into test fixture.
"
" Params:
"     functions : List
"         list of functions to mock, where each item is a dictionary consisting
"         of two entries: 'name' - the function's name, and 'ref' - a reference
"         to the function to be mocked (the 'ref' key is only necessary when the
"         function to be mocked is not a dict function)
"
" Returns:
"     Dictionary
"         mock object
"
function! utest#NewMock(functions) abort
    call s:logger.LogDebug('API invoked: utest#NewMock(%s)', a:functions)
    return s:mock.NewMock(a:functions)
endfunction

" Add function to list of tests.
"
" Params:
"     function : Funcref
"         function to be run as test
"     a:1 : Dictionary
"         optional test fixture
"
function! utest#AddTest(function, ...) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#AddTest(%s, %s)', a:function, a:000)
    if a:0 > 1
        call s:logger.EchoError(s:const.errors['TOO_MANY_ARGS'], 2)
        call s:logger.LogError(s:const.errors['TOO_MANY_ARGS'], 2)
    endif
    let l:fixture = exists('a:1') ? a:1 : v:null
    call s:test.AddTest(a:function, l:fixture)
endfunction

" API function for :UTest.
"
" Params:
"     a:000 : List
"         directory or file to scan for tests and additional command arguments
"
function! utest#Run(...) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#Run(%s)', a:000)
    if has('vim_starting')
        " If Vim-UTest was started from the command line, avoid causing errors,
        " otherwise the headless Vim/Neovim does not exit. Just echo error
        " messages if they occur.
        try
            let l:errors = s:test.RunTests(a:000)
        catch /.*/
            let l:errors = 1
            verbose echon v:throwpoint "\n" v:exception
        endtry
        " If Vim-UTest was started from the command line, exit.
        execute 'cquit ' . (l:errors > 0 ? 1 : 0)
    else
        call s:test.RunTests(a:000)
    endif
endfunction

" API function for completion for :UTest.
"
" Params:
"     arg_lead : String
"         the leading portion of the argument currently being completed
"     cmd_line : String
"         the entire command line
"     cursor_pos : Number
"         the cursor position in the command line (byte index)
"
" Returns:
"     String
"         available completion items, one per line
"
function! utest#Complete(arg_lead, cmd_line, cursor_pos) abort
    call s:logger.LogDebug('API invoked: utest#Complete()')
    return ''
    " TODO: return complete options
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Simple asserts
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Use AssertSomething() function to abort the test in case of failure, otherwise
" use the ExpectSomething() variants to continue the execution of the test also
" in case of failure.

function! utest#AssertTrue(condition) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#AssertTrue(%s)', a:condition)
    call s:test.AssertTrue(a:condition, v:true)
endfunction

function! utest#AssertFalse(condition) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#AssertFalse(%s)', a:condition)
    call s:test.AssertFalse(a:condition, v:true)
endfunction

function! utest#AssertEqual(lhs, rhs) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#AssertEqual(%s, %s)', a:lhs, a:rhs)
    call s:test.AssertEqual(a:lhs, a:rhs, v:true)
endfunction

function! utest#AssertNotEqual(lhs, rhs) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#AssertNotEqual(%s, %s)', a:lhs, a:rhs)
    call s:test.AssertNotEqual(a:lhs, a:rhs, v:true)
endfunction

function! utest#ExpectTrue(condition) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#ExpectTrue(%s)', a:condition)
    call s:test.AssertTrue(a:condition, v:false)
endfunction

function! utest#ExpectFalse(condition) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#ExpectFalse(%s)', a:condition)
    call s:test.AssertFalse(a:condition, v:false)
endfunction

function! utest#ExpectEqual(lhs, rhs) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#ExpectEqual(%s, %s)', a:lhs, a:rhs)
    call s:test.AssertEqual(a:lhs, a:rhs, v:false)
endfunction

function! utest#ExpectNotEqual(lhs, rhs) abort
    call s:logger.LogDebug(
        \ 'API invoked: utest#ExpectNotEqual(%s, %s)', a:lhs, a:rhs)
    call s:test.AssertNotEqual(a:lhs, a:rhs, v:false)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mock call expectations
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Expect future call to a mock function.
"
" Params:
"     mock : Dictionary
"         mock object, as returned by utest#NewMock()
"     function : String
"         function name, as passed to utest#NewMock()
"     a:1 : List
"         optional list of function arguments
"     a:2 : Any
"         optional return object
"
function! utest#ExpectCall(mock, function, ...) abort
    call s:logger.LogDebug('API invoked: utest#ExpectCall(%s, %s, %s)',
        \ a:mock, a:function, a:000)
    if a:0 > 2
        call s:logger.EchoError(s:const.errors['TOO_MANY_ARGS'], 4)
        call s:logger.LogError(s:const.errors['TOO_MANY_ARGS'], 4)
    endif
    let l:args = exists('a:1') ? a:1 : v:null
    let l:return = exists('a:2') ? a:2 : v:null
    call s:mock.ExpectCall(a:mock, a:function, l:args, l:return)
endfunction
