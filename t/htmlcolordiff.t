#!perl -w

use strict;
use Test::More;
use File::Spec::Functions;

if (eval { require HTML::Entities }) {
    plan tests => 193;
} else {
    plan skip_all => "SVN::Notify::HTML::ColorDiff requires HTML::Entities";
}

use_ok('SVN::Notify::HTML::ColorDiff');

my $ext = $^O eq 'MSWin32' ? '.bat' : '';

my $dir = catdir curdir, 't', 'scripts';
$dir = catdir curdir, 't', 'bin' unless -d $dir;

my %args = (
    svnlook    => catfile($dir, "testsvnlook$ext"),
    sendmail   => catfile($dir, "testsendmail$ext"),
    repos_path => 'tmp',
    revision   => '111',
    to         => 'test@example.com',
);

my $subj = "Did this, that, and the «other».";
my $qsubj;
if (SVN::Notify::PERL58()) {
    Encode::_utf8_on( $subj );
    $qsubj = quotemeta Encode::encode( 'MIME-Q', "[111] $subj" );
} else {
    $qsubj = quotemeta "[111] $subj";
}

##############################################################################
# Basic Functionality.
##############################################################################
ok( my $notifier = SVN::Notify::HTML::ColorDiff->new(%args),
    "Construct new HTML::ColorDiff notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify::HTML');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Single method call prepare" );
ok( $notifier->execute, "HTML notify" );

# Get the output.
my $email = get_output();

# Check the email headers.
like( $email, qr/Subject: $qsubj\n/, 'Check HTML subject' );
like( $email, qr/From: theory\n/, 'Check HTML From');
like( $email, qr/To: test\@example\.com\n/, 'Check HTML To');
like( $email, qr{Content-Type: text/html; charset=UTF-8\n},
      'Check HTML Content-Type' );
like( $email, qr{Content-Transfer-Encoding: 8bit\n},
      'Check HTML Content-Transfer-Encoding');

# Make sure that the <html>, <head>, <body>, and <dl> headers tags
# are included.
for my $tag (qw(html head body dl)) {
    like( $email, qr/<$tag/, "Check for <$tag> tag" );
    like( $email, qr/<\/$tag>/, "Check for </$tag> tag" );
}

# Make sure we have styles and the appropriate div.
like( $email, qr|<style type="text/css">|, "Check for <style> tag" );
like( $email, qr/<\/style>/, "Check for </style> tag" );
like( $email,
      qr/#patch ins \{background:#dfd;text-decoration:none;display:block;padding:0 10px;\}/,
      'Check for style' );
like( $email, qr/<div id="msg">/, "Check for msg div" );

# Make sure we have headers for each of the four kinds of changes.
for my $header ('Log Message', 'Modified Paths', 'Added Paths',
                'Removed Paths', 'Property Changed') {
    like( $email, qr{<h3>$header</h3>}, "HTML $header" );
}

# Check that we have the commit metatdata.
like( $email, qr|<dt>Revision</dt> <dd>111</dd>\n|, 'Check Revision');
like( $email, qr|<dt>Author</dt> <dd>theory</dd>\n|, 'Check Author');
like( $email,
      qr|<dt>Date</dt> <dd>2004-04-20 01:33:35 -0700 \(Tue, 20 Apr 2004\)</dd>\n|,
      'Check Date');

# Check that the log message is there.
UTF8: {
    use utf8;
    like( $email, qr{<pre>Did this, that, and the «other»\. And then I did some more\. Some\nit was done on a second line\. “Go figure”\. r1234</pre>}, 'Check for HTML log message' );
}

# Make sure that Class/Meta.pm is listed twice, once for modification and once
# for its attribute being set.
is( scalar @{[$email =~ m{(<li>trunk/Class-Meta/lib/Class/Meta\.pm</li>)}g]}, 2,
    'Check for two HTML Class/Meta.pm');
