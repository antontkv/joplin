#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

IS_PULL_REQUEST=0
IS_DEV_BRANCH=0
IS_LINUX=0
IS_MACOS=0

if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
	IS_PULL_REQUEST=1
fi

if [ "$GITHUB_REF" == "refs/heads/dev" ]; then
	IS_DEV_BRANCH=1
fi

if [ "$RUNNER_OS" == "Linux" ]; then
	IS_LINUX=1
	IS_MACOS=0
else
	IS_LINUX=0
	IS_MACOS=1
fi

echo "GITHUB_WORKFLOW=$GITHUB_WORKFLOW"
echo "GITHUB_EVENT_NAME=$GITHUB_EVENT_NAME"
echo "GITHUB_REF=$GITHUB_REF"
echo "RUNNER_OS=$RUNNER_OS"

echo "IS_PULL_REQUEST=$IS_PULL_REQUEST"
echo "IS_DEV_BRANCH=$IS_DEV_BRANCH"
echo "IS_LINUX=$IS_LINUX"
echo "IS_MACOS=$IS_MACOS"

cd "$SCRIPT_DIR/.."

echo "Node $( node -v )"
echo "Npm $( npm -v )"

npm install

# Run test units. Only do it for pull requests and dev branch because we don't
# want it to randomly fail when trying to create a desktop release.

if [ "$IS_PULL_REQUEST" == "1" ] || [ "$IS_DEV_BRANCH" = "1" ]; then
	npm run test-ci
	testResult=$?
	if [ $testResult -ne 0 ]; then
		exit $testResult
	fi
fi

# Run linter for pull requests only. We also don't want this to make the desktop
# release randomly fail.

if [ "$IS_PULL_REQUEST" != "1" ]; then
	npm run linter-ci ./
	testResult=$?
	if [ $testResult -ne 0 ]; then
		exit $testResult
	fi
fi

# Validate translations - this is needed as some users manually
# edit .po files (and often make mistakes) instead of using a proper
# tool like poedit. Doing it for Linux only is sufficient.

if [ "$IS_PULL_REQUEST" == "1" ]; then
	if [ "$IS_LINUX" == "1" ]; then
		node packages/tools/validate-translation.js
		testResult=$?
		if [ $testResult -ne 0 ]; then
			exit $testResult
		fi
	fi
fi

# Find out if we should run the build or not. Electron-builder gets stuck when
# building PRs so we disable it in this case. The Linux build should provide
# enough info if the app builds or not.
# https://github.com/electron-userland/electron-builder/issues/4263

if [ "$IS_PULL_REQUEST" == "1" ]; then
	if [ "$IS_MACOS" == "1" ]; then
		exit 0
	fi
fi