#!/bin/bash

VERSION=$1
REPO=https://rubycas-client.googlecode.com/svn
APP=rubycas-client

APPVER=$APP-$VERSION

cd `dirname $0`

if [[ ! -n $1 ]]
then
	echo "You must enter a version number!" >&2
	exit 1
fi

echo "Packaging $APPVER..."

echo "Deleting old snapshot tag in SVN (if it already exists)"
svn delete $REPO/tags/$APPVER -m "deleting previous snapshot -- will be replaced with new snapshot" 2> /dev/null

echo "Creating snapshot tag in SVN"
svn copy -rHEAD $REPO/trunk $REPO/tags/$APPVER -m "Snapshot of $VERSION release"

cd ..

if [[ -d $APPVER ]]
then rm -rf $APPVER
fi

echo "Exporting snapshot from SVN"
svn export $REPO/tags/$APPVER

if [[ -f $APPVER.tar.bz2 ]]
then rm $APPVER.tar.bz2
fi

echo "Creating tar"
tar -cvjf $APPVER.tar.bz2 $APPVER

if [[ -f $APPVER.zip ]]
then rm $APPVER.zip
fi

echo "Creating zip"
zip -r $APPVER.zip $APPVER/*

cd $APPVER

if [[ -f $APPVER.gem ]]
then rm $APPVER.gem
fi

echo "Building gem"
gem build $APP.gemspec
mv $APPVER.gem ../.

cd ..
rm -rf $APPVER
