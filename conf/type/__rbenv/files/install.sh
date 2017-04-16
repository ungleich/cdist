[ -d /usr/local/rbenv ] && rm -rf /usr/local/rbenv
git clone git://github.com/sstephenson/rbenv.git /usr/local/rbenv

rbenv_file=/etc/profile.d/rbenv.sh
echo "# rbenv config" > $rbenv_file
echo "export RBENV_ROOT=/usr/local/rbenv" >> $rbenv_file
echo 'export PATH="$RBENV_ROOT/bin:$PATH"' >> $rbenv_file
echo 'eval "$(rbenv init -)"' >> $rbenv_file
chmod +x $rbenv_file
tmpdir=/tmp/ruby-build
[ -d "$tmpdir" ] && rm -rf $tmpdir
git clone git://github.com/sstephenson/ruby-build.git $tmpdir
cd $tmpdir
./install.sh
cd
rm -rf $tmpdir

# TODO prepend /etc/bash.bashrc with source /etc/profile.d/rbenv.sh
