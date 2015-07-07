class ores::base(
    $branch = 'deploy',
    $config_path = '/srv/ores/config',
    $venv_path = '/srv/ores/venv',
    $data_path = '/srv/ores/data',
) {
    # Let's use a virtualenv for maximum flexibility - we can convert
    # this to deb packages in the future if needed. We also install build tools
    # because they are needed by pip to install scikit.
    # FIXME: Use debian packages for all the packages needing compilation
    require_package('python-virtualenv', 'python3-dev', 'build-essential',
                    'gfortran', 'libopenblas-dev', 'liblapack-dev')

    # Install scipy via debian package so we don't need to build it via pip
    # takes forever and is quite buggy
    require_package('python3-scipy')

    # ORES is a python3 application \o/
    require_package('uwsgi-plugin-python3')

    # It requires the enchant debian package
    require_package('enchant')

    # Spellcheck packages for supported languages
    require_package('myspell-pt', 'myspell-fa', 'myspell-en-au',
                    'myspell-en-gb', 'myspell-en-us',
                    'myspell-en-za', 'myspell-fr')

    file { '/srv':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0775',
    }

    file { [
        '/srv/ores',
        $data_path,
        "${data_path}/nltk",
    ]:
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0775',
        require => File['/srv'],
    }

    git::clone { 'ores-wm-config':
        origin    => 'https://github.com/wiki-ai/ores-wikimedia-config.git',
        ensure    => present,
        directory => $config_path,
        branch    => $branch,
        owner     => 'www-data',
        group     => 'www-data',
        require   => File['/srv/ores'],
    }
}