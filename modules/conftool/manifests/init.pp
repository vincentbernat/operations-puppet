# == Class conftool
#
# Installs conftool, and creates a wrapper script that can be run in git as
# a post-receive hook.

class conftool(
    $config_file = 'puppet:///modules/conftool/production.config.yaml',
    $ssl_dir     = '/var/lib/puppet/ssl',
    $use_ssl     = true,
    ) {
    require_package 'python-conftool'

    file { '/etc/conftool':
        ensure => directory,
        owner  => root,
        group  => root,
        mode   => '0755',
    }

    file { '/etc/conftool/config.yaml':
        ensure => present,
        owner  => root,
        group  => root,
        mode   => '0444',
        source => $config_file,
    }

    if $use_ssl {
        file { '/etc/conftool/ca.pem':
            ensure => present,
            owner  => root,
            group  => root,
            mode   => '0444',
            source => "${ssl_dir}/certs/ca.pem",
        }
    }

}
