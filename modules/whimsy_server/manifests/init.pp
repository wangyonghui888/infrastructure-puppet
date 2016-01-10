#/etc/puppet/modules/whimsy_server/manifests/init.pp


class whimsy_server (

  $apmail_keycontent = '',

  $keysdir = hiera('ssh::params::sshd_keysdir')

) {

  ############################################################
  #                       System Packages                    #
  ############################################################

  $packages = [
    build-essential,
    libgmp3-dev,
    libldap2-dev,
    libsasl2-dev,
    ruby-dev,
    zlib1g-dev,

    imagemagick,
    nodejs,
    pdftk,
  ]

  $gems = [
    bundler,
    rake,
  ]

  exec { 'Add nodesource sources':
    command => 'curl https://deb.nodesource.com/setup_5.x | bash -',
    creates => '/etc/apt/sources.list.d/nodesource.list',
    path    => ['/usr/bin', '/bin', '/usr/sbin']
  } ->

  package { $packages: ensure => installed } ->

  package { $gems: ensure => installed, provider => gem } ->

  ############################################################
  #               Web Server / Application content           #
  ############################################################

  class { 'rvm::passenger::apache':
    version            => '5.0.23',
    ruby_version       => 'ruby-2.3.0',
    mininstances       => '3',
    maxinstancesperapp => '0',
    maxpoolsize        => '30',
    spawnmethod        => 'smart-lv2',
  } ->

  vcsrepo { '/srv/whimsy':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/apache/whimsy.git',
    before   => Apache::Vhost[whimsy-vm-80]
  } ~>

  exec { 'rake::update':
    command     => '/usr/local/bin/rake update',
    cwd         => '/srv/whimsy',
    refreshonly => true
  }

  ############################################################
  #                         Symlink Ruby                     #
  ############################################################

  define whimsy_server::ruby::symlink ($binary = $title, $ruby = '') {
    $version = split($ruby, '-')
    file { "/usr/local/bin/${binary}${version[1]}" :
      ensure  => link,
      target  => "/usr/local/rvm/wrappers/${ruby}/${binary}",
      require => Class[rvm]
    }
  }

  define whimsy_server::rvm::symlink ($ruby = $title) {
    $binaries = [bundle, erb, gem, irb, rackup, rake, rdoc, ri, ruby, testrb]
    whimsy_server::ruby::symlink { $binaries: ruby => $ruby}
  }

  $rubies = keys(hiera_hash('rvm::system_rubies'))
  whimsy_server::rvm::symlink { $rubies: }

  ############################################################
  #                    Subversion Data Source                #
  ############################################################

  file { '/srv/svn':
    ensure => 'directory',
  }

  ############################################################
  #                       Mail Data Source                   #
  ############################################################

  user { 'apmail':
    ensure => present,
  }

  file { "${keysdir}/apmail.pub":
    content => $apmail_keycontent,
    owner   => apmail,
    mode    => '0640',
  }

  file { '/srv/mbox':
    ensure => directory,
    owner  => apmail,
    group  => apmail,
  }

}