# For other file names, there should be only one instance.
is( scalar @{[$email =~ m{(<li>trunk/Class-Meta/lib/Class/Meta/Class\.pm</li>)}g]}, 1,
    'Check for one HTML Class/Meta/Class.pm');
is( scalar @{[$email =~ m{(<li>trunk/Class-Meta/lib/Class/Meta/Type\.pm</li>)}g]}, 1,
    'Check for one HTML Class/Meta/Type.pm');

# Make sure that no diff is included.
unlike( $email, qr{Modified: trunk/Params-CallbackRequest/Changes},
        "Check for html diff" );

##############################################################################
# Make sure that handler delegation works.
##############################################################################
ok( $notifier = SVN::Notify->new(%args, handler => 'HTML::ColorDiff'),
    "Construct new HTML notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Single method call prepare" );
ok( $notifier->execute, "HTML notify" );

# Get the output.
$email = get_output();

# Check the email headers.
like( $email, qr/Subject: $qsubj\n/, 'Check HTML subject' );
like( $email, qr/From: theory\n/, 'Check HTML From');
like( $email, qr/To: test\@example\.com\n/, 'Check HTML To');
like( $email, qr{Content-Type: text/html; charset=UTF-8\n},
      'Check HTML Content-Type' );
like( $email, qr{Content-Transfer-Encoding: 8bit\n},
      'Check HTML Content-Transfer-Encoding');

##############################################################################
# Include HTML diff.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(%args, with_diff => 1),
    "Construct new HTML diff notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Single method call prepare" );
ok( $notifier->execute, "HTML diff notify" );

# Get the output.
$email = get_output();

like( $email, qr/Subject: $qsubj\n/, 'Check HTML diff subject' );
like( $email, qr/From: theory\n/, 'Check HTML diff From');
like( $email, qr/To: test\@example\.com\n/, 'Check HTML diff To');

# Make sure there are no attachment headers
is( scalar @{[ $email =~ m{Content-Type: text/(plain|html); charset=UTF-8\n} ]}, 1,
    'Check for one HTML Content-Type header' );
is( scalar @{[$email =~ m{Content-Transfer-Encoding: 8bit\n}g]}, 1,
      'Check for one HTML Content-Transfer-Encoding header');

# Make sure that the diff is included and escaped.
like( $email, qr/<div id="patch">/, "Check for patch div" );
like( $email, qr{<a id="trunkParamsCallbackRequestChanges"></a>\n},
      "Check for file div ID");
like( $email, qr{<div class="modfile"><h4>Modified: trunk/Params-CallbackRequest/Changes \(600 => 601\)</h4>},
      "Check for diff file header" );
like( $email, qr{<a id="trunkParamsCallbackRequestlibParamsCallbackpm"></a>\n},
      "Check for added file div ID");
like( $email, qr{<div class="addfile"><h4>Added: trunk/Params-CallbackRequest/lib/Params/Callback.pm \(600 => 601\)</h4>},
      "Check for added diff file header" );
