#!/bin/bash
# shellcheck disable=SC2086
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
###############################################################################

# Expand JDK jmods & zips to process binaries within
function expandJDK() {
  local JDK_DIR="$1"
  local OS="$2"
  local JDK_ROOT="$1"
  local JDK_BIN_DIR="${JDK_ROOT}_CP/bin"
  if [[ "$OS" =~ Darwin* ]]; then
    JDK_ROOT=$(realpath ${JDK_DIR}/../../)
    JDK_BIN_DIR="${JDK_ROOT}_CP/Contents/Home/bin"
  fi

  mkdir "${JDK_ROOT}_CP"
  cp -R ${JDK_ROOT}/* ${JDK_ROOT}_CP
  echo "Expanding the 'modules' Image to remove signatures from within.."
  ls -l "${JDK_DIR}/lib/modules"
  cd "${JDK_DIR}/lib/"
  "${JDK_BIN_DIR}/jimage" extract --dir "${JDK_DIR}/lib/modules_extracted" "modules"
  cd ../..
  #"${JDK_BIN_DIR}/jimage" extract --dir "${JDK_DIR}/lib/modules_extracted" "${JDK_DIR}/lib/modules"
  rm "${JDK_DIR}/lib/modules"
  echo "Expanding the 'src.zip' to normalize file permissions"
  unzip "${JDK_DIR}/lib/src.zip" -d "${JDK_DIR}/lib/src_zip_expanded" 1> /dev/null
  rm "${JDK_DIR}/lib/src.zip"

  echo "Expanding jmods to process binaries within"
  FILES=$(find "${JDK_DIR}" -type f -path '*.jmod')
  currentDir=`pwd`
  for f in $FILES
    do
      base=$(basename "$f")
      dir=$(dirname "$f")
      expand_dir="${dir}/expanded_${base}"
      mkdir -p "${expand_dir}"
      ls -l "$f"
      cd "${dir}"
     # "${JDK_BIN_DIR}/jmod" extract --dir "${expand_dir}" "$f"
      "${JDK_BIN_DIR}/jmod" extract --dir "${expand_dir}" "$base"
      cd $currentDir
    done

  echo "Expanding the 'jrt-fs.jar' to remove signatures from within.."
  mkdir "${JDK_DIR}/lib/jrt-fs-expanded"
  cd "${JDK_DIR}/lib/"
  unzip -d "${JDK_DIR}/lib/jrt-fs-expanded" "jrt-fs.jar" 1> /dev/null
  rm "${JDK_DIR}/lib/jrt-fs.jar"

  mkdir -p "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs-expanded"
  cd "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/"
  unzip -d "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs-expanded" "jrt-fs.jar" 1> /dev/null
  rm "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs.jar"
}

# Remove all Signatures
function removeSignatures() {
  local JDK_DIR="$1"
  local OS="$2"

  if [[ "$OS" =~ CYGWIN* ]]; then
    signToolPath="/cygdrive/c/Program Files (x86)/Windows Kits/10/bin/10.0.17763.0/x64/signtool.exe"
    echo "Removing all Signatures from ${JDK_DIR}"
    FILES=$(find "${JDK_DIR}" -type f -name '*.exe' -o -name '*.dll')
    currentDir=`pwd`
    for f in $FILES
     do
      echo "Removing signature from $f"
      base=$(basename "$f")
      dir=$(dirname "$f")
      cd $dir
      if "$signToolPath" remove /s /v "$base"; then
          echo "  ==> Successfully removed signature from $base"
      else
          echo "  ==> $f contains no signature"
      fi
      cd $currentDir
     done
  elif [[ "$OS" =~ Darwin* ]]; then
    MAC_JDK_ROOT="${JDK_DIR}/../.."
    echo "Removing all Signatures from ${MAC_JDK_ROOT}"

    if [ ! -d "${MAC_JDK_ROOT}/Contents" ]; then
        echo "Error: ${MAC_JDK_ROOT} does not contain the MacOS JDK Contents directory"
        exit 1
    fi

    # Remove any extended app attr
    xattr -c "${MAC_JDK_ROOT}"

    FILES=$(find "${MAC_JDK_ROOT}" \( -type f -and -path '*.dylib' -or -path '*/bin/*' -or -path '*/lib/jspawnhelper' -not -path '*/modules_extracted/*' -or -path '*/jpackageapplauncher*' \))
    for f in $FILES
    do
        echo "Removing signature from $f"
        codesign --remove-signature "$f" 1> /dev/null
    done
  fi
}

