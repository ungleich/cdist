Execution stages
================

Description
-----------
When cdist is started, it passes through different stages.


Stage 1: target information retrieval
-------------------------------------
In this stage information is collected about the target host using so called
explorers. Every existing explorer is run on the target and the output of all 
explorers are copied back into the local cache. The results can be used by 
manifests and types.


Stage 2: run the initial manifest
---------------------------------
The initial manifest, which should be used for mappings of hosts to types,
is executed. This stage creates objects in a cconfig database that contains
the objects as defined in the manifest for the specific host. In this stage,
no conflicts may occur, i.e. no object of the same type with the same id may
be created, if it has different parameters.


Stage 3: object information retrieval
-------------------------------------
Every object is checked whether its type has explorers and if so, these are 
executed on the target host. The results are transferred back
and can be used in the following stages to decide what changes need to be made
on the target to implement the desired state.


Stage 4: run the object manifest
--------------------------------
Every object is checked whether its type has a executable manifest. The 
manifest script may generate and change the created objects. In other words, 
one type can reuse other types.

For instance the object __apache/www.example.org is of type __apache, which may 
contain a manifest script, which creates new objects of type __file.

The newly created objects are merged back into the existing tree. No conflicts
may occur during the merge. A conflict would mean that two different objects
try to create the same object, which indicates a broken configuration.


Stage 5: code generation
------------------------
In this stage for every created object its type is checked for executable 
gencode scripts. The gencode scripts generate the code to be executed on the 
target on stdout. If the gencode executables fail, they must print diagnostic 
messages on stderr and exit non-zero.


Stage 6: code execution
-----------------------
For every object the resulting code from the previous stage is transferred to
the target host and executed there to apply the configuration changes.


Stage 7: cache
--------------
The cache stores the information from the current run for later use.


Summary
-------
If, and only if, all the stages complete without errors, the configuration
will be applied to the target.
