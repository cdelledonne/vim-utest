" ==============================================================================
" Location:    autoload/utest/fixture.vim
" Description: Test fixture class
" ==============================================================================

let s:fixture = {}
let s:fixture.internal_functions = []
let s:fixture.file = ''
let s:fixture.tests = []

let s:const = utest#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:system = libs#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Default functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Just an empty default SetUp() function.
"
function! s:fixture.SetUp() abort
    call s:logger.LogDebug('Invoked: default fixture.SetUp()')
endfunction

" Just an empty default TearDown() function.
"
function! s:fixture.TearDown() abort
    call s:logger.LogDebug('Invoked: default fixture.TearDown()')
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
"
" Note: This are public functions, but their names start with an underscore to
" avoid naming conflicts with test function names defined by the user.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Process fixture to discover and compile list of tests.
"
function! s:fixture._CompileTests() abort
    call s:logger.LogDebug('Invoked: fixture._CompileTests()')
    " Extract line of function definition for SetUp() and TearDown().
    let [setup_lnum, teardown_lnum] = [v:null, v:null]
    let [_, setup_lnum, _] = s:system.GetFunctionInfo(self.SetUp)
    let [_, teardown_lnum, _] = s:system.GetFunctionInfo(self.TearDown)
    " Filter out internal functions. In the lambda, item is an item of the self
    " dictionary, thus item[0] is the item's name (can be the name of a
    " function) and item[1] is item's value (can be a funcref).
    let user_callables = filter(items(self), {
        \ _, item ->
        \     (type(item[1]) == v:t_func) &&
        \     !s:system.ListHas(self.internal_functions, item[0])
        \ })
    for [funcname, Funcref] in user_callables
        " Extract file and line of test function definition.
        let [file, start_lnum, end_lnum] = s:system.GetFunctionInfo(Funcref)
        " Add test to list of fixture's tests.
        let test = {
            \ 'funcname': funcname,
            \ 'file': file,
            \ 'start_lnum': start_lnum,
            \ 'end_lnum': end_lnum,
            \ 'setup_lnum': setup_lnum,
            \ 'teardown_lnum': teardown_lnum,
            \ 'errors': [],
            \ }
        call add(self.tests, test)
        call s:logger.LogDebug('Added test %s: %s', string(funcname), test)
    endfor
    " Sort fixture's tests according to where they were defined.
    call sort(self.tests, {lhs, rhs -> lhs.start_lnum - rhs.start_lnum})
endfunction

" Get fixture's tests.
"
" Returns:
"     List
"         list of tests
"
function! s:fixture._GetTests() abort
    call s:logger.LogDebug('Invoked: fixture._GetTests()')
    return self.tests
endfunction

" Get fixture's test name at a certain line number in a certain file.
"
" Params:
"     file : String
"         filter tests only defined in this file
"     lnum : Number
"         get test at this line number
"
" Returns:
"     String
"         test name, or empty string if file doesn't exist or if line number
"         does not belong to any test function
"
function! s:fixture._SearchTest(file, lnum) abort
    call s:logger.LogDebug('Invoked: fixture._SearchTest()')
    let tests_in_file = filter(
        \ copy(self.tests),
        \ {_, v ->
        \     (v.file ==# a:file) &&
        \     (a:lnum >= v.start_lnum) &&
        \     (a:lnum <= v.end_lnum)
        \ }
        \ )
    if len(tests_in_file) == 1
        return tests_in_file[0].funcname
    else
        return ''
    endif
endfunction

" Create new fixture 'object'.
"
function! utest#fixture#New() abort
    call s:logger.LogDebug('Invoked: utest#fixture#New()')
    let fixture = deepcopy(s:fixture)
    let callables = filter(copy(fixture), {k, v -> type(v) == v:t_func})
    let fixture.internal_functions = keys(callables)
    " API call utest#NewFixture() is fourh-to-last in stack trace, and thus the
    " script it is called from is fifth-to-last.
    let call_point = s:system.GetStackTrace()[-5]
    let file = matchlist(call_point, '\m\Cscript\s\(.*\)\[\d\+\]')[1]
    let fixture.file = s:system.Path(file, v:false)
    return fixture
endfunction
