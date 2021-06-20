#!/usr/bin/env bash

# Used to quickly test a development version of a gem in the current
# directory. Adds a local copy of the specified gem, at the specified
# path, to the current directory's Gemfile and executes the specified
# command. Upon completion, the Gemfile will be returned to its
# previous state.

if [ $# -ne 3 ]; then
  echo "usage: $0 <gem-name> <path> <command>" >&2
  exit 1
fi

GEM_NAME=$1
GEM_PATH=$2
COMMAND=$3

if [ -d $GEM_NAME ]; then
  echo "directory exists: $GEM_NAME" >&2
  exit 1
fi

OLD_DEP=$(grep "'$GEM_NAME'" Gemfile)
if [ $? -ne 0 ]; then
  echo "$GEM_NAME not found in Gemfile" >&2
  exit 1
fi

cp Gemfile Gemfile.save
cp Gemfile.lock Gemfile.lock.save
cp -R $GEM_PATH $GEM_NAME
sed -i '' -E "s/^( *gem '$GEM_NAME').*/\1, path: '$GEM_NAME'/g" Gemfile
$COMMAND
rm -rf $GEM_NAME
mv Gemfile.lock.save Gemfile.lock
mv Gemfile.save Gemfile
