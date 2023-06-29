#!/bin/bash
# shellcheck disable=SC1091,SC2140

################################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=sbin/common/constants.sh
source "$SCRIPT_DIR/../../sbin/common/constants.sh"

export MACOSX_DEPLOYMENT_TARGET=10.9
export BUILD_ARGS="${BUILD_ARGS}"

if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
then
  XCODE_SWITCH_PATH="/Applications/Xcode.app"
  export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-toolchain-type=clang"
  if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]; then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-openssl=fetched --enable-openssl-bundling"
    export BUILD_ARGS="${BUILD_ARGS} --skip-freetype"
  fi
else
  if [[ "$JAVA_FEATURE_VERSION" -ge 17 ]] || [[ "${ARCHITECTURE}" == "aarch64" ]]; then
    # JDK17 requires metal (included in full xcode) as does JDK11 on aarch64
    XCODE_SWITCH_PATH="/Applications/Xcode.app"
  else
    # Command line tools used from JDK9-JDK16
    XCODE_SWITCH_PATH="/";
  fi
  export PATH="/Users/jenkins/ccache-3.2.4:$PATH"
  if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]; then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-openssl=fetched --enable-openssl-bundling"
  else
    if [ "${ARCHITECTURE}" == "x64" ]; then
      # We can only target 10.9 on intel macs
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-extra-cxxflags=-mmacosx-version-min=10.9"
    elif [ "${ARCHITECTURE}" == "aarch64" ]; then
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --openjdk-target=aarch64-apple-darwin"
    fi
  fi
fi

# The configure option '--with-macosx-codesign-identity' is supported in JDK8 OpenJ9 and JDK11 and JDK14+
if [[ ( "$JAVA_FEATURE_VERSION" -eq 11 ) || ( "$JAVA_FEATURE_VERSION" -ge 14 ) ]]
then
  export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-sysroot=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/"
  ## Login to KeyChain
  ## shellcheck disable=SC2046
  ## shellcheck disable=SC2006
  #security unlock-keychain -p `cat ~/.password` login.keychain-db
  #rm -rf codesign-test && touch codesign-test
  #codesign --sign "Developer ID Application: London Jamocha Community CIC" codesign-test
  #codesign -dvvv codesign-test
  #export BUILD_ARGS="${BUILD_ARGS} --codesign-identity 'Developer ID Application: London Jamocha Community CIC'"
fi

echo "[WARNING] You may be asked for your su user password, attempting to switch Xcode version to ${XCODE_SWITCH_PATH}"
sudo xcode-select --switch "${XCODE_SWITCH_PATH}"

# No MacOS builds available of OpenJDK 7, OpenJDK 8 can boot itself just fine.
if [ "${JDK_BOOT_VERSION}" == "7" ]; then
  echo "No jdk7 boot JDK available on MacOS using jdk8"
  JDK_BOOT_VERSION="8"
fi
BOOT_JDK_VARIABLE="JDK${JDK_BOOT_VERSION}_BOOT_DIR"
if [ ! -d "$(eval echo "\$$BOOT_JDK_VARIABLE")" ]; then
  bootDir="$PWD/jdk-$JDK_BOOT_VERSION"
  # Note we export $BOOT_JDK_VARIABLE (i.e. JDKXX_BOOT_DIR) here
  # instead of BOOT_JDK_VARIABLE (no '$').
  export "${BOOT_JDK_VARIABLE}"="$bootDir/Contents/Home"
  if [ ! -x "$bootDir/Contents/Home/bin/javac" ]; then
    # To support multiple vendor names we set a jdk-* symlink pointing to the actual boot JDK
    if [ -x "/Library/Java/JavaVirtualMachines/jdk-${JDK_BOOT_VERSION}/Contents/Home/bin/javac" ]; then
      echo "Could not use ${BOOT_JDK_VARIABLE} - using /Library/Java/JavaVirtualMachines/jdk-${JDK_BOOT_VERSION}/Contents/Home"
      export "${BOOT_JDK_VARIABLE}"="/Library/Java/JavaVirtualMachines/jdk-${JDK_BOOT_VERSION}/Contents/Home"
    elif [ "$JDK_BOOT_VERSION" -ge 8 ]; then # Adoptium has no build pre-8
      mkdir -p "$bootDir"
      for releaseType in "ga" "ea"
      do
        # shellcheck disable=SC2034
        for vendor1 in "adoptium" "adoptopenjdk"
        do
          # shellcheck disable=SC2034
          for vendor2 in "eclipse" "adoptium" "adoptopenjdk"
          do
            apiUrlTemplate="https://api.\${vendor1}.net/v3/binary/latest/\${JDK_BOOT_VERSION}/\${releaseType}/mac/\${ARCHITECTURE}/jdk/hotspot/normal/\${vendor2}"
            apiURL=$(eval echo ${apiUrlTemplate})
            echo "Downloading ${releaseType} release of boot JDK version ${JDK_BOOT_VERSION} from ${apiURL}"
            set +e
            wget -q -O "${JDK_BOOT_VERSION}.tgz" "${apiURL}" && tar xpzf "${JDK_BOOT_VERSION}.tgz" --strip-components=1 -C "$bootDir" && rm "${JDK_BOOT_VERSION}.tgz"
            retVal=$?
            set -e
            if [ $retVal -eq 0 ]; then
              break 3
            fi
          done
        done
      done
    fi
  fi
fi

# shellcheck disable=SC2155
export JDK_BOOT_DIR="$(eval echo "\$$BOOT_JDK_VARIABLE")"
"$JDK_BOOT_DIR/bin/java" -version 2>&1 | sed 's/^/BOOT JDK: /'
"$JDK_BOOT_DIR/bin/java" -version > /dev/null 2>&1
executedJavaVersion=$?
if [ $executedJavaVersion -ne 0 ]; then
  echo "Failed to obtain or find a valid boot jdk"
  exit 1
fi

if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]; then
  # Needed for the later nasm
  export PATH=/usr/local/bin:$PATH
  # ccache causes too many errors (either the default version on 3.2.4) so disabling
  export CONFIGURE_ARGS_FOR_ANY_PLATFORM="--disable-ccache ${CONFIGURE_ARGS_FOR_ANY_PLATFORM}"
  export MACOSX_DEPLOYMENT_TARGET=10.9.0
  if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
  then
    export SED=gsed
    export TAR=gtar
    export SDKPATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
  fi
fi
