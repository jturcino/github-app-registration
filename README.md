# github-app-registration

Agave application for updating GitHub-based applications

## Usage

This application updates other Agave applications the information contained in the JSON responses of GitHub webhooks. Currently, the JSON must be passed in as a file when submitting a job.

### Conventions
`github-app-registration` requires an app description file named `agave.json` in the home directory of the GitHub repo. No other files are required, though a wrapper script and test script must be present in the subject app's deployment directory, as per Agave convention.

Additionally, `github-app-registration` will update the subject app version number when the macro `(sourceref)` corresponds to the version number in `agave.json`. This is done is a systematic manner:
* __Releases__ will be updated to their tags
* __Commits__ will have their version incremented by one (eg. 0.1.2 updates to 0.1.3)

If a commit from a branch is given, an new version of the application will be created with the branch name appended onto the app name (eg. `myapp` updates to `myapp-branch`). The commit versioning conventions apply as well.

### Examples
Below are examples for releases, commits, and branch commits. In order to demonstrate app behavior, version in `agave.json` assumed to be `(sourceref)`.

Release:
```
$ apps-list -Q
myapp-0.1.0
$ jobs-submit -F registration-job-release.json
$ apps-list -Q
myapp-0.2.0
myapp-0.1.0
```

Commit:
```
$ apps-list -Q
myapp-0.1.0
$ jobs-submit -F registration-job-commit.json
$ apps-list -Q
myapp-0.1.1
myapp-0.1.0
```

Branch commit:
```
$ apps-list -Q
myapp-0.1.0
$ jobs-submit -F registration-job-branchcommit.json
$ apps-list -Q
myapp-branchname-0.1.1
myapp-0.1.0
```

## Setup

Currently, this is not a publicly available Agave application; therefore, you must clone a copy of this repo and register it as a private application before using it. The following steps will guide you thorugh this process.

### Installation via GitHub
```
$ git clone https://github.com/jturcino/github-app-registration.git
```

### Private app registration
Using the text editor of your choice, change the name, execution system, deployment path, and any other parameters you would like (such as version number) in `agave.json`.
```
{"name":"username-github-app-registration",
 "version":"0.0.1",
 "executionSystem":"your-system",
 "deploymentSystem":"data.iplantcollaborative.org",
 "deploymentPath":"username/apps/github-app-registration/",
...
```

Now, add the application:
```
$ apps-addupdate -F agave.json
```

