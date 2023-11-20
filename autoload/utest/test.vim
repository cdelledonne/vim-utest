" ==============================================================================
" Location:    autoload/utest/test.vim
" Description: Unit testing and mocking
" ==============================================================================

let s:test = {}
let s:test.sourced_files = {}
let s:test.fixtures = []
let s:test.qflist_id = -1

let s:assert = utest#assert#Get()
let s:const = utest#const#Get()
let s:quickfix = libs#quickfix#Get()
let s:report = utest#report#Get()
let s:system = libs#system#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:error = libs#error#Get(s:const.plugin_name, s:logger)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:test._ParseRunArgs(args) abort
    let tests = []
    " Parse arguments.
    let parser = libs#argparser#New()
    call parser.AddArgument('path', '?')
    call parser.AddArgument('--name', '*')
    let opts = parser.Parse(a:args)
    let path = remove(opts, 'path')
    let path = path is v:null ? g:utest_default_test_dir : path
    let path = s:system.Path(path, v:false)
    " Process other arguments.
    if has_key(opts, 'name')
        let tests = type(opts.name) == v:t_list ? opts.name : [opts.name]
    endif
    return [path, tests]
endfunction

function! s:test._ScanTestFiles(files) abort
    " Source test files to discover test fixtures, then compile list of tests
    " for each fixture.
    for file in a:files
        " If a file had already been sourced and has not been modified since,
        " just use the cached test fixtures already discovered.
        if has_key(self.sourced_files, file) &&
            \ getftime(file) == self.sourced_files[file].ftime
            call s:logger.LogDebug(
                \ 'File %s already sourced, using cached fixtures', string(file)
                \ )
            call extend(self.fixtures, self.sourced_files[file].fixtures)
        " Otherwise, (re)source the file, compile tests in fixtures found, and
        " cache test fixtures.
        else
            call s:logger.LogDebug('(Re)sourcing file %s', string(file))
            let first = len(self.fixtures)
            call s:system.Source(file)
            let last = len(self.fixtures)
            let fixtures_this_file = self.fixtures[first:last]
            for fixture in fixtures_this_file
                call fixture._CompileTests()
            endfor
            let self.sourced_files[file] = {
                \ 'ftime': getftime(file),
                \ 'fixtures': fixtures_this_file,
                \ }
        endif
    endfor
endfunction

function! s:test._CheckSelectedTestsExist(selected_tests) abort
    " Make list of all tests.
    let test_dicts = []
    for fixture in self.fixtures
        call extend(test_dicts, fixture._GetTests())
    endfor
    let test_names = map(test_dicts, {_, v -> v.funcname})
    call uniq(test_names)
    " Check that selected tests is a subset of all tests.
    for test in a:selected_tests
        if !s:system.ListHas(test_names, test)
            call s:error.Throw('TEST_DOES_NOT_EXIST', string(test))
        endif
    endfor
endfunction

function! s:test._RunTest(fixture, test) abort
    let error_list = []
    let a:test.setup_running = v:false
    let a:test.teardown_running = v:false
    call s:report.ReportTestInfo('Running test ''%s''', a:test.funcname)
    call s:logger.LogDebug('Running test ''%s''', a:test.funcname)
    " Run the SetUp() function. If this does not run successfully, we won't run
    " the test function (nor the TearDown() function).
    try
        let a:test.setup_running = v:true
        call a:fixture.SetUp()
    catch /vim-utest-assert-failed/
    finally
        let a:test.setup_running = v:false
    endtry
    " The test function and the TearDown() function are only run if the SetUp()
    " function succeeded (i.e. no errors recorded so far).
    if len(a:test.errors) == 0
        try
            call a:fixture[a:test.funcname]()
        catch /vim-utest-assert-failed/
        endtry
        " The TearDown() function is run whether or not the test function as
        " incurred any errors.
        try
            let a:test.teardown_running = v:true
            call a:fixture.TearDown()
        catch /vim-utest-assert-failed/
        finally
            let a:test.teardown_running = v:false
        endtry
    endif
    if len(a:test.errors) > 0
        for error in a:test.errors
            let fmt = '%s:%d: Error: %s'
            let test_file = s:system.Path(a:test.file, v:true)
            let error_args = [fmt, test_file, error.lnum, error.msg]
            call call(funcref('s:report.ReportTestError'), error_args, s:report)
            call call(funcref('s:logger.LogDebug'), error_args, s:logger)
            call add(error_list, call('printf', error_args))
        endfor
        call s:report.ReportTestError('Test failed')
        call s:logger.LogDebug('Test failed')
    else
        call s:report.ReportTestInfo('Test passed')
        call s:logger.LogDebug('Test passed')
    endif
    return error_list
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Create new test fixture.
"
" Returns:
"     Dictionary
"         test fixture
"
function! s:test.NewFixture() abort
    call s:logger.LogDebug('Invoked: test.NewFixture()')
    let fixture = utest#fixture#New()
    call add(self.fixtures, fixture)
    return fixture
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
function! s:test.NewMock(functions) abort
    call s:logger.LogDebug('Invoked: test.NewMock(%s)', a:functions)
    let mock = {}
    for function in a:functions
        " TODO: Funcref should have a proper definition
        let Funcref = {-> 0}
        let mock[function.name] = Funcref
        if has_key(function, 'ref')
            execute 'let ' . function.ref ' = Funcref'
        endif
    endfor
    return mock
