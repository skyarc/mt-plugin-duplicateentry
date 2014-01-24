package MT::Plugin::SKR::DuplicateEntry;
# DuplicateEntry - Move or Duplicate the entries and pages between blogs
#       Copyright (c) 2008-2011 SKYARC System Co.,Ltd.
#       http://www.skyarc.co.jp/engineerblog/entry/duplicateentry.html

use strict;
use MT 5;
use MT::Entry;
use MT::Blog;
use MT::Placement;
use MT::Permission;
use MT::WeblogPublisher;
use MT::I18N;
use MT::ConfigMgr;
use Data::Dumper;#DEBUG
use MT::Log;

use MT::Util;

use constant PREFIX_OF_COPY => '(Copy) ';

use vars qw( $MYNAME $VERSION );
$MYNAME = 'DuplicateEntry';
$VERSION = '2.11';

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new({
        name => $MYNAME,
        id => lc $MYNAME,
        key => lc $MYNAME,
        version => $VERSION,
        author_name => 'SKYARC System Co.,Ltd.',
        author_link => 'http://www.skyarc.co.jp/',
        doc_link => 'http://www.skyarc.co.jp/engineerblog/entry/duplicateentry.html',
        description => <<HTMLHEREDOC,
<__trans phrase="Move or Duplicate the entries and webpages between blogs">
HTMLHEREDOC
        l10n_class => $MYNAME. '::L10N',
});
MT->add_plugin( $plugin );

sub instance { $plugin; }

### Registry
sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        callbacks => {
            'MT::App::CMS::template_param.edit_entry' => \&_hdlr_template_param_edit_entry,
        },
        applications => {
            cms => {
               list_actions => {
                    entry => {
                        duplicate_move => {
                            label       => 'Duplicate or Move',
                            order       => 100,
                            code        => \&_hdlr_configure,
                            permission  => 'edit_all_posts',
                            condition   => sub {
                                my $app = MT->instance;
                                $app->isa('MT::App') or return 0;
                                return $app->mode ne 'view';
                            },
                        },
                    },
                    page => {
                        duplicate_move => {
                            label       => 'Duplicate or Move',
                            order       => 100,
                            code        => \&_hdlr_configure,
                            permission  => 'manage_pages',
                            condition   => sub {
                                my $app = MT->instance;
                                $app->isa('MT::App') or return 0;
                                return $app->mode ne 'view';
                            },
                        },
                    },
                },
                methods => {
                    duplicate_mode_copy   => \&_hdlr_duplicate_mode,
                    duplicate_mode_move   => \&_hdlr_duplicate_mode,
                    duplicate_mode_cancel => \&_hdlr_duplicate_mode,
                },
                list_filters => {
                    log => {
                       dup_entry => {
                           label => 'Copy log only',
                           handler => \&_hdlr_log_filter,
                       },
                    },
        },
            },
        },
    });
}

sub _hdlr_template_param_edit_entry {
    my ($cb , $app ,$param , $tmpl ) = @_;
 
    my $flag = $param->{can_edit_all_posts} || 0;
    $flag = $param->{can_manage_pages} || 0 if $param->{object_type} eq 'page';
    $param->{duplicate_copy_link} = '';
    if ( $flag ) {

        ## see ReplaceableVersion/tmpl/widget/edit_entry_replaceable_versions.tmpl
        $param->{duplicate_copy_link} = $app->uri( 
            mode => 'duplicate_mode_copy',
            args => {
                blog_id => $param->{blog_id},
                from => 'edit_' . $param->{object_type},
                id => $param->{id},
                magic_token => $param->{magic_token},
                return_args => $param->{return_args},
            },
        );
        $param->{duplicate_copy_link_label} = $plugin->translate('Duplicate this page');
    }
    1;
}

