Hacking
=======

Welcome
-------
Welcome dear hacker! I invite you to a tour of pointers to
get into the usable configuration management system, cdist.

The first thing to know is probably that cdist is brought to
you by people who care about how code looks like and who think
twice before merging or implementing a feature: Less features
with good usability are far better than the opposite.


Reporting bugs
--------------
If you believe you've found a bug and verified that it is
in the latest version, drop a mail to the cdist mailing list,
subject prefixed with "[BUG] " or create an issue on code.ungleich.ch.


Coding conventions (everywhere)
-------------------------------
If something should be improved or needs to be fixed, add the word FIXME
nearby, so grepping for FIXME gives all positions that need to be fixed.

Indentation is 4 spaces (welcome to the python world).


How to submit stuff for inclusion into upstream cdist
-----------------------------------------------------
If you did some cool changes to cdist, which you think might be of benefit to other
cdist users, you're welcome to propose inclusion into upstream.

There are some requirements to ensure your changes don't break other peoples
work nor kill the authors brain:

- All files should contain the usual header (Author, Copying, etc.)
- Code submission must be done via git
- Do not add cdist/conf/manifest/init - This file should only be touched in your
  private branch!
- Code to be included should be branched of the upstream "master" branch

   - Exception: Bugfixes to a version branch

- On a merge request, always name the branch I should pull from
- Always ensure **all** manpages build. Use **./build man** to test.
- If you developed more than **one** feature, consider submitting them in
  separate branches. This way one feature can already be included, even if
  the other needs to be improved.

As soon as your work meets these requirements, write a mail
for inclusion to the mailinglist **cdist-configuration-management at googlegroups.com**
or open a merge request at https://code.ungleich.ch/ungleich-public/cdist.


How to submit a new type
------------------------
For detailed information about types, see `cdist type <cdist-type.html>`_.

Submitting a type works as described above, with the additional requirement
that a corresponding manpage named man.rst in ReSTructured text format with
the manpage-name "cdist-type__NAME" is included in the type directory
AND the manpage builds (`make man`).

Warning: Submitting "exec" or "run" types that simply echo their parameter in
**gencode** will not be accepted, because they are of no use. Every type can output
code and thus such a type introduces redundant functionality that is given by
core cdist already.


Example git workflow
---------------------
The following workflow works fine for most developers

.. code-block:: sh

    # get latest upstream master branch
    git clone https://code.ungleich.ch/ungleich-public/cdist.git

    # update if already existing
    cd cdist; git fetch -v; git merge origin/master

    # create a new branch for your feature/bugfix
    cd cdist # if you haven't done before
    git checkout -b documentation_cleanup

    # *hack*
    *hack*

    # clone the cdist repository on code.ungleich.ch if you haven't done so

    # configure your repo to know about your clone (only once)
    git remote add ungleich git@code.ungleich.ch:YOURUSERNAME/cdist.git

    # push the new branch to ungleich gitlab
    git push ungleich documentation_cleanup

    # (or everything)
    git push --mirror ungleich

    # create a merge request at ungleich gitlab (use a browser)
    # *fixthingsbecausequalityassurancefoundissuesinourpatch*
    *hack*

    # push code to ungleich gitlab again
    git push ... # like above

    # add comment that everything should be green now (use a browser)

    # go back to master branch
    git checkout master

    # update master branch that includes your changes now
    git fetch -v origin
    git diff master..origin/master
    git merge origin/master

If at any point you want to go back to the original master branch, you can
use **git stash** to stash your changes away::

.. code-block:: sh

    # assume you are on documentation_cleanup
    git stash

    # change to master and update to most recent upstream version
    git checkout master
    git fetch -v origin
    git merge origin/master

Similarly when you want to develop another new feature, you go back
to the master branch and create another branch based on it::

.. code-block:: sh

    # change to master and update to most recent upstream version
    git checkout master
    git fetch -v origin
    git merge origin/master

    git checkout -b another_feature

(you can repeat the code above for as many features as you want to develop
in parallel)