endfunction

" Recursively scan path to discover tests.
"
" Params:
"     path : String
"         file or directory to scan
"     a:1 (noexcept) : Boolean
"         if set to v:true, this function will not throw exceptions (useful e.g.
"         when called to provide autocompletion for test names)
"
function! s:test.DiscoverTests(path, ...) abort
    let noexcept = exists('a:1') ? a:1 : v:false
    " Scan path recursively for test files.
    if s:system.FileIsReadable(a:path)
        let files = [s:system.Path(a:path, v:false)]
    elseif s:system.DirectoryExists(a:path)
        let files = s:system.Glob(a:path . '/**/*.vim')
    else
        if noexcept
            call s:logger.LogWarn(
                \ 'test.DiscoverTests() failed, ' .
                \ 'path %s is invalid', string(a:path)
                \ )
            return
        else
            call s:error.Throw('NO_SUCH_PATH', string(a:path))
        endif
    endif
    let self.fixtures = []
    if noexcept
        try
            call self._ScanTestFiles(files)
        catch /.*/
            call s:logger.LogWarn(
                \ 'test.DiscoverTests() failed, ' .
                \ 'exception thrown from test._ScanTestFiles()'
                \ )
        endtry
    else
        call self._ScanTestFiles(files)
    endif
endfunction

" Run tests in a certain directory or file.
"
" Params:
"     args : List
"         directory or file to scan for tests and additional :UTest arguments
"
" Returns:
"     Number
"         number of failed tests
"
function! s:test.RunTests(args) abort
    call s:logger.LogDebug('Invoked: test.Run(%s)', a:args)
    let num_tests = 0
    let num_failed_tests = 0
    let error_list = []
    call s:report.Reset()
    if g:utest_focus
        call s:report.Focus()
    endif
    call s:report.ReportInfo('Running Vim-UTest')
    try
        let [path, selected_tests] = self._ParseRunArgs(a:args)
        let run_all = len(selected_tests) > 0 ? v:false : v:true
        call self.DiscoverTests(path)
        " Check that selected tests match at least one existing test each.
        if !run_all
            call self._CheckSelectedTestsExist(selected_tests)
        endif
        " Run tests, going through test fixtures in the order they were
        " discovered in the sourced files.
        for fixture in self.fixtures
            let fixture_file = s:system.Path(fixture.file, v:true)
            call s:report.ReportInfo('Running tests in file %s', fixture_file)
            call s:logger.LogDebug('Running tests in file %s', fixture_file)
            for test in fixture._GetTests()
                " Only run this test if all tests are to be run or if a test was
                " selected explicitly.
                if run_all || s:system.ListHas(selected_tests, test.funcname)
                    let num_tests += 1
                    call s:assert.SetCurrentTest(test)
                    let current_error_list = self._RunTest(fixture, test)
                    let num_failed_tests += len(current_error_list) > 0 ? 1 : 0
                    call extend(error_list, current_error_list)
                endif
            endfor
        endfor
    catch /.*/
        let num_failed_tests = 1
        call s:report.ReportTestError(v:throwpoint)
        call s:report.ReportTestError(v:exception)
        call s:report.ReportInfo('Tests aborted due to uncaught exception')
        call s:system.AutocmdRun('UTestTestsAborted')
        return num_failed_tests
    finally
        if g:utest_focus_on_completion ||
                    \ (g:utest_focus_on_error && num_failed_tests > 0)
            call s:report.Focus()
        endif
    endtry
    " Generate Quickfix list for reported errors.
    let self.qflist_id = s:quickfix.Generate(
                \ error_list, self.qflist_id, 'Vim-UTest')
    " Report (and log) final stats.
    let num_passed_tests = num_tests - num_failed_tests
    call s:report.ReportInfo('Total tests: %d', num_tests)
    call s:report.ReportInfo('Passed: %d', num_passed_tests)
    call s:report.ReportInfo('Failed: %d', num_failed_tests)
    call s:logger.LogDebug('Total tests: %d, Passed: %d, Failed: %d',
                \ num_tests, num_passed_tests, num_failed_tests
                \ )
    let cmd = num_failed_tests > 0 ? 'UTestTestsFailed' : 'UTestTestsSucceeded'
    call s:system.AutocmdRun(cmd)
    return num_failed_tests
endfunction

" Get test 'object'.
"
function! utest#test#Get() abort
    return s:test
endfunction