### Handler - duplicate_move
sub _hdlr_configure {
    my ($app) = @_;
    my $q = $app->{query};

    my %param;
    $param{return_args} = $q->param ('return_args');
    my $blog_id = ( $app->blog 
         && $app->blog->id ) 
         || $app->param('blog_id') 
         || 0;

    # List of entries
    my @eids = $q->param ('id');
    my @items;
    my $type = '';
    foreach (@eids) {
        my $entry = MT::Entry->load ({ id => $_ })
            or next;
        unless ( $type ) {
           $type = $entry->can('class') && $entry->class eq 'page'
                 ? 'page' : 'entry';
        }
        push @items, {
            id => $entry->id,
            name => $entry->title || '...',
        };
    }
    $type = 'entry' unless $type;
    $param{type}  = $type;
    $param{items} = \@items;

    # List blogs
    my $user = $app->user;
    my $terms = {};

    ## バージョンによる制限
    $terms->{class} = '*';
    $terms->{class} = 'blog'
        if $type eq 'entry'
        && $MT::VERSION >= 5.0 
        && $MT::VERSION < 6;
 
    my @blogs;
    my $blog_iter = MT::Blog->load_iter( $terms );
    while ( my $blog = $blog_iter->() ) {

          ## special
          unless ( $user->is_superuser ) {

              ## adminnistrator
              my $perm = MT::Permission->load({ author_id => $user->id , blog_id => 0 });

              ## entry or page post
              unless ( $perm ) {
                   $perm = MT::Permission->load({ author_id => $user->id , blog_id => $blog->id })
                       or next;

                   if ( $type eq 'entry' ) {
                       $perm->can_post or next;
                   } else {
                       $perm->can_manage_pages or next;
                   }
              }
          }
          push @blogs , { 
              id => $blog->id,
              name => $blog->name,
              selected => $blog->id == $blog_id ? 1 : 0,
          };
    }

    $param{blogs} = \@blogs;
    &instance->load_tmpl ('duplicate_entry.tmpl', \%param);
}

