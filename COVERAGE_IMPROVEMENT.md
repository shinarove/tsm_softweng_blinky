# Increasing code coverage

What is not covered today in `leds.c`, `sample.c`, `platform.c` and `gcov_test.c`, and which test or input covers it.

## Baseline

From `gcovr/main.html` (gcovr 8.6, `Debug` build, blinky running for about 6 s):

| File | Lines | Functions | Branches |
|---|---|---|---|
| `leds.c` | 31/71 (43.7 %) | 3/7 | 5/28 |
| `sample.c` | 8/70 (11.4 %) | 2/5 | 1/30 |
| `platform.c` | 22/32 (68.8 %) | 1/2 | 0/6 |
| `gcov_test.c` | 0/18 (0 %) | 0/1 | 0/8 |
| all of `src/` | 96/230 (41.7 %) | 12/21 | 15/84 |

## Why it is low

1. **The unit tests do not count.** The report is produced by the `Debug` build, which contains no tests. The tests only exist in the `Test` build, and there `TestTask` (`src/tests/tests.c`) stops J-Run with `*STOP*` without ever calling `McuCoverage_WriteFiles()`, so no `.gcda` is written.
2. **Most code needs a caller or an input that the 6 s blinky run never provides.** The blinky only calls `Leds_Neg(LEDS_ONBOARD)`; `sample.c` waits for text on the USB terminal; `gcov_test()` is not called from anywhere.
3. **A few lines are error traps** (`for(;;){}` after a failed init) that cannot be reached on working hardware.

## Step 1: let the tests produce coverage data

- Enable `PL_CONFIG_USE_GCOV` for the `Test` build as well (the README currently says to disable it).
- In `TestTask`, write the data before stopping the runner:
  ```c
  nofFailures = UNITY_END();
  #if PL_CONFIG_USE_GCOV
    McuCoverage_WriteFiles();
  #endif
  McuUnity_Exit_JRun_RTT(nofFailures==0);
  ```
- Add an argument `"all"` to the dispatcher in `TestTask` that runs every test in one session, and an `add_test(NAME All ...)` in `src/tests/CMakeLists.txt`.
- In `AppTask` (`src/application.c`), skip `Leds_Neg(LEDS_ONBOARD)` and `vTaskEndScheduler()` when `PL_CONFIG_USE_UNIT_TESTS` is set. Otherwise the blinky toggles the on-board LED while a test checks it, and ends the scheduler after 6 s.
- Start from clean data and limit the report to the application code:
  ```
  Get-ChildItem build -Recurse -Filter *.gcda | Remove-Item
  ctest --test-dir build/Test -R All
  gcovr --filter src/ --html-details -o ./gcovr/main.html
  ```

**Check first:** this needs J-Run to write the `.gcda` files through semihosting file I/O, as the debugger does for the `Debug` build. This has not been tried on the board. If it does not work, run the `Test` ELF with the debugger instead; `TestTask` then needs a path that runs all tests without waiting for arguments, because `McuUnity_RTT_GetArgs()` blocks without J-Run.

## Step 2: what to test

### `leds.c`

`Leds_On`, `Leds_Off`, `Leds_Neg` and `Leds_Get` are each a switch with five branches: red, green, blue, on-board and `default`. The existing tests (`Led_1`, `Led_2`) cover red, green and blue. Missing:

| New test | What it does | Covers |
|---|---|---|
| `TestLeds_Onboard` | On / Off / Neg on `LEDS_ONBOARD`, check `Leds_Get()` after each | on-board branch in all four functions |
| `TestLeds_InvalidLed` | pass `LEDS_NOF_LEDS` to all four, expect `Leds_Get()` to return `false` | `default` branches and the final `return false` |
| `TestLeds_DeinitInit` | `Leds_Deinit()`, `Leds_Init()`, then On / Get on one LED (run it last) | `Leds_Deinit` |

```c
void TestLeds_InvalidLed(void) {
  Leds_On(LEDS_NOF_LEDS);
  Leds_Off(LEDS_NOF_LEDS);
  Leds_Neg(LEDS_NOF_LEDS);
  TEST_ASSERT_FALSE_MESSAGE(Leds_Get(LEDS_NOF_LEDS), "invalid LED shall report off");
}
```

`TestLeds_Onboard` needs `Leds_InitFromTask()` to have finished; a short `vTaskDelay()` at the start of the test is enough.

### `sample.c`

`ParseCommand()`, `process()` and `shell_sort()` only run when a line arrives on the USB terminal. `ParseCommand()` is not `static`, so a test can call it directly with a string (add a declaration to `sample.h`). Add `src/tests/test_sample.c`:

