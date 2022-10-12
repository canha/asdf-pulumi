#!/usr/bin/env bash

# Copyright (C) 2019-2020 Jorge Canha
#
# This file is part of asdf-pulumi.
#
# asdf-pulumi is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# asdf-pulumi is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with asdf-pulumi.  If not, see <http://www.gnu.org/licenses/>.

set -euo pipefail

GH_REPO="https://github.com/pulumi/pulumi"
TOOL_NAME="pulumi"
TOOL_TEST="pulumi version"

get_platform() {
  local uname_platform="$(uname)"

  case "${uname_platform}" in
  "Darwin")
    echo "darwin"
    ;;

  "Linux")
    echo "linux"
    ;;

  *)
    echo "Platform ${uname_platform} is not supported."
    exit 1
    ;;
  esac
}

get_architecture() {
  local uname_arch="$(uname -m)"

  case "${uname_arch}" in
  "arm64" | "aarch64")  # Mac M1 and Linux ARM
    echo "arm64"
    ;;

  "x86_64")
    echo "x64"
    ;;

  *)
    echo "Architecture ${uname_arch} is not supported."
    exit 1
    ;;
  esac
}


fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if pulumi is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# NOTE: You might want to adapt this sed to remove non-version strings from tags
list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/v.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

download_release() {
  local version filename url
  version="$1"
  file_basename="$2"
  filename="$3"

  url="$GH_REPO/releases/download/v${version}/${file_basename}"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "${filename}" -C - "$url" || fail "Could not download $url"
}

install_version() {



  local install_type="$1"
  local version="$2"
  local install_path="$3"
  local bin_install_path="${install_path}/bin"
  echo "$1" ... "$2" ... "$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "${bin_install_path}"
    cp -r "${ASDF_DOWNLOAD_PATH}"/* "${bin_install_path}"

    # Asert pulumi executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "${bin_install_path}/${tool_cmd}" || fail "Expected ${bin_install_path}/${tool_cmd} to be executable."
    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
