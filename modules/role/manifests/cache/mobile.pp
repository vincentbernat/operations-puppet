class role::cache::mobile {
    system::role { 'role::cache::mobile':
        description => 'mobile Varnish cache server',
    }

    class { 'varnish::htcppurger':
        mc_addrs => [ '239.128.0.112' ],
    }

    include role::cache::2layer

    class { 'lvs::realserver':
        realserver_ips => $lvs::configuration::service_ips['mobile'][$::site],
    }

    $cluster_nodes = hiera('cache::mobile::nodes')
    $site_cluster_nodes = $cluster_nodes[$::site]

    # 1/8 of total mem
    $memory_storage_size = ceiling(0.125 * $::memorysize_mb / 1024.0)

    include role::cache::ssl::unified

    require geoip
    require geoip::dev # for VCL compilation using libGeoIP

    $varnish_be_directors = {
        'one' => {
            'backend'          => {
                'dynamic'  => 'no',
                'type'     => 'random',
                'backends' => $role::cache::configuration::backends[$::realm]['appservers'][$::mw_primary],
            },
            'api'              => {
                'dynamic'  => 'no',
                'type'     => 'random',
                'backends' => $role::cache::configuration::backends[$::realm]['api'][$::mw_primary],
            },
            'rendering'        => {
                'dynamic'  => 'no',
                'type'     => 'random',
                'backends' => $role::cache::configuration::backends[$::realm]['rendering'][$::mw_primary],
            },
            'security_audit'   => {
                'dynamic'  => 'no',
                'type'     => 'random',
                'backends' => $role::cache::configuration::backends[$::realm]['security_audit'][$::mw_primary],
            },
            'test_wikipedia'   => {
                'dynamic'  => 'no',
                'type'     => 'random',
                'backends' => $role::cache::configuration::backends[$::realm]['test_appservers'][$::mw_primary],
            },
            'restbase_backend' => {
                'dynamic'  => 'no',
                'type'     => 'random',
                'backends' => $role::cache::configuration::backends[$::realm]['restbase'][$::mw_primary],
            },
        },
        'two' => {
            'backend'        => {
                'dynamic'  => 'yes',
                'type'     => 'chash',
                'backends' => $cluster_nodes['eqiad'],
            },
            'backend_random' => {
                'dynamic'  => 'yes',
                'type'     => 'random',
                'backends' => $cluster_nodes['eqiad'],
                'service'  => 'varnish-be-rand',
            },
        },
    }

    if $::role::cache::configuration::has_ganglia {
        include varnish::monitoring::ganglia::vhtcpd
    }

    $common_vcl_config = {
        'cache4xx'           => '1m',
        'static_host'        => $::role::cache::base::static_host,
        'bits_domain'        => $::role::cache::base::bits_domain,
        'top_domain'         => $::role::cache::base::top_domain,
        'do_gzip'            => true,
    }

    $be_vcl_config = merge($common_vcl_config, {
        'layer'              => 'backend',
    })

    $fe_vcl_config = merge($common_vcl_config, {
        'layer'              => 'frontend',
        'retry503'           => 1,
        'enable_geoiplookup' => true,
        'https_redirects'    => true,
    })

    varnish::instance { 'mobile-backend':
        name               => '',
        vcl                => 'mobile-backend',
        extra_vcl          => ['text-common'],
        ports              => [ 3128 ],
        admin_port         => 6083,
        runtime_parameters => ['default_ttl=2592000'],
        storage            => $::role::cache::2layer::persistent_storage_args,
        directors          => $varnish_be_directors[$::site_tier],
        vcl_config         => $be_vcl_config,
        backend_options    => array_concat($::role::cache::2layer::backend_scaled_weights, [
            {
                'backend_match' => '^cp[0-9]+\.eqiad\.wmnet$',
                'port'          => 3128,
                'probe'         => 'varnish',
            },
            {
                'backend_match'   => '^mw1017\.eqiad\.wmnet$',
                'max_connections' => 20,
            },
            {
                'backend_match'   => '^restbase\.svc\.|^deployment-restbase',
                'port'            => 7231,
                'max_connections' => 5000,
            },
            {
                'port'                  => 80,
                'connect_timeout'       => '5s',
                'first_byte_timeout'    => '180s',
                'between_bytes_timeout' => '4s',
                'max_connections'       => 1000,
            },
        ]),
    }

    varnish::instance { 'mobile-frontend':
        name               => 'frontend',
        vcl                => 'mobile-frontend',
        extra_vcl          => ['text-common', 'zero'],
        ports              => [ 80 ],
        admin_port         => 6082,
        runtime_parameters => ['default_ttl=2592000'],
        storage            => "-s malloc,${memory_storage_size}G",
        directors          => {
            'backend' => {
                'dynamic'  => 'yes',
                'type'     => 'chash',
                'backends' => $site_cluster_nodes,
            },
            'backend_random' => {
                'dynamic'  => 'yes',
                'type'     => 'random',
                'backends' => $site_cluster_nodes,
                'service'  => 'varnish-be-rand',
            },
        },
        vcl_config         => $fe_vcl_config,
        backend_options    => array_concat($::role::cache::2layer::backend_scaled_weights, [
            {
                'port'                  => 3128,
                'connect_timeout'       => '5s',
                'first_byte_timeout'    => '185s',
                'between_bytes_timeout' => '2s',
                'max_connections'       => 100000,
                'probe'                 => 'varnish',
            },
        ]),
    }

    # varnish::logging UDP based varnishncsa to be removed once
    # all uses of udp2log are ported to Kafka.
    include role::cache::logging

    # varnishkafka statsv listens for special stats related requests
    # and sends them to the 'statsv' topic in Kafka.
    # A kafka consumer then consumes these and emits
    # metrics.
    class { '::role::cache::kafka::statsv':
        varnish_name => 'frontend',
    }

    # varnishkafka eventlogging listens for eventlogging
    # requests and logs them to the eventlogging-client-side
    # topic.  EventLogging servers consume and process this
    # topic into many JSON based kafka topics for further
    # consumption.
    class { '::role::cache::kafka::eventlogging':
        varnish_name => 'frontend',
    }

    # ToDo: Remove production conditional once this works
    # is verified to work in labs.
    if $::realm == 'production' {
        # Install a varnishkafka producer to send
        # all varnish webrequest logs to Kafka.
        class { 'role::cache::kafka::webrequest': topic => 'webrequest_mobile' }
    }

    # Parse varnishlogs for request statistics and send to statsd.
    varnish::logging::reqstats { 'frontend':
        metric_prefix => "varnish.${::site}.mobile.frontend.request",
        statsd        => hiera('statsd'),
    }
}
