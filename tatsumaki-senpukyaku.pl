#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;

package StreamWriter;
use MIME::Base64 qw(encode_base64);
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;
    $self->response->content_type('multipart/mixed; boundary="|||"');

	my @images;
    for (3..6) {
        open(my $f, sprintf("static/images/%03d.gif", $_)) or die "$!";
        (my $encdata = encode_base64(join('', <$f>))) =~ s/\n//g;
		push @images, $encdata;
    }
	push @images, $images[2];
	push @images, $images[1];
    my $try = 0;
    $self->stream_write("--|||\n");
    my $t; $t = AE::timer 0, 0.1, sub {
        $self->stream_write("Content-Type: image/gif\n");
        $self->stream_write($images[$try%6]);
        $self->stream_write("--|||\n");
        if ($try++ >= 100) {
            undef $t;
            $self->finish;
        }
    };
}

package MainHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my $self = shift;
    $self->write(<<EOF);
<html>
<script type="text/javascript" src="static/js/jquery.min.js"></script>
<script type="text/javascript" src="static/js/DUI.js"></script>
<script type="text/javascript" src="static/js/Stream.js"></script>
<script type="text/javascript">
\$(function() {
	\$('#animgif').load(function(){
		\$('#message').text('せー');
		setTimeout(function() {
			\$('#animgif').load(function(){
				\$('#message').text('のー');
				setTimeout(function() {
					\$('#animgif').unbind('load');
					\$('#message').text('竜巻旋風脚！！！');
					var s = new DUI.Stream();
					s.listen('image/gif', function(payload) {
						\$('#animgif').attr('src', 'data:image/gif;base64,'+payload);
					});
					s.listen('complete', function() {
					});
					s.load('/stream');
				}, 1000);
			}).attr('src', 'static/images/002.gif');
		}, 1000);
	}).attr('src', 'static/images/001.gif');
});
</script>
<body>
<span id="message"></span><br />
<img id="animgif" src="static/images/001.gif" />
</body>
</html>
EOF
;
}

package main;
use File::Basename;

my $app = Tatsumaki::Application->new([
    '/stream' => 'StreamWriter',
	'/' => 'MainHandler',
]);

if (__FILE__ eq $0) {
    require Tatsumaki::Server;
    Tatsumaki::Server->new(port => 9999)->run($app);
} else {
    return $app;
}
