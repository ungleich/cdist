#!/bin/bash
#
# script to run on systems that didn't get cdist stuff setup via
# user_data (but did get the czdeploy authorized_keys setup).
#

if [[ $USER != 'czdeploy' && $USER != 'root' ]]; then
  echo "Please execute $0 as the czdeploy or root user"
  exit 2
fi

if [ -z "$1" ]; then
  echo "Usage: $0 <host>"
  exit 2
fi

B=$1
K=/home/czdeploy/.ssh/czdeploy.util1_relKey

# TODO: need to scp this somewhere that we know exists and that czdeploy
# can sudo, but it also needs to be a standard location across waltham,
# rackspace, and intl
scp -i $K /cdist/cdist/local/bootstrap/remote_exec czdeploy@$B:/deploy/scripts/bootstrap_cdist
scp -i $K /root/.ssh/cdist.pub czdeploy@$B:/tmp/cdist.pub
ssh -ti $K czdeploy@$B sudo /deploy/scripts/bootstrap_cdist

nc -z $B 222
if [ $? -ne 0 ]; then
  echo "Nothing running on $B:222, looks like bootstrapping failed"
  exit 1
 else
  echo "Bootstrap success!  Go ahead and run:"
  echo "sudo /cdist/local/cdist_wrapper $B"
  exit 0
fi