| Input | Covers | Assert |
|---|---|---|
| `"help"` | help branch | `handled == true`, returns `ERR_OK` |
| `"abc"` | "not for me" path | `handled == false` |
| `"42"` | one number, no space found | `handled == true` |
| `"1 2 3"` | already sorted (`i == j`, inner loop not entered) | `handled == true` |
| `"9 8 7 6 5 4 3 2 1"` | reverse order, both gap passes, elements moved | `handled == true` |
| `"3 3 1 2 2"` | duplicates (`a[j-h] > v` false with `j >= h` true) | `handled == true` |
| 63 numbers | `argc` limit of the `argv[]` array | `handled == true` |

```c
void TestSample_Sort(void) {
  bool handled = false;
  uint8_t res = ParseCommand((const uint8_t*)"9 8 7 6 5 4 3 2 1", &handled, McuShellCdcDevice_GetStdio());
  TEST_ASSERT_TRUE(handled);
  TEST_ASSERT_EQUAL_UINT8(ERR_OK, res);
}
```

Output to the USB CDC device is dropped when no terminal is connected, so the test does not block.

Do not use a single-character line such as `"7"` as a test input yet: the tokenizer loop in `ParseCommand()` then steps over the string terminator and reads past the end of its buffer. That is a second bug worth fixing before adding such a test.

These tests execute the code but cannot check the sorted result, because `process()` only prints it. `sample.c` contains a deliberate bug (`shell_sort(a, argc)` is called with one element too many) and reaches full coverage without the tests noticing it. To test the result, make `shell_sort()` visible to tests (declare it in `sample.h` under `PL_CONFIG_USE_UNIT_TESTS`) and compare the array with `TEST_ASSERT_EQUAL_INT_ARRAY`.

### `platform.c`

`PL_Init()` is already fully covered. The whole gap is `allocMem()`, which is only called from `ParseCommand()` for numeric input. Any of the numeric `sample.c` tests above brings `platform.c` to 100 %; no separate test is needed.

### `gcov_test.c`

`gcov_test()` has no caller, so the file is at 0 %. It returns nothing, so a test can only drive the paths. With `j = Calc(i, 2*i)`:

| `i` | Path |
|---|---|
| `0` | `Calc`: `i == 0`, result 1; prints "j is not zero" |
| `1` | `Calc`: result 3; `Value()` returns 5; `Test2` sets `j` to 0; prints "j is zero" |
| `2` | `Calc`: result 6; `Value()` returns 1 |
| `5` | `i > 0` but `j < 10` is false |
| `-1` | `i > 0` is false |

For `i = 5` and `i = -1`, `Calc()` returns `res` without ever assigning it. Fix this first (`int res = 0;`); with that fix these two inputs also cover the `*p != 0` false branch in `Test2`.

```c
void TestGcov_AllPaths(void) {
  static const int in[] = {-1, 0, 1, 2, 5};
  for (size_t k=0; k<sizeof(in)/sizeof(in[0]); k++) {
    gcov_test(in[k]);
  }
}
```

## Step 3: exclude unreachable error traps

Mark them, with a reason, so they stop showing up as gaps:

```c
ledRed = McuLED_InitLed(&config);
/* GCOVR_EXCL_START: only reachable if out of memory during init */
if (ledRed==NULL) {
  for(;;) {}
}
/* GCOVR_EXCL_STOP */
```

Candidates: the three `ledX==NULL` traps in `Leds_Init`, the `cyw43_arch_init()` failure in `Leds_InitFromTask`, the `xTaskCreate` failures in `App_Init` and `Sample_Init`, and `arg==NULL` in `ParseCommand`.

## Not measured today

The shell commands in `leds.c` (`Leds_ParseCommand` and its helpers, about 120 lines) are compiled out because `PL_CONFIG_USE_SHELL` is 0, so they are not in the report at all. If the shell is enabled later, test `Leds_ParseCommand()` the same way as `ParseCommand()`: `"led help"`, `"led status"`, `"led red on"`, `"led red off"`, `"led red neg"`, `"led red xyz"` and an unrelated command.

## Expected result

Line coverage, calculated from the counts in the current report (not measured):

| File | Now | After steps 1 + 2 | After step 3 |
|---|---|---|---|
| `leds.c` | 43.7 % | about 93 % | 100 % |
| `sample.c` | 11.4 % | about 95 % | 100 % |
| `platform.c` | 68.8 % | 100 % | 100 % |
| `gcov_test.c` | 0 % | 100 % | 100 % |
| all of `src/` | 41.7 % | about 95 % | close to 100 % |

To keep it there, let the build fail below a threshold:

```
gcovr --filter src/ --fail-under-line 90 --fail-under-branch 80
```
