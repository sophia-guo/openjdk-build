import java.nio.file.NoSuchFileException
/*
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

String javaVersion = "jdk12"

node ("master") {
  try {
    def scmVars = checkout scm
    load "${WORKSPACE}/pipelines/build/common/import_lib.groovy"
  
    // Load buildConfigurations from config file. This is what the nightlies & releases use to setup their downstream jobs
    def buildConfigurations = null
    def buildConfigPath = "${WORKSPACE}/pipelines/jobs/configurations/${javaVersion}_pipeline_config.groovy"
    try {
      buildConfigurations = load buildConfigPath
    } catch (NoSuchFileException e) {
      javaVersion = javaVersion + "u"
      println "[INFO] ${buildConfigPath} does not exist, chances are we want a ${javaVersion} repo.\n[INFO] Trying ${WORKSPACE}/pipelines/jobs/configurations/${javaVersion}_pipeline_config.groovy..."

      buildConfigurations = load "${WORKSPACE}/pipelines/jobs/configurations/${javaVersion}_pipeline_config.groovy"
    }

    if (buildConfigurations != null) {
      println "[INFO] Found buildConfigurations:\n$buildConfigurations"
    }
    else {
      throw new Exception("[ERROR] Could not find buildConfigurations for ${javaVersion}")
    }

    // Load targetConfigurations from config file. This is what is being run in the nightlies
    load "${WORKSPACE}/pipelines/jobs/configurations/${javaVersion}.groovy"

    println "[INFO] Found targetConfigurations:\n$targetConfigurations"

    Closure regenerationScript = load "${WORKSPACE}/pipelines/build/common/config_regeneration.groovy"

    println "[INFO] Running regeneration script..."
    regenerationScript(
            javaVersion,
            buildConfigurations,
            targetConfigurations,
            currentBuild,
            this,
            null,
            null,
            null,
            null
    ).regenerate()
      
    println "[SUCCESS] All done!"

  } finally {
    // Always clean up, even on failure (doesn't delete the dsls)
    println "[INFO] Cleaning up..."
    cleanWs()
  }

}
