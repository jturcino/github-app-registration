
function newVersion {
	NAME=`jq '.name' $1 | tr -d '"'`
        VERSION=`jq '.version' $DESCRIPTION_FILE | tr -d '"'`           # get most version of app

	PREV_ID=`apps-list -n $NAME | head -n1 | awk '{print $1;}'`	# get most recent ID of app with same name
	if [ -z "$PREV_ID" ]; then					# if no previous apps with same name, app is 1st branch commit or 1st master commit
		BRANCH=`basename $(jq '.ref' $WEBHOOK | tr -d '"')`
		if ! [ "$BRANCH" == "master" ]; then			# if is 1st branch commit, get most recent ID of master branch app
			PREV_ID=`apps-list -n ${NAME%-$BRANCH} | head -n1 | awk '{print $1;}'`
		fi
	fi

	# now, have PREV_ID unless 1st commit
	if ! [ -z "$PREV_ID" ]; then					# if not 1st master commit, increment app version (eg 0.1.0 --> 0.1.1)
		let LAST_CHAR="(${PREV_ID: -1} + 1) % 10"
		PREV_VERSION="${PREV_ID: -5}"
		VERSION="${PREV_VERSION:0:-1}$LAST_CHAR"
	else
		VERSION="0.0.1"						# if 1st master commit, default 1st version
	fi
	echo $VERSION							# return updated version
}

tar xzf bin.tgz
export PATH="./bin/:$PATH"

WEBHOOK="${webhookFile}"
CLONE_URL=`jq '.repository.clone_url' $WEBHOOK | tr -d '"'`
REPO_NAME=`basename ${CLONE_URL%%.git}`
DESCRIPTION_FILE="$REPO_NAME/agave.json"

REF=`jq '.ref' $WEBHOOK | tr -d '"'` 			# ref/tags/branch
BRANCH=`basename $REF`					# ref/tags/BRANCH
TAGS=`basename $(dirname $REF)`				# ref/TAGS/branch
CREATED=`jq '.created' $WEBHOOK | tr -d '"'`

IS_RELEASE=false
if [ "$TAGS" == "tags" ]; then 				# this event is a release
	IS_RELEASE=true
	BRANCH=`jq '.base_ref' $WEBHOOK | tr -d '"' | xargs basename`
elif ! [ "$BRANCH" == "master" ] && ! [ $CREATED = false ]; then # this event is the creation of a branch 
	echo "This is not a simple commit or release. Exiting without updating app." >&2
	exit
fi

# clone repo
git clone -b $BRANCH $CLONE_URL

# check for app description
if ! [ -e "$DESCRIPTION_FILE" ]; then
	echo "The repo must contain exactly one agave.json file in the base directory. Exiting." >&2
	exit
fi

# load agave.json as string
# string will be changed (name, insert commit hash, version)
CHANGE_DESCRIPTION_FILE=`cat $DESCRIPTION_FILE`

# append branch name
NAME=`echo $CHANGE_DESCRIPTION_FILE | ./bin/jq '.name' | tr -d '"'`
if [ $IS_RELEASE = false ] && ! [ "$BRANCH" == "master" ] && ! [ "$NAME" == *"-$BRANCH" ]; then
	NAME_REPLACEMENT="$NAME-$BRANCH"

	# update app name
	CHANGE_DESCRIPTION_FILE=`echo $CHANGE_DESCRIPTION_FILE | 
				./bin/jq --arg foo "$NAME_REPLACEMENT" 'to_entries | 
					map(if .key == "name" 
						then . + {"value":$foo} 
						else . 
						end 
					) 
				| from_entries'`
fi

# add commit hash if macro (commithash) in longDescription
LONG_DESCRIPTION=`echo $CHANGE_DESCRIPTION_FILE | ./bin/jq '.longDescription' | tr -d '"'`
if ! [ $IS_RELEASE = true ] && [[ $LONG_DESCRIPTION == *"(commithash)"* ]]; then
	COMMIT_HASH=`jq '.after' $WEBHOOK | tr -d '"'`
	LONG_DESCRIPTION="${LONG_DESCRIPTION//"(commithash)"/$COMMIT_HASH}"

	# update longDescription
	CHANGE_DESCRIPTION_FILE=`echo $CHANGE_DESCRIPTION_FILE | 
				./bin/jq --arg foo "$LONG_DESCRIPTION" 'to_entries | 
					map(if .key == "longDescription" 
						then . + {"value":$foo} 
						else . 
						end 
					) 
				| from_entries'`
fi

# set up version if given (sourceref)
#   if release, use tags
#   if commit (branch or master), increment by on (eg. 0.1.0 --> 0.1.1)
PREV_VERSION=`echo $CHANGE_DESCRIPTION_FILE | jq '.version' | tr -d '"'`
if [ "$PREV_VERSION" == "(sourceref)" ]; then 		# version is to be updated
        if [ $IS_RELEASE = true ]; then 		# if release, use tags (ref/tags/TAGS)
                NEW_VERSION=`basename $REF`
        else						# if commit, use newVersion function to update
                NEW_VERSION=`newVersion $DESCRIPTION_FILE`
        fi

        # update version
	CHANGE_DESCRIPTION_FILE=`echo $CHANGE_DESCRIPTION_FILE | 
				./bin/jq --arg foo "$NEW_VERSION" 'to_entries | 
					map(if .key == "version" 
						then . + {"value":$foo} 
						else . 
						end 
					) 
				| from_entries'`
fi

# replace $DESCRIPTION_FILE with changes
rm $DESCRIPTION_FILE
echo $CHANGE_DESCRIPTION_FILE > $DESCRIPTION_FILE

# register app
apps-addupdate -F $DESCRIPTION_FILE

# remove git repo
rm -rf $REPO_NAME
