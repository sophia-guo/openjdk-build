class Config11 {
  final Map<String, Map<String, ?>> buildConfigurations = [
        x64Mac    : [
                os                  : 'mac',
                arch                : 'x64',
                additionalNodeLabels : 'macos10.14',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system', 'sanity.perf'],
                        weekly : []
                ],
                configureArgs       : [
                        "openj9"      : '--enable-dtrace=auto --with-cmake',
                        "hotspot"     : '--enable-dtrace=auto'
                ]
        ],

        x64MacXL    : [
                os                   : 'mac',
                arch                 : 'x64',
                additionalNodeLabels : 'macos10.14',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system'],
                        weekly : []
                ],
                additionalFileNameTag: "macosXL",
                configureArgs        : '--with-noncompressedrefs --enable-dtrace=auto --with-cmake'
        ],

        x64Linux  : [
                os                  : 'linux',
                arch                : 'x64',
                dockerImage         : 'adoptopenjdk/centos6_build_image',
                dockerFile: [
                        openj9  : 'pipelines/build/dockerFiles/cuda.dockerfile'
                ],
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system', 'sanity.perf', 'sanity.external'],
                        weekly : ['special.functional']
                ],
                configureArgs       : [
                        "openj9"      : '--disable-ccache --enable-jitserver --enable-dtrace=auto',
                        "hotspot"     : '--disable-ccache --enable-dtrace=auto',
                        "corretto"    : '--disable-ccache --enable-dtrace=auto',
                        "SapMachine"  : '--disable-ccache --enable-dtrace=auto'
                ]
        ],

        // Currently we have to be quite specific about which windows to use as not all of them have freetype installed
        x64Windows: [
                os                  : 'windows',
                arch                : 'x64',
                additionalNodeLabels: [
                        hotspot: 'win2012',
                        openj9:  'win2012&&vs2017'
                ],
                buildArgs : [
                        hotspot : '--jvm-variant client,server'
                ],
                                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system', 'sanity.perf'],
                        weekly : []
                ]
        ],

        x64WindowsXL    : [
                os                   : 'windows',
                arch                 : 'x64',
                additionalNodeLabels : 'win2012&&vs2017',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system'],
                        weekly : []
                ],
                additionalFileNameTag: "windowsXL",
                configureArgs        : '--with-noncompressedrefs'
        ],

        x32Windows: [
                os                  : 'windows',
                arch                : 'x86-32',
                additionalNodeLabels: [
                        hotspot: 'win2012',
                        openj9:  'win2012&&mingw-standalone'
                ],
                buildArgs : [
                        hotspot : '--jvm-variant client,server'
                ],
                test                : [
                        nightly: ['sanity.openjdk'],
                        weekly : []
                ]
        ],

        ppc64Aix    : [
                os                  : 'aix',
                arch                : 'ppc64',
                additionalNodeLabels: [
                        hotspot: 'xlc13&&aix710',
                        openj9:  'xlc13&&aix715'
                ],
                test                : [
                        nightly: ['sanity.openjdk'],
                        weekly : ['sanity.openjdk', 'sanity.system', 'extended.system']
                ]
        ],

        s390xLinux    : [
                os                  : 'linux',
                arch                : 's390x',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system', 'sanity.perf'],
                        weekly : []
                ],
                configureArgs       : '--disable-ccache --enable-dtrace=auto'
        ],

        sparcv9Solaris    : [
                os                  : 'solaris',
                arch                : 'sparcv9',
                test                : false,
                configureArgs       : '--enable-dtrace=auto'
        ],

        ppc64leLinux    : [
                os                  : 'linux',
                arch                : 'ppc64le',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system', 'sanity.perf'],
                        weekly : []
                ],
                configureArgs       : [
                        "hotspot"     : '--disable-ccache --enable-dtrace=auto',
                        "openj9"      : '--disable-ccache --enable-dtrace=auto --enable-jitserver'
                ]

        ],

        arm32Linux    : [
                os                  : 'linux',
                arch                : 'arm',
                // TODO Temporarily remove the ARM tests because we don't have fast enough hardware
                //test                : ['sanity.openjdk', 'sanity.perf']
                test                : false,
                configureArgs       : '--enable-dtrace=auto'
        ],

        aarch64Linux    : [
                os                  : 'linux',
                arch                : 'aarch64',
                dockerImage         : 'adoptopenjdk/centos7_build_image',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system', 'sanity.perf'],
                        weekly : []
                ],
                configureArgs       : '--enable-dtrace=auto'
        ],

        /*
        "x86-32Windows"    : [
                os                 : 'windows',
                arch               : 'x86-32',
                additionalNodeLabels: 'win2012&&x86-32',
                test                : false
        ],
        */
        x64LinuxXL    : [
                os                   : 'linux',
                dockerImage          : 'adoptopenjdk/centos6_build_image',
                dockerFile: [
                        openj9  : 'pipelines/build/dockerFiles/cuda.dockerfile'
                ],
                arch                 : 'x64',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system'],
                        weekly : []
                ],
                additionalFileNameTag: "linuxXL",
                configureArgs        : '--with-noncompressedrefs --disable-ccache --enable-jitserver --enable-dtrace=auto'
        ],
        s390xLinuxXL    : [
                os                   : 'linux',
                arch                 : 's390x',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system'],
                        weekly : []
                ],
                additionalFileNameTag: "linuxXL",
                configureArgs        : '--with-noncompressedrefs --disable-ccache --enable-dtrace=auto'
        ],
        ppc64leLinuxXL    : [
                os                   : 'linux',
                arch                 : 'ppc64le',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system'],
                        weekly : []
                ],
                additionalFileNameTag: "linuxXL",
                configureArgs        : '--with-noncompressedrefs --disable-ccache --enable-dtrace=auto --enable-jitserver'
        ],
        aarch64LinuxXL    : [
                os                   : 'linux',
                dockerImage          : 'adoptopenjdk/centos7_build_image',
                arch                 : 'aarch64',
                test                : [
                        nightly: ['sanity.openjdk', 'sanity.system', 'extended.system'],
                        weekly : []
                ],
                additionalFileNameTag: "linuxXL",
                configureArgs        : '--with-noncompressedrefs --disable-ccache --enable-dtrace=auto'
        ],
        riscv64Linux      :  [
                os                   : 'linux',
                additionalNodeLabels : 'riscvcross',
                arch                 : 'riscv64',
                configureArgs        : '--disable-ddr --openjdk-target=riscv64-unknown-linux-gnu --with-sysroot=/opt/fedora28_riscv_root'
        ],
  ]

}

Config11 config = new Config11()
return config.buildConfigurations