# Sign with temporary Signature, which when removed results in determinisitic binary length
function tempSign() {
  local JDK_DIR="$1"
  local OS="$2"

  if [[ "$OS" =~ CYGWIN* ]]; then
    signToolPath="/cygdrive/c/Program Files (x86)/Windows Kits/10/bin/10.0.17763.0/x64/signtool.exe"
    echo "Adding temp Signatures for ${JDK_DIR}"
    selfCert="test"
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout $selfCert.key -out $selfCert.crt -subj "/CN=example.com" -addext "subjectAltName=DNS:example.com,DNS:*.example.com,IP:10.0.0.1"
    openssl pkcs12 -export -passout pass:test -out $selfCert.pfx -inkey $selfCert.key -in $selfCert.crt
    echo "Signing test"
    FILES=$(find "${JDK_DIR}" -type f -name '*.exe' -o -name '*.dll')
    for f in $FILES
     do
      echo "Signing $f"
      winPathFile=`cygpath -w $f`
      if "$signToolPath" sign /f $selfCert.pfx /p test /fd SHA256 $winPathFile; then
          echo "  ==> Successfully signed $winPathFile"
      else
          echo "  ==> $winPathFile failed to be signed!!"
          exit 1
      fi
     done
  elif [[ "$OS" =~ Darwin* ]]; then
    MAC_JDK_ROOT="${JDK_DIR}/../../Contents"
    echo "Adding temp Signatures for ${MAC_JDK_ROOT}"
    #TODO Generate locally certificate SELF_CERT

    FILES=$(find "${MAC_JDK_ROOT}" \( -type f -and -path '*.dylib' -or -path '*/bin/*' -or -path '*/lib/jspawnhelper' -not -path '*/modules_extracted/*' -or -path '*/jpackageapplauncher*' \))
    for f in $FILES
    do
        echo "Signing $f with a local certificate"
        # Sign both with same local Certificate, this adjusts __LINKEDIT vmsize identically
        codesign -s "$SELF_CERT" --options runtime -f --timestamp "$f"
    done
  fi
}