### Application Methods - duplicate_mode_*
sub _hdlr_duplicate_mode {
    my ($app) = @_;
    my $q = $app->{query};
    $app->return_args ($q->param ('return_args'));

    return unless $app->validate_magic();

    my $target_blog_id = $q->param ('blog_id');
    my $mode = $q->param('__mode') || '';
    $target_blog_id || $mode
        or return $app->redirect ($app->return_uri); #error

    my $charset = {
        'shift_jis' => 'sjis',
        'iso-2022-jp' => 'jis',
        'euc-jp' => 'euc',
        'utf-8' => 'utf8'
    }->{lc MT::ConfigMgr->instance->PublishCharset} || 'utf8';

    my $user = $app->user
        or return $app->error($app->translate("Login Required."));

    # Move/Duplicate entries
    my @eids = $q->param ('id');
    my $type = 'entry';
    my $redirect_object = '';
    my %rebuild_recipe; ## 記事移動用の再構築情報を格納
    foreach (@eids) {
        my $original = MT::Entry->load ({ id => $_ })
            or next;
        my $entry = $original->clone;
        $type = $entry->class || 'entry';

        # source permission check.
        _check_permission($user, $entry->blog_id, "edit_all_posts")
            or return $app->error($app->translate("Permission denied."));
        # target permission check.
        my $type = $entry->class;
        my $perm_name = _perm_name_for_type($type);
        _check_permission($user, $target_blog_id, $perm_name)
            or return $app->error($app->translate("Permission denied."));

        $entry->status (MT::Entry::HOLD());

        # Workflow plugin features
        if ($entry->can ('workflow_id')) {
            $entry->workflow_id (0);
            $entry->workflow_level (0);
            $entry->workflow_approved_id (0);
        }
        # GetLock
        if ($entry->can ('locked_by')) {
            $entry->locked_by(undef);
            $entry->locked_on(undef);
        }
        # ReplaceableVersion
        $entry->rep_archived(0) if $entry->can('rep_archived');

        if ($mode eq 'duplicate_mode_move') {


            # do nothing.
            next if $entry->blog_id == $target_blog_id;

            ## 移動元から不要な情報を削除
            if ( $entry->class eq 'entry' ) {
                 my %recipe = $app->publisher->rebuild_deleted_entry(
                    Entry => $original,
                    Blog  => $original->blog
                 ) if $original->status eq MT::Entry::RELEASE();

                 ## 削除予定のentry_idは除外する
                 for ( keys %{$recipe{Individual}} ) {
                     my $e_id = $_ or next;
                     if ( scalar grep { $e_id == $_ } @eids ) {
                         delete $recipe{Individual}{$e_id};
                     }
                 }

                 my $child_hash = $rebuild_recipe{ $original->blog->id } || {};
                 MT::__merge_hash( $child_hash, \%recipe );
                 $rebuild_recipe{ $original->blog->id } = $child_hash;
            }
            else {
                my $blog = $original->blog;
                my $at = $blog->archive_type;
                my $is_page_archive = 0;;
                if ( $at && $at ne 'None' ) {
                    my @at_orig = split( /,/, $at );
                    $is_page_archive = 1 if scalar grep { 'Page' } @at_orig;
                }

                if ( $is_page_archive ) {
                    $app->publisher->remove_fileinfo(
                        ArchiveType => 'Page',
                        Blog        => $blog->id,
                        Entry       => $original->id
                    );
                    if ( $app->config('DeleteFilesAtRebuild') ) {
                        $app->publisher->remove_entry_archive_file(
                            Entry       => $original,
                            ArchiveType => 'Page'
                        );
                        my %recipe;
                        if ( my $prev = $original->previous(1) ) {
                           my $prev_id = $prev->id || 0;
                           unless ( scalar grep { $prev_id == $_ } @eids ) { 
                               $recipe{Page}{ $prev->id }{id} = $prev_id;
                           }
                        }
                        if ( my $next = $original->next(1) ) {
                           my $next_id = $next->id || 0;
                           unless ( scalar grep { $next_id == $_ } @eids ) {
                               $recipe{Page}{ $next->id }{id} = $next_id;
                           }
                        }

                        if ( scalar keys %recipe ) {
                            my $child_hash = $rebuild_recipe{ $original->blog->id } || {};
                            MT::__merge_hash( $child_hash, \%recipe );
                            $rebuild_recipe{ $original->blog->id } = $child_hash;
                        }

                    }
                }
            } 

            # Remove of Category placements when moved to other blog
            if ($entry->blog_id != $target_blog_id) {
                map {
                    $_->remove;
                } MT::Placement->load ({ entry_id => $entry->id });

                ## cleanup
                $entry->clear_cache('category');
                $entry->clear_cache('categories');
            }
            my @tags = $entry->get_tags;
            $entry->blog_id ($target_blog_id);
            $entry->set_tags (@tags); # Clone of Tag

            # 19370 assign current user ID to duplicated entry.
            $entry->author_id($app->user->id);
            my $ts = MT::Util::epoch2ts ($entry->blog, time);
            $entry->created_on($ts);
            $entry->created_by( $app->user->id );
            $entry->modified_on($ts);
            $entry->modified_by( $app->user->id );

            ## MT6対応
            if ( $MT::VERSION >= 6 ) {
                ## 公開終了ステータスはそのまま引き継ぐ
                if ( ($original->status || 0)  == 6 ) {
                    $entry->status( $original->status );
                }
            }

            $app->run_callbacks(
                'duplicate_entry_pre_save',
                $app,
                $mode,
                $entry,
                $original,
            ) or return $app->error(
                $plugin->translate(
                    "Duplicate Entry: Failed to save moved entry (ID [_1]) : [_2]",
                    $original->id,
                    $entry->errstr,
                )
            );

            $entry->save
                or return $app->error( $plugin->translate("Duplicate Entry: Failed to save moved entry (ID [_1]) : [_2]", $original->id, $entry->errstr ));

            # 20776
            # duplicate comments and trackback.
            _duplicate_comment_on_entry( $app , $mode , $original , $entry) or return;
            _duplicate_trackback_on_entry( $app , $mode , $original , $entry) or return;
            _remove_revision_on_entry( $entry );
            _duplicate_revision_start_entry($app, $mode, $entry, $original);

            my $class_name = $plugin->translate($entry->class);
            my $blog_class_name = $plugin->translate($entry->blog->class);
            doLog( $original->blog_id, $app->user, 
                $plugin->translate("Duplicate Entry: [_6] [_1] (ID [_2]) is moved to the [_7] [_3] (ID [_4]) by [_5]"
                     , $original->title
                     , $original->id
                     , $entry->blog->name
                     , $original->blog_id
                     , $app->user->nickname
                     , $class_name
                     , $blog_class_name ));

        }
        elsif ($mode eq 'duplicate_mode_copy') {
            my $clone = $entry->clone;

            $clone->id (undef);
            ## change the base name                 
            my $class = MT->model($clone->class);
            my $exist =
                  $class->exist( { blog_id => $clone->blog_id, basename => $clone->basename } );
            $clone->basename( MT::Util::make_unique_basename( $clone ) ) if $exist;

            $clone->title (MT::I18N::encode_text (PREFIX_OF_COPY, 'utf8', $charset). $entry->title);

            my @tags = $entry->get_tags;
            $clone->blog_id ($target_blog_id);
            $clone->set_tags (@tags); # Clone of Tag
            # 19370 assign current user ID to duplicated entry.
            $clone->author_id($app->user->id);

            my $ts = MT::Util::epoch2ts ($clone->blog, time);
            $clone->created_on($ts);
            $clone->created_by( $app->user->id );
            $clone->modified_on($ts);
            $clone->modified_by( $app->user->id );

            ## MT6の場合はリセット
            if ( $MT::VERSION >= 6 ) {
                $clone->unpublished_on( undef );
            }

            $app->run_callbacks(
                'duplicate_entry_pre_save',
                $app,
                $mode,
                $clone,
                $original,
            ) or return $app->error(
                $plugin->translate(
                    "Duplicate Entry: Failed to save original object (ID [_1]) : [_2]",
                    $original->id,
                    $original->errstr,
                )
            );

            $original->save
                or return $app->error($plugin->translate('Duplicate Entry: Failed to save original object (ID [_1]) : [_2]', $original->id, $original->errstr));
            $clone->save
                or return $app->error($plugin->translate('Duplicate Entry: Failed to save copied object (ID [_1]) : [_2]', $clone->id, $clone->errstr));

            $redirect_object = $clone;
            # Clone of Category placements when copying in same blog
            if ($entry->blog_id == $clone->blog_id) {
                map {
                    my $clone_placement = $_->clone;
                    $clone_placement->id (undef);
                    $clone_placement->entry_id ($clone->id);
                    $clone_placement->save;
                } MT::Placement->load ({ entry_id => $entry->id });
            }

            # 19374
            # duplicate revisions
            if ( $entry->blog_id == $clone->blog_id ) { 
               _duplicate_revisions_on_entry($app, $entry, $clone) or return;
            }
            else {
               _duplicate_revision_start_entry($app, $mode, $clone , $entry);
            }
            # 20776
            # duplicate comments and trackback.
            _duplicate_comment_on_entry( $app , $mode , $entry , $clone) or return;
            _duplicate_trackback_on_entry( $app , $mode , $entry , $clone) or return;

            $entry = $clone;

            my $class_name = $plugin->translate($entry->class);
            doLog( $original->blog_id, $app->user, 
                $plugin->translate("Duplicate Entry: [_6] [_1] (ID [_2]) is copied by [_3] : [_4] (ID [_5])"
                    , $original->title
                    , $original->id
                    , $app->user->nickname
                    , $entry->title
                    , $entry->id
                    , $class_name ));

        }

        $app->run_callbacks(
            'duplicate_entry_post_save',
            $app,
            $mode,
            $entry,
            $original,
        );

    }

    ## duplicate_mode_move 再構築
    if ( $mode eq 'duplicate_mode_move' && scalar keys %rebuild_recipe ) {

        my $blog = MT::Blog->load( { id => $target_blog_id } );
        my $can_background
        = ( ( $blog 
            && (( $type eq 'entry' && $blog->count_static_templates('Individual') == 0 )
            ||  ( $type eq 'page'  && $blog->count_static_templates('Page') == 0 )) )
            || MT::Util->launch_background_tasks() ) ? 1 : 0;

        if ( $app->config('RebuildAtDelete') ) {
            $app->run_callbacks('pre_build');
            my $rebuild_func = sub {
                foreach my $b_id ( keys %rebuild_recipe ) {
                    my $b   = MT::Blog->load($b_id);
                    my $res = $app->rebuild_archives(
                        Blog   => $b,
                        Recipe => $rebuild_recipe{$b_id},
                    ) or return $app->publish_error();
                    $app->rebuild_indexes( Blog => $b )
                        or return $app->publish_error();
                    $app->run_callbacks( 'rebuild', $b );
                }
            };

            if ($can_background) {
                MT::Util::start_background_task($rebuild_func);
            }
            else {
                $rebuild_func->();
            }

            if ( $redirect_object && $app->return_args =~ m!__mode=view! ) {
                $app->{return_args} = '';
                $app->add_return_arg(
                    _type => $redirect_object->class,
                    id =>  $redirect_object->id,
                    blog_id => $redirect_object->blog_id,
                    duplicate_entry => 1,
                    no_rebuild => 1
                );
            }
            else {
                $app->add_return_arg( saved => 1 , no_rebuild => 1 );
            }

            my %params = (
                is_full_screen  => 1,
                redirect_target => $app->base
                    . $app->path
                    . $app->script . '?'
                    . $app->return_args,
            );
            return $app->load_tmpl( 'rebuilding.tmpl', \%params );
        }
    }

    ## Redirected to the destination page. ( PageAction )
    if( $redirect_object && $app->return_args =~ m!__mode=view! ) {
        return $app->redirect($app->uri(
            mode => 'view',
            args => {
               _type => $redirect_object->class,
               id => $redirect_object->id,
               blog_id => $redirect_object->blog_id,
               duplicate_entry => 1,
        }));
    }
    return $app->redirect ($app->return_uri. '&saved=1');
}