like( $email, qr{<ins>\+    \{ isa        =&gt; \$ap_req_class,\n</ins>},
      'Check for an insert element.');
like( $email, qr{<del>-    \{ isa        =&gt; ('|&#39;)Apache\1,\n</del>},
      'Check for a del element');

# Make sure that it's not attached.
unlike( $email, qr{Content-Type: multipart/mixed; boundary=},
        "Check for no html diff attachment" );
unlike( $email, qr{Content-Disposition: attachment; filename=},
        "Check for no html diff filename" );
like( $email, qr{isa        =\&gt; ('|&#39;)Apache\1,}, "Check for HTML escaping" );

# Make sure that the file names have links into the diff.
like( $email,
      qr|<li><a href="#trunkParamsCallbackRequestChanges">trunk/Params-CallbackRequest/Changes</a></li>\n|,
      "Check for file name link." );

# Make sure that the file names are linked.
like( $email,
      qr|<li><a href="#trunkClassMetaChanges">trunk/Class-Meta/Changes</a></li>|,
      "Check for linked file name" );
like( $email,
      qr|<li><a href="#trunkClassMetalibClassMetaTypepm">trunk/Class-Meta/lib/Class/Meta/Type\.pm</a></li>|,
      "Check for linked property change file");

##############################################################################
# Include HTML diff with diff_switches.
##############################################################################
ok $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
    with_diff => 1,
    diff_switches => '--no-diff-added',
), 'Construct new HTML diff_switches notifier';
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, 'Single method call prepare' );
ok( $notifier->execute, 'HTML diff_switches notify' );

# Get the output.
$email = get_output();

like $email,
    qr{<div class="addfile"><h4>Added:\s+trunk/Params-CallbackRequest/lib/Params/Callback\.pm</h4></div>\n</div>\s+</body>},
    'Check for added diff file header without body';

##############################################################################
# Attach diff.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(%args, attach_diff => 1,
                                       boundary => 'frank'),
    "Construct new HTML attach diff notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Single method call prepare" );
ok( $notifier->execute, "Attach HTML attach diff notify" );

# Get the output.
$email = get_output();

like( $email, qr/Subject: $qsubj\n/, 'Check HTML attach diff subject' );
like( $email, qr/From: theory\n/, 'Check HTML attach diff From');
like( $email, qr/To: test\@example\.com\n/, 'Check HTML attach diff To');

# Make sure we have two sets of headers for attachments.
is( scalar @{[ $email =~ m{Content-Type: text/(plain|html); charset=UTF-8\n}g ]}, 2,
    'Check for two Content-Type headers' );
is( scalar @{[$email =~ m{Content-Transfer-Encoding: 8bit\n}g]}, 2,
      'Check for two Content-Transfer-Encoding headers');

# Make sure that the diff is included.
like( $email, qr{Modified: trunk/Params-CallbackRequest/Changes},
      "Check for diff" );

# Make sure that it's attached.
like( $email, qr{Content-Type: multipart/mixed; boundary="(.*)"\n},
        "Check for html diff attachment" );
like( $email,
      qr{Content-Disposition: attachment; filename=r111-theory.diff\n},
      "Check for html diff filename" );
unlike( $email, qr{<pre><span>\nModified}, "Check for no pre tag" );

# Check for boundaries.
is( scalar @{[$email =~ m{(--frank\n)}g]}, 2,
    'Check for two boundaries');
is( scalar @{[$email =~ m{(--frank--)}g]}, 1,
    'Check for one final boundary');

##############################################################################
# Try html format with a single file changed.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(%args, revision => '222'),
    "Construct new subject_cx file notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare HTML file" );
ok( $notifier->execute, "Notify HTML file" );

# Check the output.
$email = get_output();
like( $email, qr{Subject: \[222\] Hrm hrm\. Let's try a few links\.\n},
      "Check subject header for HTML file" );
like( $email, qr/From: theory\n/, 'Check HTML file From');
like( $email, qr/To: test\@example\.com\n/, 'Check HTML file To');
like( $email, qr{Content-Type: text/html; charset=UTF-8\n},
      'Check HTML file Content-Type' );
like( $email, qr{Content-Transfer-Encoding: 8bit\n},
      'Check HTML file Content-Transfer-Encoding');

##############################################################################
# Try viewcvs_url + HTML.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
     viewcvs_url => 'http://svn.example.com/?rev=%s&view=rev',
),
    "Construct new HTML viewcvs_url notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare HTML viewcvs_url" );
ok( $notifier->execute, "Notify HTML viewcvs_url" );

# Check the output.
$email = get_output();
like( $email,
      qr|<dt>Revision</dt>\s+<dd><a href="http://svn\.example\.com/\?rev=111\&amp;view=rev">111</a></dd>\n|,
      'Check for HTML URL');

##############################################################################
# Try svnweb_url + HTML.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
     svnweb_url => 'http://svn.example.com/?rev=%s&view=rev',
), "Construct new HTML svnweb_url notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare HTML svnweb_url" );
ok( $notifier->execute, "Notify HTML svnweb_url" );

