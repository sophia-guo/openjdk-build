stage ('build OpenJDK') {
    def Platforms = [:]
    Platforms["Linux"] = {
        node {
            build job: 'openjdk9_build_x86-64_linux', propagate: false
        }
    }
    Platforms["Windows"] = {
        node {
            build job: 'openjdk9_build_x86-64_windows'
        }
    }
    Platforms["s390x"] = {
        node {
            build job: 'openjdk9_build_s390x_linux'
        }
    }
    Platforms["arm64"] = {
        node {
            build job: 'openjdk9_build_arm64_linux'
        }
    }
    Platforms["ppc64le"] = {
        node {
            build job: 'openjdk9_build_ppc64le_linux'
        }
    }
    Platforms["mac"] = {
        node {
            build job: 'openjdk9_build_x86-64_macos'
        }
    }
    Platforms["aix"] = {
        node {
            build job: 'openjdk9_build_ppc64_aix'
        }
    }
    parallel Platforms
}
stage ('checksums') {
    node {
        def job = build job: 'openjdk9_build_checksum'
    }
}
stage ('publish nightly') {
    node {
        def job = build job: 'openjdk_release_tool', parameters: [string(name: 'REPO', value: 'nightly'), string(name: 'TAG', value: 'jdk-9+181'), string(name: 'VERSION', value: 'jdk9')]
    }
}
