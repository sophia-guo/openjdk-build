targetConfigurations = [
        "x64Mac"      : [
                "hotspot",
                "openj9"
        ],
        "x64Linux"    : [
                "hotspot",
                "openj9"
        ],
        "x64Windows"  : [
                "hotspot",
                "openj9"
        ],
        "x32Windows"  : [
                "hotspot"
        ],
        "ppc64Aix"    : [
                "hotspot",
                "openj9"
        ],
        "ppc64leLinux": [
                "hotspot",
                "openj9"
        ],
        "s390xLinux"  : [
                "hotspot",
                "openj9"
        ],
        "aarch64Linux": [
                "hotspot",
                "openj9"
        ]
]

// 03:30
triggerSchedule="TZ=UTC\n30 03 * * *"

return this
