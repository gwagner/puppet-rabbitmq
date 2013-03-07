class rabbitmq::config
{
    $package_dependencies = [
        'ncurses-devel',
        'openssl-devel',
        'icu',
        'libicu-devel',
        'js',
        'js-devel',
        'erlang',
        'libtool'
    ]

    $version = "3.0.2"
}