# If performing a reproducible compare to a non temurin build-scripts built JDK
# then remove certain Temurin build-script added metadata or different files
function cleanTemurinFiles() {
  local DIR="$1"

  echo "Cleaning Temurin build-scripts specific files and metadata from ${DIR}"

  echo "Removing Temurin NOTICE file from $DIR"
  rm "${DIR}"/NOTICE

  if [[ $(uname) =~ Darwin* ]]; then
    echo "Removing Temurin specific lines from release file in $DIR"
    sed -i "" '/^BUILD_SOURCE=.*$/d' "${DIR}/release"
    sed -i "" '/^BUILD_SOURCE_REPO=.*$/d' "${DIR}/release"
    sed -i "" '/^SOURCE_REPO=.*$/d' "${DIR}/release"
    sed -i "" '/^FULL_VERSION=.*$/d' "${DIR}/release"
    sed -i "" '/^SEMANTIC_VERSION=.*$/d' "${DIR}/release"
    sed -i "" '/^BUILD_INFO=.*$/d' "${DIR}/release"
    sed -i "" '/^JVM_VARIANT=.*$/d' "${DIR}/release"
    sed -i "" '/^JVM_VERSION=.*$/d' "${DIR}/release"
    sed -i "" '/^IMAGE_TYPE=.*$/d' "${DIR}/release"
  
    echo "Removing SOURCE= from ${DIR}/release file, as Temurin builds from Adoptium mirror repo _adopt tag"
    sed -i "" '/^SOURCE=.*$/d' "${DIR}/release"
  else
    echo "Removing Temurin specific lines from release file in $DIR"
    sed -i '/^BUILD_SOURCE=.*$/d' "${DIR}/release"
    sed -i '/^BUILD_SOURCE_REPO=.*$/d' "${DIR}/release"
    sed -i '/^SOURCE_REPO=.*$/d' "${DIR}/release"
    sed -i '/^FULL_VERSION=.*$/d' "${DIR}/release"
    sed -i '/^SEMANTIC_VERSION=.*$/d' "${DIR}/release"
    sed -i '/^BUILD_INFO=.*$/d' "${DIR}/release"
    sed -i '/^JVM_VARIANT=.*$/d' "${DIR}/release"
    sed -i '/^JVM_VERSION=.*$/d' "${DIR}/release"
    sed -i '/^IMAGE_TYPE=.*$/d' "${DIR}/release"

    echo "Removing SOURCE= from ${DIR}/release file, as Temurin builds from Adoptium mirror repo _adopt tag"
    sed -i '/^SOURCE=.*$/d' "${DIR}/release"
  fi

  echo "Removing cacerts file, as Temurin builds with different Mozilla cacerts"
  find "${DIR}" -type f -name "cacerts" -delete

  echo "Removing any JDK image files not shipped by Temurin(*.pdb, *.pdb, demo) in $DIR"
  find "${DIR}" -type f -name "*.pdb" -delete
  find "${DIR}" -type f -name "*.map" -delete
  rm -rf "${DIR}/demo"
}

# Temurin release file metadata BUILD_INFO/SOURCE can/will be different
function cleanTemurinBuildInfo() {
  local DIR="$1"
  
  echo "Cleaning any Temurin build-scripts release file BUILD_INFO from ${DIR}"

  if [[ $(uname) =~ Darwin* ]]; then
    sed -i "" '/^BUILD_SOURCE=.*$/d' "${DIR}/release"
    sed -i "" '/^BUILD_SOURCE_REPO=.*$/d' "${DIR}/release"
    sed -i "" '/^BUILD_INFO=.*$/d' "${DIR}/release"
  else
    sed -i '/^BUILD_SOURCE=.*$/d' "${DIR}/release"
    sed -i '/^BUILD_SOURCE_REPO=.*$/d' "${DIR}/release" 
    sed -i '/^BUILD_INFO=.*$/d' "${DIR}/release"
  fi
}

# Patch the Vendor strings from the BootJDK in jrt-fs/jar MANIFEST
function patchManifests() {
  local JDK_DIR="$1"

  if [[ $(uname) =~ Darwin* ]]; then
    echo "Removing jrt-fs.jar MANIFEST.MF BootJDK vendor string lines"
    sed -i "" '/^Implementation-Vendor:.*$/d' "${JDK_DIR}/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
    sed -i "" '/^Created-By:.*$/d' "${JDK_DIR}/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
    sed -i "" '/^Implementation-Vendor:.*$/d' "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
    sed -i "" '/^Created-By:.*$/d' "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
  else
    echo "Removing jrt-fs.jar MANIFEST.MF BootJDK vendor string lines"
    sed -i '/^Implementation-Vendor:.*$/d' "${JDK_DIR}/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
    sed -i '/^Created-By:.*$/d' "${JDK_DIR}/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
    sed -i '/^Implementation-Vendor:.*$/d' "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
    sed -i '/^Created-By:.*$/d' "${JDK_DIR}/jmods/expanded_java.base.jmod/lib/jrt-fs-expanded/META-INF/MANIFEST.MF"
  fi
}

