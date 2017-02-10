
function newVersion {
	NAME=`jq '.name' $1 | tr -d '"'`
	PREV_ID=`apps-list -n $NAME | head -n1 | awk '{print $1;}'`
	let LAST_CHAR="(${PREV_ID: -1} + 1) % 10"
	PREV_VERSION="${PREV_ID: -5}"
	NEW_VERSION="${PREV_VERSION:0:-1}$LAST_CHAR"
	echo $NEW_VERSION
}

WEBHOOK="${webhookFile}"
CLONE_URL=`jq '.repository.clone_url' $WEBHOOK | tr -d '"'`
REPO_NAME=`basename ${CLONE_URL%%.git}`
DESCRIPTION_FILE="$REPO_NAME/agave.json"

REF=`jq '.ref' $WEBHOOK | tr -d '"'` 			# ref/tags/branch
BRANCH=`basename $REF`					# ref/tags/BRANCH
CHECK_TAGS=`basename $(dirname $REF)`			# ref/TAGS/branch
CREATED=`jq '.created' $WEBHOOK | tr -d '"'`

IS_RELEASE=false
if [ "$CHECK_TAGS" == "tags" ]; then
	IS_RELEASE=true
elif ! [ "$BRANCH" == "master" ] && ! [ $CREATED = false ]; then
	echo "This is not a simple commit or release. Exiting without updating app."
	exit
fi

# clone repo
#git clone $CLONE_URL
git clone -b $BRANCH $CLONE_URL

# check for app description
if ! [ -e "$DESCRIPTION_FILE" ]; then
	echo "The repo must contain exactly one agave.json file in the base directory. Exiting."
	exit
fi

# set up version
PREV_VERSION=`jq '.version' $DESCRIPTION_FILE | tr -d '"'`
if [[ "$PREV_VERSION" == "(sourceref)" ]]; then
	if [ $IS_RELEASE = true ]; then
		REPLACEMENT=`basename $REF`
	else
		REPLACEMENT=`newVersion $DESCRIPTION_FILE`
	fi

	# update description file
        NEW_VERSION="${PREV_VERSION/(sourceref)/$REPLACEMENT}"
	CHANGE_DESCRIPTION_FILE=`jq --arg foo $NEW_VERSION '.version = $foo' $DESCRIPTION_FILE`
	rm $DESCRIPTION_FILE
	echo $CHANGE_DESCRIPTION_FILE >> $DESCRIPTION_FILE
fi

# append branch name
NAME=`jq '.name' $DESCRIPTION_FILE | tr -d '"'`
if ! [ "$BRANCH" == "master" ] && ! [ "$NAME" == *"-$BRANCH" ]; then
	NAME_REPLACEMENT="$NAME-$BRANCH"
	CHANGE_DESCRIPTION_FILE=`jq --arg foo $NAME_REPLACEMENT '.name = $foo' $DESCRIPTION_FILE`
	rm $DESCRIPTION_FILE
	echo $CHANGE_DESCRIPTION_FILE >> $DESCRIPTION_FILE
fi

# register app
apps-addupdate -F $DESCRIPTION_FILE

# remove git repo
rm -rf $REPO_NAME