# Check the output.
$email = get_output();
like( $email,
      qr|<dt>Revision</dt>\s+<dd><a href="http://svn\.example\.com/\?rev=111\&amp;view=rev">111</a></dd>\n|,
      'Check for HTML URL');

##############################################################################
# Try encoding.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
    encoding => 'ISO-8859-1'
), "Construct new encoding notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare encoding" );
ok( $notifier->execute, "Notify encoding" );

# Check the output.
$email = get_output();
like( $email, qr{Content-Type: text/html; charset=ISO-8859-1\n},
      'Check Content-Type charset' );

##############################################################################
# Try html format with propsets.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(%args, with_diff => 1,
                                                  revision => '333'),
    "Construct new propset notifier" );
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify::HTML');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare propset HTML file" );
ok( $notifier->execute, "Notify propset HTML file" );

# Check the output.
$email = get_output();
like( $email, qr{Subject: \[333\] Property modification\.\n},
      "Check subject header for propset HTML" );
like( $email, qr/From: theory\n/, 'Check propset HTML From');
like( $email, qr/To: test\@example\.com\n/, 'Check propset HTML To');
like( $email, qr{Content-Type: text/html; charset=UTF-8\n},
      'Check propset HTML Content-Type' );
like( $email, qr{Content-Transfer-Encoding: 8bit\n},
      'Check propset HTML Content-Transfer-Encoding');

# Check for a header for the modified file.
like( $email, qr{<a id="trunkactivitymailbinactivitymail"></a>\n},
      "Check for modified file div ID");
like( $email, qr{<div class="modfile"><h4>Modified: trunk/activitymail/bin/activitymail \(681 => 682\)</h4>},
      "Check for modified file header" );

# Check for propset file.
like( $email, qr{<a id="trunkactivitymailbinactivitymail"></a>\n},
      "Check for modified file div ID");
like( $email, qr{<div class="propset"><h4>Property changes: trunk/activitymail/t/activitymail\.t</h4>},
      "Check for modified file header" );

##############################################################################
# SVNWeb URL.
##############################################################################
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
    revision     => 444,
    svnweb_url   => 'http://svn.example.com/index.cgi/revision/?rev=%s',
),
    "Construct new complext notifier" );
isa_ok($notifier, 'SVN::Notify::HTML');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare complex example" );
ok( $notifier->execute, "Notify complex example" );

$email = get_output();

# Make sure multiple lines are still multiple!
like($email, qr/link\.\n\nWe/, "Check for multiple lines" );

# Check for SVNWeb URLs.
like( $email,
      qr|<dt>Revision</dt>\s+<dd><a href="http://svn\.example\.com/index\.cgi/revision/\?rev=444">444</a></dd>\n|,
      'Check for main SVNWeb URL');
like($email,
     qr{<a href="http://svn\.example\.com/index\.cgi/revision/\?rev=6000">Revision 6000</a>\.},
     "Check for first log mesage SVNWeb URL");
like($email,
     qr{<a href="http://svn\.example\.com/index\.cgi/revision/\?rev=6001">rev\n6001</a>\.},
     "Check for split line log mesage SVNWeb URL");
unlike($email,
       qr{<a href="http://svn\.example\.com/index\.cgi/revision/\?rev=200">rev 200</a>,},
       "Check for no rev 200 SVNWeb URL");

##############################################################################
# Try max_diff_length
#############################################################################
ok $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
    max_diff_length => 512,
    with_diff       => 1,
), 'Construct new max_diff_length notifier';

isa_ok $notifier, 'SVN::Notify';
isa_ok $notifier, 'SVN::Notify::HTML';
is $notifier->max_diff_length, 512, 'max_diff_hlength should be set';
ok $notifier->with_diff, 'with_diff should be set';
ok $notifier->prepare, 'Prepare max_diff_length checking';
ok $notifier->execute, 'Notify max_diff_length checking';

