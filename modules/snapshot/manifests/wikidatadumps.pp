class snapshot::wikidatadumps::common {
    file { '/usr/local/bin/wikidatadumps-shared.sh':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/snapshot/wikidatadumps-shared.sh',
    }

    file { '/var/log/wikidatadump':
        ensure => 'directory',
        mode   => '0755',
        owner  => 'datasets',
        group  => 'www-data',
    }

    file { '/usr/local/share/dcat':
        ensure  => 'directory',
        mode    => '0444',
        owner   => 'datasets',
        group   => 'www-data',
        recurse => true,
        purge   => true,
        source  => 'puppet:///modules/snapshot/dcat',
    }
}

class snapshot::wikidatadumps::json(
    $enable = true,
    $user   = undef,
) {
    include snapshot::wikidatadumps::common

    if ($enable == true) {
        $ensure = 'present'
    }
    else {
        $ensure = 'absent'
    }

    $scriptPath = '/usr/local/bin/dumpwikidatajson.sh'
    file { $scriptPath:
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/snapshot/dumpwikidatajson.sh',
        require => Class['snapshot::wikidatadumps::common'],
    }

    cron { 'wikidatajson-dump':
        ensure  => $ensure,
        command => $scriptPath,
        user    => $user,
        minute  => '15',
        hour    => '3',
        weekday => '1',
        require => File[$scriptPath],
    }
}

class snapshot::wikidatadumps::ttl(
    $enable = true,
    $user   = undef,
) {
    include snapshot::wikidatadumps::common

    if ($enable == true) {
        $ensure = 'present'
    }
    else {
        $ensure = 'absent'
    }

    system::role { 'snapshot::wikidatadumps::ttl':
        ensure      => $ensure,
        description => 'producer of weekly wikidata ttl dumps'
    }

    $scriptPath = '/usr/local/bin/dumpwikidatattl.sh'
    file { $scriptPath:
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/snapshot/dumpwikidatattl.sh',
        require => Class['snapshot::wikidatadumps::common'],
    }

    cron { 'wikidatattl-dump':
        ensure  => $ensure,
        command => $scriptPath,
        user    => $user,
        minute  => '0',
        hour    => '23',
        weekday => '1',
        require => File[$scriptPath],
    }
}
