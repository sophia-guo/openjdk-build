println "building ${JDK_VERSION}"

//def buildPlatforms = ['Linux', 'zLinux', 'ppc64le', 'AIX']
def buildPlatforms = ['Linux', 'ppc64le']
def buildMaps = [:]
buildMaps['Linux'] = [test:true, ArchOSs:'x86-64_linux']
buildMaps['zLinux'] = [test:true, ArchOSs:'s390x_linux']
buildMaps['ppc64le'] = [test:true, ArchOSs:'ppc64le_linux']
buildMaps['AIX'] = [test:false, ArchOSs:'ppc64_aix']
//def typeTests = ['openjdktest', 'systemtest']
def typeTests = ['openjdktest']

def jobs = [:]
for ( int i = 0; i < buildPlatforms.size(); i++ ) {
	def index = i
	def platform = buildPlatforms[index]
	def archOS = buildMaps[platform].ArchOSs
	jobs[platform] = {
		def buildJob
		def buildJobNum
		def checksumJob
		stage('build') {
			buildJob = build job: "openjdk9_openj9_build_${archOS}"
			buildJobNum = buildJob.getNumber()
		}
		if (buildMaps[platform].test) {
			stage('test') {
				typeTests.each {
					build job:"openjdk9_j9_${it}_${archOS}",
							propagate: false,
							parameters: [string(name: 'UPSTREAM_JOB_NUMBER', value: "${buildJobNum}"),
									string(name: 'UPSTREAM_JOB_NAME', value: "openjdk9_openj9_build_${archOS}")]
				}
			}
		}
		stage('checksums') {
			checksumJob = build job: 'update_jdk9_openj9_checksum',
							parameters: [string(name: 'SDKBUILDNAME', value: "openjdk9_openj9_build_${archOS}"),
									string(name: 'BUILDNUMBER', value: "${buildJobNum}")]
		}
		stage('publish nightly') {
			build job: 'UpdateTool', 
						parameters: [string(name: 'REPO', value: 'nightly'), 
						string(name: 'TAG', value: 'jdk-9+181'), 
						string(name: 'VERSION', value: 'jdk9-openj9'),
						string(name: 'CHECKSUMBUILDNAME', value: "update_jdk9_openj9_checksum"),
						string(name: 'BUILDNUMBER', value: "${checksumJob.getNumber()}")]
		}
	}
}
parallel jobs

