package DuplicateEntry::L10N::ja;

use strict;
use base 'DuplicateEntry::L10N';
use vars qw( %Lexicon );

our %Lexicon = (

    'The entry has moved from the [_3] ([_1] ID: [_2])' => 'ブログ記事を「[_1]:ID [_2]」[_3]から移動',
    'The page has moved from the [_3] ([_1] ID: [_2])' => 'ウェブページを「[_1]:ID [_2]」[_3]から移動',

    'Duplication of entry in ([_1] ID: [_2]) and ([_3] ID: [_4]) [_5]'
       => '[_3](ID:[_4])[_5]の[_1](ID:[_2])記事を複製',   

    'Duplication of page in ([_1] ID: [_2]) and ([_3] ID: [_4]) blog'
       => '[_3](ID:[_4])[_5]の[_1](ID:[_2])ウェブページを複製',   

    'Failed to duplicate entry revision' => '変更履歴の複製に失敗しました。', 

    'Are you sure to duplicate this item ?' => '複製を行います。よろしいですか？',
    'Move or Duplicate the entries and webpages between blogs' => 'ブログ記事やウェブページをブログ間で複製したり移動します',
    'Duplicate or Move' => '複製または移動',
#
    'Action will apply these items below' => '以下のアイテムに適用されます',
    'Select the target blog' => '複製または移動先のブログを選択',
    'Actions' => 'アクション',
    'Duplicate' => '複製',
    'Duplicate this page' => 'このページを複製する',
    'Move' => '移動',
    'Cancel' => 'キャンセル',
    'Copy log only' => '複製ログのみを表示',
    "Failed to save moved entry (ID [_1]) : [_2]" => 'エントリの複製：移動したエントリ(ID [_1])の保存に失敗しました：[_2]',
    'Duplicate Entry: Failed to save original object (ID [_1]) : [_2]' => 'エントリの複製：複製元のエントリ／ページの変更に失敗しました (ID [_1])：[_2]',
    'Duplicate Entry: Failed to save copied object (ID [_1]) : [_2]' => 'エントリの複製：複製したエントリ／ページの保存に失敗しました (ID [_1])：[_2]',
    "Duplicate Entry: [_6] [_1] (ID [_2]) is moved to the [_7] [_3] (ID [_4]) by [_5]" => 'エントリの複製：[_5] が[_6]「[_1]」(ID: [_2]) を[_7]「[_3]」(ID: [_4])に移動しました。',
    "Duplicate Entry: [_6] [_1] (ID [_2]) is copied by [_3] : [_4] (ID [_5])" => 'エントリの複製：[_3] が[_6]「[_1]」(ID: [_2])を複製しました：「[_4]」 (ID: [_5])',
    'entry' => "ブログ記事",
    'page' => "ウェブページ",
    'blog' => 'ブログ',
    'website' => 'ウェブサイト',


   ## comment copy move and reset count.
   'Duplicate Entry: Failed to reset the count of comments. (ID [_1]) : [_2]'
        => 'エントリの複製: 複製したエントリ/ウェブページにおいて、コメント件数のリセットに失敗しました。(ID [_1]) : [_2]',
   'Duplicate Entry: Fails to move the comment. (ID [_1]) : [_2]'
        => 'エントリの複製: 移動したエントリ/ウェブページに関係するコメントの移動に失敗しました。(ID [_1]) : [_2]',

   ## trackback  move and reset count.
   'Duplicate Entry: Fails to reset the count of pings. (ID [_1]) : [_2]'
        => 'エントリの複製: 複製したエントリ/ウェブページにおいて、トラックバック件数のリセットに失敗しました。(ID [_1]) : [_2]',
   'Duplicate Entry: Fails to move the trackback. (ID [_1]) [_2]'
        => 'エントリの複製: 移動したエントリ/ウェブページに関係するトラックバックの移動に失敗しました。(ID [_1]) : [_2]',
   'Duplicate Entry: Fails to move the trackback ping. (ID [_1]) [_2]'
        => 'エントリの複製: 移動したエントリ/ウェブページに関係するトラックバック(ping)の移動に失敗しました。(ID [_1]) : [_2]',


);

1;