sub _remove_revision_on_entry {
    my $entry = shift;
    $entry->mt_postremove_obj($entry);
}


# duplicate binded revisions when entry was duplicated.
sub _duplicate_revisions_on_entry {
    my ($app, $entry, $new_entry) = @_;

    my $rev_class = MT->model($entry->datasource . ':revision');
    my $iter = $rev_class->load_iter({$entry->datasource . '_id' => $entry->id} , { sort => 'created_on' , direction => 'ascend'});

    my $revision_number = 0;
    while( my $entry_rev = $iter->() ) {
        my $cloned = $entry_rev->clone;
        $cloned->entry_id($new_entry->id);
        $cloned->id(undef);
        my $data = MT::Serialize->unserialize($cloned->entry);
        ${$data}->{id} = $new_entry->id;
        ${$data}->{basename} = $new_entry->basename;

        if ( $entry->can('locked_by') ) {
           ${$data}->{locked_by} = undef;
           ${$data}->{locked_on} = undef;
        }
        if ( $entry->can('workflow_id') ) {
           ${$data}->{workflow_id} = 0;
           ${$data}->{workflow_level} = 0;
           ${$data}->{workflow_approved_id} = 0;
        }
        if ( $entry->can('ml_entry_id') ) {
           ${$data}->{ml_entry_id} = $new_entry->ml_entry_id;
        }
        if ( $entry->can('rep_archived') ) {
           ${$data}->{rep_archived} = 0;
        }
        ${$data}->{comment_count} = 0;
        ${$data}->{ping_count} = 0;

        $cloned->entry(MT::Serialize->serialize($data));
        $cloned->rev_number( ++$revision_number );
        $cloned->save
            or return $app->error($plugin->translate('Failed to duplicate entry revision' ));
    }
    if ( $revision_number ) {
        $new_entry->current_revision( $revision_number );
    }
    _duplicate_revision_start_entry($app, 'duplicate_mode_copy', $new_entry, $entry);
    return 1;
}

