class rabbitmq
{
    include rabbitmq::config

    package
    {
        $rabbitmq::config::package_dependencies:
            ensure => installed,
            provider => 'yum',
            require => [Yumrepo['epel']];

        'rabbitmq-server':
            ensure => installed,
            provider => 'rpm',
            configfiles => keep,
            source => "http://www.rabbitmq.com/releases/rabbitmq-server/v${rabbitmq::config::version}/rabbitmq-server-${rabbitmq::config::version}-1.noarch.rpm",
            require => [
                Yumrepo['epel'],
                Package[$rabbitmq::config::package_dependencies]
            ];
    }

    rabbitmq::plugin {
        'rabbitmq_management':
            ensure => present,
            require => Package['rabbitmq-server'];
    }

    service {
        'rabbitmq-server':
            ensure => true,
            enable => true,
            hasrestart => true,
            hasstatus => true,
            subscribe => [
                Package["rabbitmq-server"]
            ];
    }
}

define rabbitmq::plugin ($ensure = present)
{
    include rabbitmq

    case $ensure {
        present: {
            exec {
                "rabbitmq-plugin-${name}":
                    command => "rabbitmq-plugins enable ${name}; chmod 400 /var/lib/rabbitmq/.erlang.cookie; chown rabbitmq: /var/lib/rabbitmq/.erlang.cookie;",
                    onlyif => "test `rabbitmq-plugins list -e -m ${name} | grep '^${name}$' | wc -l` -eq 0",
                    notify => Service['rabbitmq-server'],
                    environment => ['HOME=/var/lib/rabbitmq'],
                    user => 'root',
                    require => [ Package['rabbitmq-server'] ];
            }
        }
        absent: {
            exec {
                "rabbitmq-plugin-${name}":
                    command => "rabbitmq-plugins disable ${name}; chmod 400 /var/lib/rabbitmq/.erlang.cookie; chown rabbitmq: /var/lib/rabbitmq/.erlang.cookie;",
                    onlyif => "test `rabbitmq-plugins list -e -m ${name} | grep '^${name}$' | wc -l` -gt 0",
                    notify => Service['rabbitmq-server'],
                    environment => ['HOME=/var/lib/rabbitmq'],
                    user => 'root',
                    require => [ Package['rabbitmq-server'] ];
            }
        }
    }
}

define rabbitmq::user (
    $ensure   = present,
    $password = false,
    $vhost    = '/',
    $conf     = '.*',
    $read     = '.*',
    $write    = '.*'
) {

	include rabbitmq

	case $ensure {
		present: {
			if ! $password {
				fail 'Must pass password to rabbitmq::user'
			}
			exec{
			    "rabbitmqctl-user-${name}":
                    command => "rabbitmqctl add_user '${name}' '${password}'",
                    onlyif  => "test `rabbitmqctl -q list_users | grep  '^${name}\t' | wc -l` -eq 0",
                    require => [ Service['rabbitmq-server'] ];
			}
		}
		absent: {
			exec{
			    "rabbitmqctl-user-${name}":
                    command => "rabbitmqctl delete_user '${name}'",
                    onlyif  => "test `rabbitmqctl -q list_users | grep '^${name}\t' | wc -l` -gt 0",
                    require => [ Service['rabbitmq-server'] ];
			}
		}
	}

	rabbitmq::permissions { $name:
		ensure => $ensure,
		vhost  => $vhost,
		conf   => $conf,
		read   => $read,
		write  => $write,
	}
}

define rabbitmq::user::set_tags($tags = '') {
    $username = $title

    exec {
        "rabbitmq-setusertags-${username}":
            command => "rabbitmqctl set_user_tags ${username} ${tags}",
            path    => ["/bin", "/sbin", "/usr/bin", "/usr/sbin"],
            unless  => "rabbitmqctl list_users | grep ^${username} | tr -d ',' | grep \"${tags}\"",
            require => [ Service['rabbitmq-server'] ];
    }
}

define rabbitmq::permissions (
    $ensure = present,
    $vhost  = '/',
    $conf   = '.*',
    $read   = '.*',
    $write  = '.*'
) {

	include rabbitmq

	case $ensure {
		present: {
			exec{

			    "rabbitmqctl-permissions-${name}":
                    command => "rabbitmqctl set_permissions -p '${vhost}' '${name}' '${conf}' '${write}' '${read}'",
                    onlyif  => "test `rabbitmqctl -q list_permissions -p '${vhost}' | grep '^${name}\t${conf}\t${write}\t${read}' | wc -l` -eq 0",
                    require => [
                        Exec["rabbitmqctl-user-${name}"],
                        Service['rabbitmq-server']
                    ];
			}
		}
		absent: {
			exec{
			    "rabbitmqctl-permissions-${name}":
                    command => "rabbitmqctl clear_permissions -p '${vhost}' '${name}'",
                    onlyif  => "test `rabbitmqctl -q list_permissions -p '${vhost}' | grep '^${name}\t${conf}\t${write}\t${read} ' | wc -l` -gt 0",
                    require => [
                        Exec["rabbitmqctl-user-${name}"],
                        Service['rabbitmq-server']
                    ];
			}
		}
	}
}

define rabbitmq::vhost ($ensure = present)
{

    include rabbitmq
    $vhost = $name

	case $ensure {
		present: {
			exec{
			    "rabbitmqctl-vhost-${vhost}":
                    command => "rabbitmqctl add_vhost '${vhost}'",
                    onlyif  => "test `rabbitmqctl -q list_vhosts | grep '^${vhost}' | wc -l` -eq 0",
                    require => [
                        Service['rabbitmq-server']
                    ];
			}
		}
		absent: {
			exec{
			    "rabbitmqctl-vhost-${vhost}":
                    command => "rabbitmqctl delete_vhost '${vhost}'",
                    onlyif  => "test `rabbitmqctl -q list_vhosts | grep '^${vhost}' | wc -l` -gt 0",
                    require => [
                        Service['rabbitmq-server']
                    ];
			}
		}
	}
}