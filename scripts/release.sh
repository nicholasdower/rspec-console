#!/bin/bash

set -e

if [ $# -ne 1 ]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: stage or commit your changes." >&2
  exit 1;
fi

NEW_VERSION=$1
CURRENT_VERSION=$(grep VERSION lib/rspec-interactive/version.rb | cut -d'"' -f 2)

bundle exec bin/test

echo "Updating from v$CURRENT_VERSION to v$NEW_VERSION. Press enter to continue."
read

sed -E -i '' "s/VERSION = \"[^\"]+\"/VERSION = \"$NEW_VERSION\"/g" lib/rspec-interactive/version.rb
gem build
gem push rspec-interactive-$NEW_VERSION.gem
bundle install
git commit -a -m "v$NEW_VERSION Release"
open "https://github.com/nicholasdower/rspec-interactive/releases/new?title=v$NEW_VERSION%20Release&tag=v$NEW_VERSION&target=$(git rev-parse HEAD)"
