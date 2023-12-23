" ==============================================================================
" Location:    autoload/utest.vim
" Description: API functions and global data for Vim-UTest
" ==============================================================================

let s:assert = utest#assert#Get()
let s:const = utest#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:error = libs#error#Get(s:const.plugin_name, s:logger)
let s:system = libs#system#Get()
let s:runner = utest#runner#Get()

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
" TearDown() methods on the returned fixture. Also use the fixture to store
" runtime data.
"
" Returns:
"     Dictionary
"         test fixture
"
function! utest#NewFixture() abort
    call s:logger.LogDebug('API invoked: utest#NewFixture()')
    return s:runner.NewFixture()
endfunction

" Create new mock object. Mock objects represent dependencies of the component
" under test.
"
" Params:
"     fixture : Dictionary
"         fixture object, as returned by utest#NewFixture()
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
function! utest#NewMock(fixture, functions) abort
    call s:logger.LogDebug('API invoked: utest#NewMock(%s)', a:functions)
    return s:runner.NewMock(a:fixture, a:functions)
endfunction

" Define new mock constructor function.
"
" Params:
"     mock : Dictionary
"         mock object, as returned by utest#NewMock()
"     function : String
"         name of constructor function to mock (an autoload function)
"
function! utest#NewMockConstructor(mock, function) abort
    call s:logger.LogDebug('API invoked: utest#NewMockConstructor(%s, %s)',
        \ a:mock.id, a:function)
    return s:runner.NewMockConstructor(a:mock, a:function)
endfunction

" API function for :UTest.
"
" Params:
"     a:000 : List
"         directory or file to scan for tests and additional command arguments
"
function! utest#Run(...) abort
    call s:logger.LogDebug('API invoked: utest#Run(%s)', a:000)
    let num_failed_tests = s:runner.RunTests(a:000)
    " If Vim-UTest was started from the command line, exit.
    if s:system.VimIsStarting()
        execute 'cquit ' . (num_failed_tests > 0 ? 1 : 0)
    endif
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

" Use AssertSomething() function to stop the test in case of failure, otherwise
" use the ExpectSomething() variants to continue the execution of the test also
" in case of failure.

function! utest#AssertTrue(expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertTrue(%s)', a:expr)
    call s:assert.AssertTrue(a:expr, v:true)
endfunction

function! utest#AssertFalse(expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertFalse(%s)', a:expr)
    call s:assert.AssertFalse(a:expr, v:true)
endfunction

function! utest#AssertEqual(value, expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertEqual(%s, %s)',
        \ a:value, a:expr)
    call s:assert.AssertEqual(a:value, a:expr, v:true)
endfunction

function! utest#AssertNotEqual(value, expr) abort
    call s:logger.LogDebug('API invoked: utest#AssertNotEqual(%s, %s)',
        \ a:value, a:expr)
    call s:assert.AssertNotEqual(a:value, a:expr, v:true)
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

function! utest#ExpectTrue(expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectTrue(%s)', a:expr)
    call s:assert.AssertTrue(a:expr, v:false)
endfunction

function! utest#ExpectFalse(expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectFalse(%s)', a:expr)
    call s:assert.AssertFalse(a:expr, v:false)
endfunction

function! utest#ExpectEqual(value, expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectEqual(%s, %s)',
        \ a:value, a:expr)
    call s:assert.AssertEqual(a:value, a:expr, v:false)
endfunction

function! utest#ExpectNotEqual(value, expr) abort
    call s:logger.LogDebug('API invoked: utest#ExpectNotEqual(%s, %s)',
        \ a:value, a:expr)
    call s:assert.AssertNotEqual(a:value, a:expr, v:false)
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
"     args : List
"         list of function arguments or v:null - passing an empty list means the
"         function is expected to be called with no arguments, whilst passing
"         v:null means that the function is expected to be called with any
"         number of arguments
"     a:2 : Any
"         optional return object
"
function! utest#ExpectCall(mock, function, args, ...) abort
    call s:logger.LogDebug('API invoked: utest#ExpectCall(%s, %s, %s)',
        \ a:mock, a:function, a:000)
    if a:0 > 2
        call s:error.Throw('TOO_MANY_ARGS', 4)
    endif
    let return = exists('a:1') ? a:1 : v:null
    call a:mock._AddExpectedCall(a:function, a:args, return)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Command completion
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:GetPath() abort
    return s:runner.DiscoverTests(s:path, v:true)
endfunction

" Dashed complete options.
let s:opts = {
    \ '--name': funcref('s:GetPath'),
    \ '--cursor': v:null,
    \ }

" Path argument completed on the command line.
let s:path = s:system.Path(g:utest_default_test_dir, v:false)

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
" Examples:
"     one possible scenario:
"         cmd_line: 'UTest test/path.vim '
"         arg_lead: ''
"         cursor_pos: 20
"     another possible scenario:
"         cmd_line: 'UTest test/path.vim -'
"         arg_lead: '-'
"         cursor_pos: 21
"
function! utest#Complete(arg_lead, cmd_line, cursor_pos) abort
    " First argument is 'UTest', so we ignore it.
    let args = split(a:cmd_line)[1:]
    " If arg_lead is empty, all arguments count as completed, otherwise
    " completed arguments are all but the last one.
    let completed_args = a:arg_lead ==# '' ? args : args[:-2]
    if len(completed_args) == 0
        " If there are no completed arguments, we know that a path hasn't been
        " completed, so we reset the saved path to the default value.
        let s:path = s:system.Path(g:utest_default_test_dir, v:false)
        " If the current argument being completed is either empty or it does not
        " start with a dash, we know that a path is being completed, so we offer
        " to complete paths.
        if a:arg_lead ==# '' || match(a:arg_lead, '\m\C^-') == -1
            return join(s:system.Glob(a:arg_lead . '*', v:true), "\n")
        endif
    else
        " If some completed arguments exist, and the first completed argument
        " does not start with a dash, we save this argument as the path.
        if match(completed_args[0], '\m\C^-') == -1
            let s:path = completed_args[0]
        endif
    endif
    if len(completed_args) > 0 && get(s:opts, completed_args[-1], v:null) != v:null
        " If some completed arguments exist, and the last argument requires a
        " value, we offer to complete valid values for that argument
        return join(s:opts[completed_args[-1]](), "\n")
    else
        " Otherwise, if no completed arguments exist, or the last argument does
        " not require a value, we offer to complete dashed options.
        return join(keys(s:opts), "\n")
    endif
endfunction