sub _duplicate_revision_start_entry {
    my ($app, $mode, $entry, $orig ) = @_;

    my $note = '';
    my $blog = $orig->blog;
    $entry->{changed_revisioned_cols} = [ 'status' ];
    if ( $mode eq 'duplicate_mode_move' ) {
       $note = $entry->class eq 'entry'
           ? $plugin->translate('The entry has moved from the [_3] ([_1] ID: [_2])'
                ,$blog->name
                ,$blog->id
                ,$blog->class_label )
           : $plugin->translate('The page has moved from the [_3] ([_1] ID: [_2])'
                ,$blog->name
                ,$blog->id
                ,$blog->class_label );
    } else {
       $note = $entry->class eq 'entry'
           ? $plugin->translate('Duplication of entry in ([_1] ID: [_2]) and ([_3] ID: [_4]) [_5]'
                ,$orig->title
                ,$orig->id
                ,$blog->name
                ,$blog->id
                ,$blog->class_label)
           : $plugin->translate('Duplication of page in ([_1] ID: [_2]) and ([_3] ID: [_4]) [_5]'
                ,$orig->title
                ,$orig->id
                ,$blog->name
                ,$blog->id
                ,$blog->class_label);
    }
    $app->param( 'revision-note', $note ) if $app->isa('MT::App');
    $entry->mt_postsave_obj( $app , $entry , $orig);
    return 1;
}

