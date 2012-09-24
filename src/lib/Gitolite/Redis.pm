package Gitolite::Redis;

# redis interface
# ----------------------------------------------------------------------

@EXPORT = qw(
  $redis
);

use Exporter 'import';
use Redis;

our $redis;

my $redis_sock = "$ENV{HOME}/.gitolite-redis.sock";
-S $redis_sock or _start_redis_server();
$redis = Redis->new(sock => $redis_sock, encoding => undef) or die "redis new failed: $!";
$redis->ping or die "redis ping failed: $!";

sub _start_redis_server {
    my $conf = join("", <DATA>);
    $conf =~ s/%HOME/$ENV{HOME}/g;

    open( REDIS, "|-", "/usr/sbin/redis-server", "-" ) or die "start redis server failed: $!";
    print REDIS $conf;
    close REDIS;
    exit 0;
}

1;

__DATA__
# resources
maxmemory 50MB
port 0
unixsocket %HOME/.gitolite-redis.sock
unixsocketperm 700
timeout 0
databases 1

# daemon
daemonize yes
pidfile %HOME/.gitolite-redis.pid
dbfilename %HOME/.gitolite-redis.rdb
dir %HOME

# feedback
loglevel notice
logfile %HOME/.gitolite-redis.log

# safety
save 60 1