# Check the output.
$email = get_output();
like $email, qr{Use Apache::RequestRec for mod_perl 2},
    'Check for the last diff line';
unlike $email, qr{ BEGIN }, 'Check for missing extra line';
like $email, qr{Diff output truncated at 512 characters.},
    'Check for truncation message';

##############################################################################
# Try wrapping the log message.
##############################################################################
ok $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
    revision => 222,
    wrap_log => 1,
), 'Constructe new HTML wrapped log notifier';
isa_ok($notifier, 'SVN::Notify::HTML::ColorDiff');
isa_ok($notifier, 'SVN::Notify::HTML');
isa_ok $notifier, 'SVN::Notify';
ok $notifier->wrap_log, 'wrap_log should be true';
ok $notifier->prepare, 'Prepare HTML header and footer checking';
ok $notifier->execute, 'Notify HTML header and footer checking';

# Check the output.
$email = get_output();
$email = get_output();
like( $email,
      qr{<p>Hey, we could add one for a Subversion Revision # 606, too!</p>

<p>And finally, we have RT-Ticket: 123 for Jesse and RT # 445 for Ask\.
And we even have Mantis-161: foo bar baz for Dirk Olmes\.</p>},
      'The log message should be in paragraph tags'
);

##############################################################################
# Major linkize and Bug tracking URLs, as well as complex diff.
##############################################################################
my $year = 1900 + (localtime)[5];
ok( $notifier = SVN::Notify::HTML::ColorDiff->new(
    %args,
    with_diff    => 1,
    revision     => 444,
    linkize      => 1,
    wrap_log     => 1,
    viewcvs_url  => 'http://viewsvn.bricolage.cc/?rev=%s&view=rev',
    rt_url       => 'http://rt.cpan.org/NoAuth/Bugs.html?id=%s',
    bugzilla_url => 'http://bugzilla.mozilla.org/show_bug.cgi?id=%s',
    jira_url     => 'http://jira.atlassian.com/secure/ViewIssue.jspa?key=%s',
    ticket_url   => 'http://ticket.example.com/id=%s',
    ticket_regex => '\[?\s*(Custom\s*#\s*(\d+))\s*\]?',
    header       => 'This commit is brought to you by Kineticode. '
                  . 'Setting knowledge in motion.',
    footer       => "<span>Copyright &reg; Kineticode, Inc., 2004-$year. "
                  . 'Some rights reserved.</span>',
),
    "Construct new complex notifier" );
isa_ok($notifier, 'SVN::Notify::HTML');
isa_ok($notifier, 'SVN::Notify');
ok( $notifier->prepare, "Prepare complex example" );
ok( $notifier->execute, "Notify complex example" );

$email = get_output();
# Make sure multiple lines are paragraphs!
like($email, qr{link\.</p>\n\n<p>We}, "Check for multiple paragraphs" );

# Make sure we have good unicode characters.
UTF8: {
    use utf8;
    like $email, qr{“Unicode characters”}, 'We should have Unicode';
}

# Make sure that binary files in the diff are set up properly.
like($email,
     qr{<div class="binary"><h4>Deleted: trunk/SVN-Notify/t/data/bin/sendmail\.exe</h4>},
     "Check for binary file div");

# Make sure that copied files in the diff are set up properly.
like($email,
     qr{<div class="copfile"><h4>Copied: trunk/TestSimple/doc/pod/Test/Builder\.pod \(1634 => 1646\)</h4>},
     "Check for copied file div");

# Check linkize results.
like($email, qr|<a href="mailto:recipient\@example\.com">recipient\@example\.com</a>\.|,
     "Check for linked email address");