sub _duplicate_comment_on_entry {
    my ( $app , $mode , $entry , $new_entry ) = @_;

    if ( $mode eq 'duplicate_mode_copy' ) {

        $new_entry->comment_count( 0 );
        $new_entry->save 
           or return $app->error($plugin->translate('Duplicate Entry: Failed to reset the count of comments. (ID [_1]) : [_2]', $new_entry->id, $new_entry->errstr)); 

        return 1;
    }

    ## mode : duplicate_mode_move
    my $class = MT->model('comment');
    my $iter = $class->load_iter({ blog_id => $entry->blog_id , entry_id => $entry->id })
       or return 1;

    while ( my $comment = $iter->() ) {

        $comment->entry_id ( $new_entry->id );
        $comment->blog_id ( $new_entry->blog_id );
        $comment->save
           or return $app->error($plugin->translate( 'Duplicate Entry: Fails to move the comment. (ID [_1]) : [_2]' , $comment->id , $comment->errstr ));

    }
    return 1;
} 

sub _duplicate_trackback_on_entry {
    my ( $app , $mode , $entry , $new_entry ) = @_;  

    if ( $mode eq 'duplicate_mode_copy' ) {

        $new_entry->ping_count( 0 );
        $new_entry->save
           or return $app->error($plugin->translate( 'Duplicate Entry: Fails to reset the count of pings. (ID [_1]) : [_2]' , $new_entry->id , $new_entry->errstr ));

        return 1;
    }

    ## mode : duplicate_mode_move 
    my $class = MT->model('trackback');
    my $ping_class = MT->model('tbping');
    my $iter = $class->load_iter({ blog_id => $entry->blog_id , entry_id => $entry->id })
       or return 1;

    while ( my $tb = $iter->() ) {

        $tb->entry_id ( $new_entry->id );
        $tb->blog_id ( $new_entry->blog_id );
        $tb->url( $new_entry->permalink );
        $tb->save
            or return $app->error($plugin->translate( 'Duplicate Entry: Fails to move the trackback. (ID [_1]) [_2]' , $tb->id , $tb->errstr ));

        my $ping_iter = $ping_class->load_iter({ blog_id => $entry->blog_id , tb_id => $tb->id })
            or return 1;

        while ( my $ping = $ping_iter->() ) {

           $ping->blog_id( $new_entry->blog_id );
           $ping->save
               or return $app->error($plugin->translate( 'Duplicate Entry: Fails to move the trackback ping. (ID [_1]) [_2]' , $ping->id , $ping->errstr ));

        }

    }
    return 1;
}


sub doLog {
    my ($blog_id, $author, $message , $metadata ) = @_;

    my $log = new MT::Log;
    $log->message ($message);
    $log->ip ($ENV{REMOTE_ADDR});
    $log->blog_id ($blog_id);
    $log->author_id ($author->id);
    $log->level (MT::Log::INFO());
    $log->category ('duplicate_entry');
    $log->class ('system');
    my @t = gmtime;
    my $ts = sprintf '%04d%02d%02d%02d%02d%02d', $t[5]+1900,$t[4]+1,@t[3,2,1,0];
    $log->created_on ($ts);
    $log->created_by ($author->id);
    $log->metadata( $metadata ) if $metadata;
    $log->save;
}

### Space and CR,LF trimmed quotemeta
sub trimmed_quotemeta {
    my ($str) = @_;
    $str = quotemeta $str;
    $str =~ s/(\\\s)+/\\s+/g;
    $str;
}

# quick filter for log
sub _hdlr_log_filter {
    my ($terms, $args) = @_;

    $terms->{category} = 'duplicate_entry';
}

# check permission
sub _check_permission {
    my ($user, $blog_id, $perm_name) = @_;

    my $blog = MT::Blog->load($blog_id);

    return 0 unless $blog && $blog_id;
    return 0 unless $perm_name;

    my $perm = $user->permissions(0);
    if ($user->is_superuser || ($perm and $perm->can_do('administer')) ) {
        return 1;
    }

    if( $blog ) {
        $perm = $user->permissions($blog->id);
        if ($perm)  {
            if ( $perm->can_do('administer') ) {
                return 1;
            }
            if( $blog->is_blog
                  ? $perm->can_do('administer_blog')
                  : $perm->can_do('administer_website') ) {
                return 1;
            }
        }

        return 1 if $perm && $perm->can_do($perm_name);
    }

    # never reach here.
    return 0;
}


my $PERM_NAMES = {
    entry => 'create_post',
    page => 'manage_pages',
};

# return sufficient permssion name for specified object type.
sub _perm_name_for_type {
    my ($type) = @_;

    return $PERM_NAMES->{$type};
}

1;
