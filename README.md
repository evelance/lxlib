# [Experiment] Lua eXtension library with static hashing

## Motivation

Lua is probably the scripting language that offers the lightest way to
create fully independent execution contexts (a lua_State).

But even with the small standard library the language offers, registering all functions
into the state so that the script can access them comes at a significant cost - around
90% of the total time needed to run a small pre-compiled script.
Adding user-defined functions increases this cost, and dynamic loaded modules are even slower.

This experiment investigates:
1. If static hash tables can avoid this cost
2. How such modules would be written and what the implications are for scripts
3. How Lua will behave if a large amount of user-supplied functions get added.

All modifications and additional files are released into public domain.

## Instructions

1. Run refresh_and_run.sh
2. The files out-lx and out-normal are benchmarks that compare
   the time needed to create 100K states, load the Lua standard libraries,
   load and execute precompiled bytecode, perform a full garbage-collection
   cycle and teardown the states.
3. out-lua54-normal out-lua54-lx can be used for manual testing
4. Change in Makefile: LXLIB=basex
5. Run refresh_and_run.sh
6. Now out-lx and out-lua54-lx have some more modules included (lfs and lhf.{complex, mathx, base64, ascii85})
7. Change in Makefile: LXLIB=heavy
8. Run refresh_and_run.sh (takes minutes)
9. Now out-lx and out-lua54-lx include around 100K auto-generated functions (module1 to module200 with 
   the functions module1.m1func1 to module1.m1func200) and have an object size of around 40MB.

## Sample results

Tested on a virtualized Linux 5.4.0-4-amd64, i5-2430M, 100K states

### Executing test program (main.c/script.lua)

 - LX lib: Lua 5.4 standard libraries
 - Normal: Lua 5.4 standard libraries
```
./out-lx
Create states     -  1.0409s
Load libraries    -  0.1597s
Load bytecode     -  0.4913s
Execution         -  7.5180s
memory usage per state: 8KB
full gc cycle     -  0.7457s
Cleanup           -  1.1452s
```
```
./out-normal
Create states     -  1.0743s
Load libraries    - 13.6163s
Load bytecode     -  0.5637s
Execution         -  7.8426s
memory usage per state: 22KB
full gc cycle     -  0.8152s
Cleanup           -  1.8271s
```

 - LX lib: Lua 5.4 standard libraries + LuaFileSystem + some LHF libraries
```
./out-lx
Create states     -  1.0495s
Load libraries    -  0.1596s
Load bytecode     -  0.4896s
Execution         -  6.4444s
memory usage per state: 8KB
full gc cycle     -  0.7956s
Cleanup           -  1.1430s
```

 - Normal: Lua 5.4 standard libraries + require base64 (LHF)
```
./out-normal
Create states     -  1.0629s
Load libraries    - 11.0060s
Load bytecode     -  0.5761s
Require base64    - 40.4501s
Execution         -  7.8623s
memory usage per state: 23KB
full gc cycle     -  0.9126s
Cleanup           -  1.5989s
```

 - LX lib: Lua 5.4 standard libraries + some LHF libraries + many auto-generated functions
 - 100K functions, executable size is now almost 40MB
```
./out-lx 
Create states     -  1.1100s
Load libraries    -  0.1638s
Load bytecode     -  0.5040s
Execution         -  6.4105s
memory usage per state: 8KB
full gc cycle     -  0.8932s
Cleanup           -  1.2539s
```

### Executing with the command-line interpreter

 - Normal: Lua 5.4 standard libraries
 - First call
```
$ time ./out-lua54-normal -e "print 'hello world'"
hello world

real	0m0,025s
user	0m0,000s
sys	0m0,019s
```

 - Normal: Lua 5.4 standard libraries
 - Consecutive calls
```
$ time ./out-lua54-normal -e "print 'hello world'"
hello world

real	0m0,010s
user	0m0,000s
sys	0m0,009s
```


- LX lib: Lua 5.4 standard libraries + some LHF libraries + many auto-generated functions
- 100K functions, executable size is now almost 40MB
- First call
```
$ time ./out-lua54-lx -e "print 'hello world'"
hello world

real	0m0,203s
user	0m0,019s
sys	0m0,112s
```

- LX lib: Lua 5.4 standard libraries + some LHF libraries + many auto-generated functions
- 100K functions, executable size is now almost 40MB
- Consecutive calls
```
$ time ./out-lua54-lx -e "print 'hello world'"
hello world

real	0m0,013s
user	0m0,000s
sys	0m0,011s
```
