println "building ${JDK_VERSION}"

def buildPlatforms = ['Mac', 'Windows', 'Linux', 'ppc64le', 'AIX']
def buildMaps = [:]
buildMaps['Mac'] = [build:true, test:true, ArchOSs:'x86-64_macos']
buildMaps['Windows'] = [build:true, test:false, ArchOSs:'x86-64_windows']
buildMaps['Linux'] = [build:true, test:true, ArchOSs:'x86-64_linux']
buildMaps['zLinux'] = [build:true, test:true, ArchOSs:'s390x_linux']
buildMaps['ppc64le'] = [build:true, test:true, ArchOSs:'ppc64le_linux']
buildMaps['AIX'] = [build:true, test:false, ArchOSs:'ppc64_aix']
def typeTests = ['openjdktest', 'systemtest']

def jobs = [:]
for ( int i = 0; i < buildPlatforms.size(); i++ ) {
	def index = i
	def platform = buildPlatforms[index]
	def archOS = buildMaps[platform].ArchOSs
	jobs[platform] = {
		def buildJob
		stage('build') {
			buildJob = build job: "openjdk8_build_${archOS}"
		}
		if (buildMaps[platform].test) {
			stage('test') {
				typeTests.each {
					build job:"openjdk8_hs_${it}_${archOS}",
							propagate: false,
							parameters: [string(name: 'UPSTREAM_JOB_NUMBER', value: "${buildJob.getNumber()}"),
									string(name: 'UPSTREAM_JOB_NAME', value: "openjdk8_build_${archOS}")]
				}
			}
		}
	}
}
parallel jobs