like($email, qr{<a href="http://www\.kineticode\.com/">http://www\.kineticode\.com/</a>\!},
     "Check for linked URL" );
like($email,
     qr{<a href="http://www\.example\.com/my\.pl\?one=1&amp;two=2&amp;f=w\*\*t">http://www\.example\.com/my\.pl\?one=1&amp;two=2&amp;f=w\*\*t</a>\.},
     "Check for fancy linked URL" );

# Check for RT URLs.
like($email,
     qr{<a href="http://rt\.cpan\.org/NoAuth/Bugs\.html\?id=6">Ticket # 6</a>,},
     "Check for first RT URL");
like($email,
     qr{<a href="http://rt\.cpan\.org/NoAuth/Bugs\.html\?id=12">Ticket\n12</a>,},
     "Check for split RT URL");
unlike($email,
     qr{<a href="http://rt\.cpan\.org/NoAuth/Bugs\.html\?id=69">ticket 69</a>},
     "Check for no Ticket 69 URL");
like($email,
     qr{<a href="http://rt\.cpan\.org/NoAuth/Bugs\.html\?id=23">RT-Ticket: #23</a>},
     "Check for Jesse's RT URL");
like($email,
     qr{<a href="http://rt\.cpan\.org/NoAuth/Bugs\.html\?id=45">RT #45</a>},
     "Check for Ask's RT URL");

# Check for ViewCVS URLs.
like( $email,
      qr|<dt>Revision</dt>\s+<dd><a href="http://viewsvn\.bricolage\.cc/\?rev=444\&amp;view=rev">444</a></dd>\n|,
      'Check for main ViewCVS URL');
like($email,
     qr{<a href="http://viewsvn\.bricolage\.cc/\?rev=6000&amp;view=rev">Revision 6000</a>\.},
     "Check for first log mesage ViewCVS URL");
like($email,
     qr{<a href="http://viewsvn\.bricolage\.cc/\?rev=6001&amp;view=rev">rev\n6001</a>\.},
     "Check for split line log mesage ViewCVS URL");
unlike($email,
       qr{<a href="http://viewsvn\.bricolage\.cc/\?rev=200&amp;view=rev">rev 200</a>,},
       "Check for no grev 200 ViewCVS URL");

# Check for Bugzilla URLs.
like( $email,
      qr{<a href="http://bugzilla\.mozilla\.org/show_bug\.cgi\?id=1234">Bug # 1234</a>},
      "Check for first Bugzilla URL" );
like( $email,
      qr{<a href="http://bugzilla\.mozilla\.org/show_bug\.cgi\?id=8">bug 8</a>,},
      "Check for second Bugzilla URL" );
unlike( $email,
      qr{<a href="http://bugzilla\.mozilla\.org/show_bug\.cgi\?id=3">bug 3</a>\.},
      "Check for no humbug URL" );
like( $email,
      qr{<a href="http://bugzilla\.mozilla\.org/show_bug\.cgi\?id=4321">Bug\n#4321</a>},
      "Check for split line Bugzilla URL" );

# Check for JIRA URLs.
like( $email,
      qr{<a href="http://jira\.atlassian\.com/secure/ViewIssue\.jspa\?key=TST1234-111">TST1234-111</a>\.},
      "Check for Jira URL" );
unlike( $email,
      qr{<a href="http://jira\.atlassian\.com/secure/ViewIssue\.jspa\?key=JRA-\n4321">JRA-\n4321-1234</a>},
      "Check for no split line Jira URL" );
unlike( $email,
      qr{<a href="http://jira\.atlassian\.com/secure/ViewIssue\.jspa\?key=studlyCAPS-1234">studlyCAPS-1234</a>\.},
      "Check for no studlyCAPS Jira URL" );

# Check for custom ticket URLs.
like( $email,
      qr{<a href="http://ticket\.example\.com/id=54321">Custom # 54321</a>},
      "Check for custom ticket URL" );

unlike $email, qr{<p></p>}, 'There should be no empty paragraphs';

##############################################################################
# Functions.
##############################################################################

sub get_output {
    my $outfile = catfile qw(t data output.txt);
    open CAP, "<$outfile" or die "Cannot open '$outfile': $!\n";
    binmode CAP, 'utf8' if SVN::Notify::PERL58();
    return join '', <CAP>;
}
