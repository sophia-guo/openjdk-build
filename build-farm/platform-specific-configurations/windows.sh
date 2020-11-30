#!/bin/bash

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

export ANT_HOME=/cygdrive/C/Projects/OpenJDK/apache-ant-1.10.1
export ALLOW_DOWNLOADS=true
export LANG=C
export OPENJ9_NASM_VERSION=2.13.03

TOOLCHAIN_VERSION=""

# Any version above 8 (11 for now due to openjdk-build#1409
if [ "$JAVA_FEATURE_VERSION" -gt 11 ]; then
    BOOT_JDK_VERSION="$((JAVA_FEATURE_VERSION-1))"
    BOOT_JDK_VARIABLE="JDK$(echo $BOOT_JDK_VERSION)_BOOT_DIR"
    if [ ! -d "$(eval echo "\$$BOOT_JDK_VARIABLE")" ]; then
      bootDir="$PWD/jdk-$BOOT_JDK_VERSION"
      # Note we export $BOOT_JDK_VARIABLE (i.e. JDKXX_BOOT_DIR) here
      # instead of BOOT_JDK_VARIABLE (no '$').
      export ${BOOT_JDK_VARIABLE}="$bootDir"
      if [ ! -d "$bootDir/bin" ]; then
        echo "Downloading GA release of boot JDK version ${BOOT_JDK_VERSION}..."
        releaseType="ga"
        # This is needed to convert x86-32 to x32 which is what the API uses
        case "$ARCHITECTURE" in
          "x86-32") downloadArch="x32";;
          *) downloadArch="$ARCHITECTURE";;
        esac
        apiUrlTemplate="https://api.adoptopenjdk.net/v3/binary/latest/\${BOOT_JDK_VERSION}/\${releaseType}/windows/\${downloadArch}/jdk/\${VARIANT}/normal/adoptopenjdk"
        apiURL=$(eval echo ${apiUrlTemplate})
        # make-adopt-build-farm.sh has 'set -e'. We need to disable that
        # for the fallback mechanism, as downloading of the GA binary might
        # fail.
        set +e
        wget -q "${apiURL}" -O openjdk.zip
        retVal=$?
        set -e
        if [ $retVal -ne 0 ]; then
          # We must be a JDK HEAD build for which no boot JDK exists other than
          # nightlies?
          echo "Downloading GA release of boot JDK version ${BOOT_JDK_VERSION} failed."
          echo "Attempting to download EA release of boot JDK version ${BOOT_JDK_VERSION} ..."
          # shellcheck disable=SC2034
          releaseType="ea"
          apiURL=$(eval echo ${apiUrlTemplate})
          wget -q "${apiURL}" -O openjdk.zip
        fi
        unzip -q openjdk.zip
        mv $(ls -d jdk-${BOOT_JDK_VERSION}*) "$bootDir"
      fi
    fi
    export JDK_BOOT_DIR="$(eval echo "\$$BOOT_JDK_VARIABLE")"
    "$JDK_BOOT_DIR/bin/java" -version
    executedJavaVersion=$?
    if [ $executedJavaVersion -ne 0 ]; then
        echo "Failed to obtain or find a valid boot jdk"
        exit 1
    fi
    "$JDK_BOOT_DIR/bin/java" -version 2>&1 | sed 's/^/BOOT JDK: /'
fi

if [ "${ARCHITECTURE}" == "x86-32" ]
then
  export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache --with-target-bits=32 --target=x86"

  if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]
  then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-openssl=/cygdrive/c/openjdk/OpenSSL-1.1.1h-x86_32-VS2013 --enable-openssl-bundling"
    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar"
      # https://github.com/AdoptOpenJDK/openjdk-build/issues/243
      export INCLUDE="C:\Program Files\Debugging Tools for Windows (x64)\sdk\inc;$INCLUDE"
      export PATH="/c/cygwin64/bin:/usr/bin:$PATH"
      TOOLCHAIN_VERSION="2013"
    elif [ "${JAVA_TO_BUILD}" == "${JDK11_VERSION}" ]
    then
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar"

      # Next line a potentially tactical fix for https://github.com/AdoptOpenJDK/openjdk-build/issues/267
      export PATH="/usr/bin:$PATH"
    fi
    # LLVM needs to be before cygwin as at least one machine has 64-bit clang in cygwin #813
    # NASM required for OpenSSL support as per #604
    export PATH="/cygdrive/c/Program Files (x86)/LLVM/bin:/cygdrive/c/openjdk/nasm-$OPENJ9_NASM_VERSION:$PATH"
  else
    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      TOOLCHAIN_VERSION="2013"
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export PATH="/cygdrive/c/openjdk/make-3.82/:$PATH"
    elif [ "${JAVA_TO_BUILD}" == "${JDK11_VERSION}" ]
    then
      TOOLCHAIN_VERSION="2013"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    elif [ "$JAVA_FEATURE_VERSION" -gt 11 ]
    then
      TOOLCHAIN_VERSION="2017"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    fi
  fi
fi

if [ "${ARCHITECTURE}" == "x64" ]
then
  if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]
  then
    export HAS_AUTOCONF=1
    export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"

    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export INCLUDE="C:\Program Files\Debugging Tools for Windows (x64)\sdk\inc;$INCLUDE"
      export PATH="$PATH:/c/cygwin64/bin"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar --disable-ccache"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-openssl=/cygdrive/c/openjdk/OpenSSL-1.1.1h-x86_64-VS2013 --enable-openssl-bundling"
      TOOLCHAIN_VERSION="2013"
    elif [ "${JAVA_TO_BUILD}" == "${JDK9_VERSION}" ]
    then
      TOOLCHAIN_VERSION="2013"
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar"
    elif [ "${JAVA_TO_BUILD}" == "${JDK10_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar"
    elif [ "$JAVA_FEATURE_VERSION" -ge 11 ]
    then
      TOOLCHAIN_VERSION="2017"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar --with-openssl=/cygdrive/c/openjdk/OpenSSL-1.1.1h-x86_64-VS2017 --enable-openssl-bundling"
    fi

    CUDA_VERSION=9.0
    CUDA_HOME="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v$CUDA_VERSION"
    # use cygpath to map to 'short' names (without spaces)
    CUDA_HOME=$(cygpath -ms "$CUDA_HOME")
    if [ -f "$(cygpath -u $CUDA_HOME/include/cuda.h)" ]
    then
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --enable-cuda --with-cuda=$CUDA_HOME"
    fi

    # LLVM needs to be before cygwin as at least one machine has clang in cygwin #813
    # NASM required for OpenSSL support as per #604
    export PATH="/cygdrive/c/Program Files/LLVM/bin:/usr/bin:/cygdrive/c/openjdk/nasm-$OPENJ9_NASM_VERSION:$PATH"
  else
    TOOLCHAIN_VERSION="2013"
    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export PATH="/cygdrive/c/openjdk/make-3.82/:$PATH"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    elif [ "${JAVA_TO_BUILD}" == "${JDK9_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    elif [ "${JAVA_TO_BUILD}" == "${JDK10_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    elif [ "$JAVA_FEATURE_VERSION" -ge 11 ]
    then
      TOOLCHAIN_VERSION="2017"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    fi
  fi
fi

if [ ! -z "${TOOLCHAIN_VERSION}" ]; then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-toolchain-version=${TOOLCHAIN_VERSION}"
fi
