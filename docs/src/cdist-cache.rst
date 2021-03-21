Local cache overview
====================

Description
-----------
While executing, cdist stores data to local cache. Currently this feature is
one way only. That means that cdist does not use stored data for future runs.
Anyway, those data can be used for debugging cdist, debugging types and
debugging after host configuration fails.

Local cache is saved under $HOME/.cdist/cache directory, one directory entry
for each host. Subdirectory path is specified by
:strong:`-C/--cache-path-pattern` option, :strong:`cache_path_pattern`
configuration option or by using :strong:`CDIST_CACHE_PATH_PATTERN`
environment variable.

For more info on cache path pattern see :strong:`CACHE PATH PATTERN FORMAT`
section in cdist man page.


Cache overview
--------------
As noted above each configured host has got its subdirectory in local cache.
Entries in host's cache directory are as follows.

bin
  directory with cdist type emulators
  
conf
  dynamically determined cdist conf directory, union of all specified
  conf directories

explorer
  directory containing global explorer named files containing explorer output
  after running on target host

messages
  file containing messages

object
  directory containing subdirectory for each cdist object

object_marker
  object marker for this particular cdist run

stderr
  directory containing init manifest and remote stderr stream output

stdout
  directory containing init manifest and remote stdout stream output

target_host
  file containing target host of this cdist run, as specified when running
  cdist

typeorder
  file containing types in order of execution.


Object cache overview
~~~~~~~~~~~~~~~~~~~~~
Each object under :strong:`object` directory has its own structure.

autorequire
    file containing a list of object auto requirements

children
    file containing a list of object children, i.e. objects of types that this
    type reuses (along with 'parents' it is used for maintaining parent-child
    relationship graph)

code-local
    code generated from gencode-local, present only if something is
    generated

code-remote
    code generated from gencode-remote, present only if something is
    generated

explorer
    directory containing type explorer named files containing explorer output
    after running on target host

files
    directory with object files created during type execution
    
parameter
    directory containing type parameter named files containing parameter
    values   

parents
    file containing a list of object parents, i.e. objects of types that reuse
    this type (along with 'children' it is used for maintaining parent-child
    relationship graph); objects without parents are objects specified in init
    manifest

require
    file containing a list of object requirements

source
    this type's source (init manifest)

state
    this type execution state ('done' when finished)

stderr
  directory containing type's manifest, gencode-* and code-* stderr stream
  outputs

stdin
    this type stdin content

stdout
  directory containing type's manifest, gencode-* and code-* stdout stream
  outputs.
