" ==============================================================================
" Location:    autoload/utest.vim
" Description: API functions and global data for Vim-UTest
" ==============================================================================

let s:assert = utest#assert#Get()
let s:const = utest#const#Get()
let s:system = libs#system#Get()
let s:test = utest#test#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:error = libs#error#Get(s:const.plugin_name, s:logger)

" Print news of new Vim-UTest versions.
let s:news_items = libs#util#FilterNews(
    \ s:const.plugin_name, s:const.plugin_version, s:const.plugin_news)
for s:news_item in s:news_items
    call s:logger.EchoInfo(s:news_item)
endfor

" Log config options.
call s:logger.LogInfo('Configuration options:')
for s:cvar in sort(keys(s:const.config_vars))
    call s:logger.LogInfo('> g:%s: %s', s:cvar, string(g:[s:cvar]))
endfor

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General API functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Create new test fixture object.
"
" Define test functions on the returned fixture. Also define SetUp() and
" TearDown() methods on the returned fixture. Also use the fixture to store mock
" objects and runtime data.
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
    return s:test.NewMock(a:functions)
endfunction

" API function for :UTest.
"
" Params:
"     a:000 : List
"         directory or file to scan for tests and additional command arguments
"
function! utest#Run(...) abort
    call s:logger.LogDebug('API invoked: utest#Run(%s)', a:000)
    let num_failed_tests = s:test.RunTests(a:000)
    " If Vim-UTest was started from the command line, exit.
    if s:system.VimIsStarting()
        execute 'cquit ' . (num_failed_tests > 0 ? 1 : 0)
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


" API function to query information about Vim-UTest.
"
" Returns:
"     Dictionary
"         version : String
"             Vim-CMake version
"
function! utest#GetInfo() abort
    let l:info = {}
    let l:info.version = s:const.plugin_version
    return l:info
endfunction
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Simple asserts
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Use AssertSomething() function to abort the test in case of failure, otherwise
" use the ExpectSomething() variants to continue the execution of the test also
" in case of failure.

function! utest#AssertTrue(condition) abort
    call s:logger.LogDebug('API invoked: utest#AssertTrue(%s)', a:condition)
    call s:assert.AssertTrue(a:condition, v:true)
endfunction

function! utest#AssertFalse(condition) abort
    call s:logger.LogDebug('API invoked: utest#AssertFalse(%s)', a:condition)
    call s:assert.AssertFalse(a:condition, v:true)
endfunction

function! utest#AssertEqual(lhs, rhs) abort
    call s:logger.LogDebug('API invoked: utest#AssertEqual(%s, %s)',
        \ a:lhs, a:rhs)
    call s:assert.AssertEqual(a:lhs, a:rhs, v:true)
endfunction

function! utest#AssertNotEqual(lhs, rhs) abort
    call s:logger.LogDebug('API invoked: utest#AssertNotEqual(%s, %s)',
        \ a:lhs, a:rhs)
    call s:assert.AssertNotEqual(a:lhs, a:rhs, v:true)
endfunction

function! utest#AssertInRange(lower, upper, expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertInRange(%s, %s, %s)',
        \ a:lower, a:upper, a:expr)
    call s:assert.AssertInRange(a:lower, a:upper, a:expr, v:true)
endfunction

function! utest#AssertMatch(pattern, expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertMatch(%s, %s)',
        \ a:pattern, a:expr)
    call s:assert.AssertMatch(a:pattern, a:expr, v:true)
endfunction

function! utest#AssertNoMatch(pattern, expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertNoMatch(%s, %s)',
        \ a:pattern, a:expr)
    call s:assert.AssertNoMatch(a:pattern, a:expr, v:true)
endfunction

function! utest#ExpectTrue(condition) abort
    call s:logger.LogDebug('API invoked: utest#ExpectTrue(%s)', a:condition)
    call s:assert.AssertTrue(a:condition, v:false)
endfunction

function! utest#ExpectFalse(condition) abort
    call s:logger.LogDebug('API invoked: utest#ExpectFalse(%s)', a:condition)
    call s:assert.AssertFalse(a:condition, v:false)
endfunction

function! utest#ExpectEqual(lhs, rhs) abort
    call s:logger.LogDebug('API invoked: utest#ExpectEqual(%s, %s)',
        \ a:lhs, a:rhs)
    call s:assert.AssertEqual(a:lhs, a:rhs, v:false)
endfunction

function! utest#ExpectNotEqual(lhs, rhs) abort
    call s:logger.LogDebug('API invoked: utest#ExpectNotEqual(%s, %s)',
        \ a:lhs, a:rhs)
    call s:assert.AssertNotEqual(a:lhs, a:rhs, v:false)
endfunction

function! utest#ExpectInRange(lower, upper, expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectInRange(%s, %s, %s)',
        \ a:lower, a:upper, a:expr)
    call s:assert.AssertInRange(a:lower, a:upper, a:expr, v:false)
endfunction

function! utest#ExpectMatch(pattern, expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectMatch(%s, %s)',
        \ a:pattern, a:expr)
    call s:assert.AssertMatch(a:pattern, a:expr, v:false)
endfunction

function! utest#ExpectNoMatch(pattern, expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectNoMatch(%s, %s)',
        \ a:pattern, a:expr)
    call s:assert.AssertNoMatch(a:pattern, a:expr, v:false)
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
        call s:error.Throw('TOO_MANY_ARGS', 4)
    endif
    let args = exists('a:1') ? a:1 : v:null
    let return = exists('a:2') ? a:2 : v:null
    call s:assert.ExpectCall(a:mock, a:function, args, return)
endfunction
