
function newID {
	NAME=`jq '.name' $1 | tr -d '"'`
	PREV_ID=`apps-list -n $NAME | head -n1 | awk '{print $1;}'`
	let LAST_CHAR="(${PREV_ID: -1} + 1) % 10"
	PREV_VERSION="${PREV_ID: -5}"
	NEW_VERSION="${PREV_VERSION:0:-1}$LAST_CHAR"
	echo $NEW_VERSION
}


WEBHOOK="${1}"
CLONE_URL=`jq '.repository.clone_url' $WEBHOOK | tr -d '"'`
REPO_NAME=`basename ${CLONE_URL%%.git}`
DESCRIPTION_FILE="$REPO_NAME/agave.json"
echo REPO NAME: $REPO_NAME

REF=`jq '.ref' $WEBHOOK | tr -d '"'` 			# ref/tags/branch
CHECK_BRANCH=`basename $REF`				# ref/tags/BRANCH
CHECK_TAGS=`basename $(dirname $REF)`			# ref/TAGS/branch
CHECK_CREATED=`jq '.created' $WEBHOOK | tr -d '"'`
echo REF: ref/$CHECK_TAGS/$CHECK_BRANCH

IS_RELEASE=false
IS_VALID_COMMIT=false
if [ "$CHECK_TAGS" == "tags" ]; then
	IS_RELEASE=true
elif [ "$CHECK_BRANCH" == "master" ] || [ $CHECK_CREATED = false ]; then
	IS_VALID_COMMIT=true
else
	echo "This is not a simple commit or release. Exiting without updating app."
	exit
fi

# check current dir is not git repo
if [ ! "$(git branch 2> /dev/null)" == "" ]; then 
	echo "Current dir $PWD is already git dir. Exiting."
	exit
fi

# clone repo
echo Cloning into $PWD
git clone $CLONE_URL

# check for app description
if ! [ -e "$PWD/$DESCRIPTION_FILE" ]; then
	echo "The repo must contain exactly one agave.json file in the base directory. Exiting."
	exit
fi

# set up version
VERSION=`jq '.version' $DESCRIPTION_FILE | tr -d '"'`
if [[ "$VERSION" == "(sourceref)" ]]; then
	if [ $IS_RELEASE = true ]; then
		REPLACEMENT=`basename $REF`
	else
		REPLACEMENT=`newID $DESCRIPTION_FILE`
	fi
	# update description file
        VERSION="${VERSION/(sourceref)/$REPLACEMENT}"
	CHANGE_DESCRIPTION_FILE=`jq --arg foo $VERSION '.version = $foo' $DESCRIPTION_FILE`
	rm $PWD/$DESCRIPTION_FILE
	echo $CHANGE_DESCRIPTION_FILE >> $PWD/$DESCRIPTION_FILE
fi

# register app
echo Registering app
apps-addupdate -F $DESCRIPTION_FILE
