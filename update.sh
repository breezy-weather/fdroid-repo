#!/bin/bash

declare -a github_repos=("breezy-weather/breezy-weather:Internet")
declare -a anti_features=("breezy-weather/breezy-weather:NonFreeAssets")
declare -a fastlane_repos=("breezy-weather/breezy-weather")

if [[ ! -d fdroid/metadata ]]; then
	mkdir -p fdroid/metadata
fi

if [[ ! -d fdroid/repo ]]; then
	mkdir -p fdroid/repo
fi

for github_repo in ${github_repos[@]}; do
	repo=$(echo $github_repo | sed 's|:.*||')
	wget -q -O latest https://api.github.com/repos/$repo/releases/latest
	release=$(cat latest | grep tag_name | sed 's/.*tag_name\":\ \"//' | sed 's/\",//')
	changelog="$(cat latest | sed -z 's/"\n}//g' | grep body | sed 's/  "body": "//' | sed 's/",//' | sed 's/\\r//g' | sed 's/\\n/  \n/g')"
	urls=$(cat latest | grep browser_download_url | sed 's/      "browser_download_url": "//' | sed 's/"//')
	url=$(echo "$urls" | grep standard.apk$ | grep -v debug | grep -v arm64-v8a | grep -v armeabi-v7a | grep -v x86 | grep -v x86_64 | head -n 1)
	asset=$(echo $url | head -n 1 | sed 's/.*\///')

	wget -q -O fdroid/repo/$asset $url

	name=$(aapt dump badging fdroid/repo/$asset | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$asset | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$asset | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	for fastlane_repo in ${fastlane_repos[@]}; do
		if [[ $fastlane_repo == $repo  ]]; then
			mkdir -p fdroid/metadata/$id

			git clone https://github.com/$repo

			mv $(echo $repo | sed 's/.*\///')/src/basic/fastlane/metadata/android/* fdroid/metadata/$id/

			rm -rf $(echo $repo | sed 's/.*\///')

			for folder in fdroid/metadata/$id/*; do
				if [[ -d $folder/images ]]; then
					if [[ -d $folder/images/phoneScreenshots ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

						mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
					fi

					if [[ -f $folder/images/icon.png ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

						mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
					fi

					rm -rf $folder/images
				fi

				if [[ -d $folder/changelogs ]]; then
					mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
				fi

				if [[ -f $folder/full_description.txt ]]; then
					mv $folder/full_description.txt $folder/description.txt
				fi

				if [[ -f $folder/short_description.txt ]]; then
					mv $folder/short_description.txt $folder/summary.txt
				fi
			done

			echo "AuthorName: $(echo $github_repo | sed 's|/.*||')
Categories:
    - $(echo $github_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
IssueTracker: https://github.com/$repo/issues
License: LGPL-3.0-only
Name: $name
SourceCode: https://github.com/$repo
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/blob/main/CHANGELOG.md
Translation: https://hosted.weblate.org/projects/breezy-weather/breezy-weather-android/#information

AllowedAPKSigningKeys: 29d435f70aa9aec3c1faff7f7ffa6e15785088d87f06ecfcab9c3cc62dc269d8" | tee -a fdroid/metadata/$id.yml

			wget -q -O releases https://api.github.com/repos/$repo/releases
			urls=$(cat releases | grep -m1 '"prerelease": true,' -B31 -A224 | grep browser_download_url | sed 's/      "browser_download_url": "//' | sed 's/"//')
			url=$(echo "$urls" | grep .apk$ | grep -v debug | grep -v arm64-v8a | grep -v armeabi-v7a | grep -v x86 | grep -v x86_64)
			asset=$(echo $url | sed 's/.*\///')

			if [[ $(cat releases | grep -m1 '"prerelease": true,' -B31 -A224 | grep created_at -m1 | sed 's/.* "//' | sed 's/T.*//' | sed 's/-//g') -ge $(cat latest | grep created_at -m1 | sed 's/.* "//' | sed 's/T.*//' | sed 's/-//g') ]]; then
				wget -q -O fdroid/repo/$asset $url
			fi

			rm latest

			rm releases
		fi
	done

	if [[ ! -f fdroid/metadata/$id.yml ]]; then
		description=""

		wget -q -O repo https://api.github.com/repos/$repo
		if [[ ! $(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//') == *null* ]]; then
			description=$(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//')
		fi

		if [[ -z "$description" ]]; then
			description="$name"
		else
			description="$description"
		fi

		echo "AuthorName: $(echo $github_repo | sed 's|/.*||')
Categories:
    - $(echo $github_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
    $description
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

		mkdir -p fdroid/metadata/$id/en-US/changelogs

		echo "$changelog" | tee fdroid/metadata/$id/en-US/changelogs/$version.txt

		rm repo
	fi

	rm latest
done

cd fdroid

/usr/bin/fdroid update --pretty --delete-unknown --use-date-from-apk

cd ../
