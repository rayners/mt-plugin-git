
package Git::Util;

use strict;
use warnings;

use File::Basename;
use File::Spec;

sub post_save_entry {
    my ( $cb, $app, $entry, $orig ) = @_;

    my $repo_path = __repo_path( $entry->blog );
    return 1 unless $repo_path;    # no repo, skip out

    my $file_path = __path_in_repo($entry);
    return 1 unless $file_path;    # no path in the repo, skip out

    my $fmgr = $entry->blog->file_mgr;

    my $file = File::Spec->catfile( $repo_path, $file_path );
    my $adding = !-f $file;        # if it doesn't exist, we're adding it

    # does the directory exist?
    my $path = dirname($file);

    # create it if it doesn't
    $fmgr->mkpath($path) if !-d $path;

    # now we write it
    $fmgr->put_data( $entry->text . "\n" . $entry->text_more, $file );

    require Git::Wrapper;
    my $git = Git::Wrapper->new($repo_path);

    $git->add($file_path) if ($adding);

    $git->commit({ all => 1, message => "Entry saved" });

    return 1;
}

sub __repo_path {
    my ($blog) = @_;

    my $p = MT->component('Git');
    my $local_git_repo
        = $p->get_config_value( 'local_git_repo', 'blog:' . $blog->id );
    return unless $local_git_repo;

    # if the path doesn't exist
    my $fmgr = $blog->file_mgr;
    if ( !-d $local_git_repo ) {
        $fmgr->mkpath($local_git_repo);

        # need to init the git repo
        require Git::Wrapper;
        my $git = Git::Wrapper->new($local_git_repo);
        my $res = $git->init;

    }

    return $local_git_repo;

}

sub __path_in_repo {
    my ($entry) = @_;

    # let's just use the filetemplate bits
    # make it easy :)

    my $a = MT->publisher->archiver('Individual');

    # do we add a file extension?
    my $str = '<mt:filetemplate format="%y/%m/%_b">';

    require MT::Builder;
    require MT::Template::Context;

    my $ctx     = MT::Template::Context->new;
    $ctx->stash( 'entry',   $entry );
    $ctx->stash( 'blog',    $entry->blog );
    $ctx->stash( 'blog_id', $entry->blog_id );

    my $f = $a->archive_file($ctx);

    return $f;
}

1;
