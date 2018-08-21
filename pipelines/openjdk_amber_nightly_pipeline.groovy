println "building ${JDK_VERSION}"

def buildPlatforms = ['Mac', 'Linux', 'Windows']
def buildMaps = [:]
def PIPELINE_TIMESTAMP = new Date(currentBuild.startTimeInMillis).format("yyyyMMddHHmm")

buildMaps['Mac'] = [test:['openjdktest'], ArchOSs:'x86-64_macos']
buildMaps['Windows'] = [test:false, ArchOSs:'x86-64_windows']
buildMaps['Linux'] = [test:['openjdktest'], ArchOSs:'x86-64_linux']

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
			buildJob = build job: "openjdk_amber_build_${archOS}",
					parameters: [string(name: 'PIPELINE_TIMESTAMP', value: "${PIPELINE_TIMESTAMP}")]
			buildJobNum = buildJob.getNumber()
		}
		if (buildMaps[platform].test) {
			stage('test') {
				buildMaps[platform].test.each {
					build job:"amber-rsl_hs_${it}_${archOS}",
							propagate: false,
							parameters: [string(name: 'UPSTREAM_JOB_NUMBER', value: "${buildJobNum}"),
									string(name: 'UPSTREAM_JOB_NAME', value: "openjdk_amber_build_${archOS}"),
									string(name: 'OPENJDK_IMPL', value: 'hotspot')]
				}
			}
		}
		stage('checksums') {
			checksumJob = build job: 'openjdk_amber_build_checksum',
							parameters: [string(name: 'UPSTREAM_JOB_NUMBER', value: "${buildJobNum}"),
									string(name: 'UPSTREAM_JOB_NAME', value: "openjdk_amber_build_${archOS}")]
		}
		stage('publish nightly') {
			build job: 'openjdk_release_tool',
						parameters: [string(name: 'REPO', value: 'nightly'),
									string(name: 'TAG', value: "${JDK_TAG}"),
									string(name: 'VERSION', value: 'jdk-amber'),
									string(name: 'CHECKSUM_JOB_NAME', value: "openjdk_amber_build_checksum"),
									string(name: 'CHECKSUM_JOB_NUMBER', value: "${checksumJob.getNumber()}")]
		}
	}
}
parallel jobs
