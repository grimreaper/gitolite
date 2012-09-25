package Gitolite::Redis;

# redis interface
# ----------------------------------------------------------------------

@EXPORT = qw(
  $redis
  _redis_rules
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

sub _redis_rules {
    my ($repo, $g_repo, $user) = @_;
    my $vk_rules = "vk_rules:$repo:$g_repo:$user";
    my @rules;

    if ($redis->type($vk_rules) eq 'list') {
        print STDERR "$vk_rules ttl is:" . $redis->ttl($vk_rules) . "\n";
    } else {
        print STDERR "$vk_rules doesn't exist; generating...\n";

        my @rl = _expand($repo, $g_repo);
        my @ul = _expand($user);
        my @keys;
        for my $r (@rl) {
            for my $u (@ul) {
                push @keys, "rs:$r:$u";
            }
        }
        my $t = "$vk_rules-temp-$$";
        $redis->sunionstore($t, @keys);
        $redis->expire($t, 7);
        @rules = $redis->sort(( $t, "get", "r:*", "store", $vk_rules));
        $redis->expire($vk_rules, 72);
    }
    return @rules;
}

sub _expand {
    my $base = shift;
    my $base2 = shift || '';
    my @t;

    my @ret;
    @ret = ($base, '@all');
    push @ret, $base2 if $base2;
    # dd(1, \@ret);

    @t = $redis->smembers('repopatterns');
    # dd(1.5, \@t);
    for my $rp (@t) {
        push @ret, $rp if $base =~ /^$rp$/ or $base2 =~ /^$rp$/;
    }
    # dd(2, \@ret);

    @t = @ret;
    for my $t (@t) {
        push @ret, $redis->hkeys("g:$t");
    }
    return @ret;
}

sub dd {
    use Data::Dumper;
    for my $i (@_) {
        print STDERR "DBG: " . Dumper($i);
    }
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
