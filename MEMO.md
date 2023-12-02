# v100以後の改版メモ

### '@', '!' fetchとdeposit

base.dict にエントリ2つを追加した。

### pop

base.dictのpopエントリに add.b #2,%a5を入れた。

### スタックアンダーフローチェック

narrowroad.sのdump_stackの最初でアンダーフローをチェックしてエラーメッセージを出した。

### putnum を直した(11/18)。

桁0だけ表示されないバグを直した。素直に下の桁からバッファに蓄え、最後にまとめて出力するようにした。divu.w命令を使った。上位16bitに余り、下位16bitに商が返される。

現在、signed short 16bitとして表示する(-32768 - 32767の範囲)。

linbuf末尾からASCII数字列を格納するようにしている。

### 数値出力: 10進固定小数点数

固定小数点数を使うときに実装しましょう。後送り。

### TYPEBルーチン

メモリ上のデータを空白が出るまで出力する。

### 現状のメモリマップ(11/20)

codes.sの先頭と、リンカスクリプト(`trip.ldscript`)による

機械語コード4kB, 辞書4kBを想定している。

0000-0FFF: リセットベクタ、割り込みベクタ、ほか
1000-1FFF: CODEセグメント、機械語コード
  code_top:
  ram_top:
2000-2FFF: DICTセグメント、base.dictをアセンブリコードに変換したdict.sが置かれる。
3000-FFFF: BUFFERセグメント
  linbuf:  3000-307F(128bytes)
  wordbuf: 3080-30FF(128bytes)
  putnumbuf: 3100-310F(16bytes)
    これはwordbufの末尾16バイトでも構わない。
FC00-FEFF: STACKセグメント
  data stack:   FC00-FCFF(%a5)
  return stack: FD00-FDFF(%a6)
  assembly stack: FE00-FEFF(%a7)

### 辞書エントリ追加(11/20)

@は奇数アドレスの時バスエラーを起こす。
C@, C!を追加した。バイトアクセス

### word定義、辞書検索がうまく働いていない(11/20)。

* 起動直後、cr, blは動作する。
* add呼び出し→add not found, 以後cr, blともにnot foundとなる。
  add,abc呼び出し後もだめ。inner interpreterが動作していない様子。デバッグ必要。
* abcが動作しない。nop not foundが出る。

調査の結果、

* 偶数長の比較がおかしい。文字列は先頭に長さ、２バイト名後に文字列データを置く。高速化のためword比較なので、偶数長の場合、末尾１バイトに何を詰めるかまでコントロールせねばならない。
* Moore師匠によれば、
  + 行入力からワードを切り出すWORDルーチンでは、文字列の次の空白文字までバッファに置くようにする。
  + 辞書エントリの文字列も、詰め文字は空白文字とする。

番兵、ですね。

今は計算機資源に余裕があるので、数10命令増えようが「文字列の意味を忠実に実装する」のですが、当時はこういう技をよく使いました。

### word定義・検索関連の修正(11/26)

ということで、以下の修正を施しました。

* 辞書エントリの文字列長さが偶数の時、文字列末尾に空白文字を追加した。偶数バイト長のとき、先頭の文字数１バイトも含めてワードアライメントで次のデータを置くと１バイト空きがでる。この１バイトが従来バイト0だったのを、空白文字を置くように辞書コンパイラを修正した。
  + do_same: 文字列比較時のワード数カウンタ初期化を修正した。というかもともと間違っていた。  
  + do_same: %d0へのバイトリードのあと、bit8-15のクリアをしていなかった。ここ68kアセンブリで要注意。`eor.w #0,%d0`を追加。

```
    +2    ÷2
  1 --> 3 --> 1
  2 --> 4 --> 2
  3 --> 5 --> 2
  4 --> 6 --> 3
  5 --> 7 --> 3
  ...
```

  + makedict.sh: awkスクリプトでアセンブリ命令列を出している。文字列は`.ascii`疑似命令で出しているが、偶数文字の文字列は末尾に' 'を追加した。
  + acceptルーチン: 行入力ルーチン。読み込み完了(`\r`検知)し、戻る前にバッファ末尾に無条件に空白文字を足した。乱暴だが。
  + dictdump.c: デバッグ用の辞書ダンプリスト生成用のプログラムも辞書エントリの文字列部分の長さ計算を修正した。

### その他の修正(11/26)

* 辞書エントリ: `base`を追加。数値出力の基数を格納する変数のアドレスをスタックに置く。`!`, `@`と組み合わせて使用する。まだ動作している感じがしない。デバッグ要。
* 辞書エントリ生成: 空の`dc.w`疑似命令が出ていた。理由は謎。とりあえず`dc.w`のオペランド文字列が空の時には生成しないようにした。乱暴。
* ブレークポイント機能: アセンブリ言語ソース中に `br[0-9][0-9]*`(b,r,数字)に一致するラベルがあれば、そのラベルすべてをブレークポイントとみなすようにした。
  + ソースコード中でブレークポイント入れたいところに`bp000:`と書く。`do_same`ルーチンにブレークポイント入れるときはこんな感じで。

```
do_same:
bp000:
    move.w  %d1,-(%a7)      /* push %d1 */
    move.w  %a1,-(%a7)
    move.w  %a0,-(%a7)
```

  + `extract_bp.sh`: 生成後のオブジェクトからシンボルリストを出し、そこに`br[0-9]`に一致するシンボルがあれば、そのアドレスを`PXXXX`の形式で出力する。この出力を `bp.X`ファイルとして保持し、ターゲットにアップロードする。
  + 68000エミュレータMusashi: 複数引数でアップロードファイルを指定できるように修正。
  + 実行時: `./sim narrowroad.X bp.X`と2ファイル指定して呼び出す。
* シングルステップ機能: Musashiに追加、ブレーク停止中はレジスタダンプしてキー入力待ちになる。スペースを叩くとワンステップ、`.`を入力すると実行再開。

### バグか？baseを変更後、2度目のbaseが読み込めない。

```
;
run...]16 base !
]base

se not found
00BA ].
BA]
```

`16 base !`で基数を16に切り替えたのち、`base`に値が正しく設定されているかどうかを確認しようと`base`と入力した。すると、`se not found`と出てスタックに`BA`が置かれた。なんで？

辞書引き、ワード切り出しの不具合を疑いトレースした結果、この挙動は「期待通り」(もしくは「書いた通り」)であることが分かった。すなわち、

* 基数を16としたことで、`A`, `B`は数値となる。
* なので`base`は数字から始まっていると見なし、`ba`を16進0xbaと見なしてスタックに`BA`を載せる。
* 次の文字`s`で数値でないと見なして数値変換(do_number)を抜けてワード検索に移動する。
* 残り2文字`se`を切り出して辞書検索に入り、`se not found`となった。

だった。だがこの挙動は許容できない。設計がおかしい。

baseは16進文字から始まっているが、ワードとして見ると16進数ではないだろう。現状は、数字文字なら数値に変換してゆくが、まず空白文字でワードを切り出してから変換すべきではないか。うーん、そういえばMoore師匠はnumber, wordをしっかり作れと言っていたなぁ。師匠の教えに立ち返ってみよう。

再度、Moore師匠の教えに立ち返ると、8.1 ワードの解剖(word dissection)にそれらしいことが書いてある。

> 以下の文字列全てがワードとなるような単純なルールはない。  
> * HELLO GOOD-BY 3.14 I.B.M. -.5 1.E03  
> 同様に、以下の文字列を意図するワードに分離する単純なルールもない。  
> * -ALPHA 1+ ALPHA+BETA +X**-3 X,Y,Z; X.OR.Y  
> 遅くなるが「スペースで終わるワードを読み、辞書を引き、数字に変換する。この定義でワードでない場合は、最後の文字を削除して再試行します。最終的には残った文字がワードとなるように、十分な文字を削除する。

要するに、
* 現状は、「数値変換、ワード切り出しと検索」、の順に処理しているが、
* これを「ワード切り出し、辞書検索、数値変換」の順に変える。
* 数値にもならないなら末尾1文字を削除して再度回す。

ということだ。ここでも、まずワードを切り出すと言っている。

とりあえず、「ワード切り出し、辞書検索、数値変換」に変更することにする。

### outer ループ組み換え(11/26)

組んでみた。当然だが動かない。
```
;
run...]1
0001 ]2
0001 0002 ]+

N not found
0003 ]pop
```
`N not found`が出るが、1 + 2 は実行できている。
```
0003 ]pop

 ]1Attempted to write 31 to RAM address 00fe3000
At 133a: move.b  D0, (A1,D1.l)
```
`pop`を入れるとプロンプトを返すが、1文字`1`を入力した時点でシミュレータが堕ちる。
```
kuma@LizNoir:~/narrowroad-m68k$ ;
run...]1 2 + .
0001 ]
```
1行に複数ワードがある場合そもそも続きを解釈しない。

### outerループデバッグ(11/27)

* `At 133a: move.b D0, (A1,D1.l)`の件、accept入り口でD1(バッファ長)の値がおかしい。FFFE0080になっていた。
* 呼び出し側で%d1への定数セットで`move.w`を使っていたので上16ビットが初期化されていなかった。`move.l`にして問題なくなった。
* move.wで上が初期化されていない、move.bでビット8-15が初期化されていないという失敗が多い。とりあえず気を付けるとして、それ以上の防止策はどうする？ 

* 上記を修正後、`pop`でプロンプトに帰ってこない。
* acceptからは帰ってきている。
* findの終わりにブレークポイント掛けると、何度も辞書検索している。
* 2度目のfindから、%a0(wordbuf)の指定が違っている。違うバッファからワードを見て検索していた。
* outer ループでコマンド実行後に行入力ループに戻る際に、レジスタのpopができていなかった。pop3個を追加すると動くようになった。

### バグかも？(11/28)

```
run...]16 base !
]base !
underflow]A base !

A not found
]base

 3400 ]@

 0000 ].
Attempted to write 0000 to RAM address 00fffffe
At 02d6: move.l  D4, -(A3)
kuma@PC-C2387:~/narrowroad-m68k$
```
もう1回、今度はいきなり`base !`でアンダーフローを起こしてみる。
```
;
run...]base !
underflow]base
3400 ]@
0000 ].
]
```
変数`base`が0になっているらしい。

数値を表示`.`する際には`base`で割るため、ゼロ除算が生じているはず。現状、このエクセプションはキャッチしていないため、何が起こるかわからない状態。

* そもそも`!`でアンダーフローを起こした場合書き込みされているのが問題か？
* `!`の実行時に毎回スタックアンダーフローチェックするのはよろしくない。実行効率低下が心配だ。アウターループに戻ってくる際にチェックする、でいいはず。
* `base`を参照するときにゼロかどうかをチェックするか。これも微妙だが。

* いずれにしても、ゼロ除算のエクセプションは、バスエラーエクセプションとともに組み込んでおくべきですね。これらのエクセプションが生じると、スタックをクリアしてouter loop 先頭に戻る。
### Exception対応追加(11/28)

* Illegal Instruction/Bus Error/Div by Zero に対してException ベクタ追加。
* Exceptionベクタ`do_exception`では、メッセージを表示して初期化ルーチンに飛ぶ。
* 初期化は、%a7(SP), %a5(DSP), %a4(RSP)に対して行う。
* メモリ上変数は初期化されない、以前の状態のまま。

#### ベクタテーブル

* bus error とその他例外を設けた。

```
    .section VECTOR_TABLE
    dc.l    sp_end          /* 0: Initial SP */
    dc.l    start           /* 1: Initial PC */
    dc.l    do_exception    /* 2: Access fault */
    dc.l    do_buserror     /* 3: Address Error */
    dc.l    do_exception    /* 4: Illegal Instruction */
    dc.l    do_divbyzero    /* 5: Divide by Zero */
```

#### 例外処理ルーチン

* アドレスをダンプした後メッセージを出す。
* アドレスは%sp +2 のダブルワード

```
    .section CODE
buserror_str:
    dc.b    9
    .ascii  "bus error "
exception_str:
    dc.b     9
    .ascii  "exception "
divbyzero_str:
    dc.b    14
    .ascii  "divide by zero "
do_divbyzero:
    move.l  #divbyzero_str,%a0
    bra     do_exception_message
do_buserror:
    move.l  #buserror_str,%a0
    bra     do_exception_message
do_exception:
    /* exception ... rewind SP, IP, DSP, RSP */
    move.l  #exception_str,%a0
do_exception_message:
    jsr     (putstr)
    jsr     (bl)
    add.l   #2,%a7
    move.l  (%a7),%a0         /* access address */
    move.l  %a0,%d0
    jsr     (puthex8) 
    jsr     (crlf)
    /* falling down to start */
start:
    ... (この先で%a7,%a5,%a4が初期化される)
```

### IF/ELSE/THENとループ導入: Part1 仮想命令(ブランチ)の追加(11/30)

ワードコンパイル導入に先立ち、必要なワードを追加してゆく。ワードリストの要素は、通常実行ルーチンのアドレス(ジャンプ先)だが、「そのワードを取り出してそこへジャンプする」以外の処理が必要になる。ここではその「命令」3つを挙げる。

* `lit`: リテラル、次のワードの値をスタックに積む。数値をコンパイルするとき生成されるコードに埋め込む。

```
do_lit:
    move.w  (%a6)+,%d0          /* next word to %d0, immediate
                                   operand of 'do_lit' */
    move.w   %d0,-(%a5)         /* push it to Data Stack */
    bra.b   do_next
```

* `bra`, `bne`: 無条件ブランチと条件付きブランチ。
* `bne`はスタックの値がfalseの時にジャンプする。`IF/ELSE/THEN`で、true節とfalse節の飛び越えに用いる。ワードIFのコンパイルの際に、`bne`をtrue節の前に置き、あとでELSE/THENに出会ったときにその位置へのジャンプ(IPにそのアドレスをセット)する。
* `bra`はtrue節の最後に置き、あとでfalse節の最後のアドレスが確定した時点でここにジャンプ先を置く。
* ループを組むときにも用いる。

```
    .global do_bne
do_bne:
    move.w  (%a5)+,%d0
    and.w   %d0,%d0
    bne.w   do_bra
    add.w   #2,%a6
    bra.w   do_next

    .global do_bra
do_bra:
    add.w   (%a6)+,%a6
    bra.w   do_next
```

辞書エントリの定義の中で、`lit`, `bra`, `bne`と書くことができる。例えば、スタックトップがゼロの時 `false`を、非ゼロの時 `true`を印字するワードの定義は、以下のように書くことができる。litの次には定数を置く。数値か、アドレス(`#false_str`など)を書く。

`bne`, `bra`の後ろには相対オフセットを書く。オフセットの次のアドレスを起点として符合付き2バイト整数として計算する。

例えば、`bne 12`は、次の命令/オフセット6個を飛ばし7個目に条件ブランチする。

```
word branch
    bne
    12
    lit
    #false_str
    types
    cr
    bra
    8
    lit
    #true_str
    types
    cr
    endword
```

* 条件ワード: 比較演算子の類、スタックの上2ワードに適用する2項演算子。true(1)/false(0)をスタックに置く。`0=`, `0<`, `<`, `>`, 

プログラマが打ち込むプログラムでは使わない。辞書エントリとしては存在しないが、終了時 next/exitにジャンプする。


### 解説: 辞書エントリ

辞書エントリは、
* ヘッダ(名前文字列とprecedenceフラグ)
* 一つ手前のエントリへのリンク
* コード部(CFA)
* パラメータ部(PFA)

から成る。

エントリの本質は、
* 名前、
* ワードのリストか機械語ルーチンの区別
* 機械語ルーチン
* リスト本体(ワードのリストの場合)

であり、これを指定する記述を以下のように決めた。

ワードのリストの場合
```
word <name> <opt-name> <precedence-flags>
   ...
   ...(list of words, routines)
   ...
   endword
```

機械語ルーチンの場合
```
code <name> <opt-name> <precedence-flags>
    ...
    ...(machine codes)
    ...
    endcode
```

#### *\<name>*:
ワードの名前、アルファベット・数字だけでなく、空白文字以外の任意の印字可能文字を使用できる。ただしASCII文字に限る(0x21-0x7f)。  

エントリ先頭の文字列として置かれる。Forth言語でワードを打ち込んだ時マッチング対象となる文字列である。  

文字列長さの上限は31文字まで。文字列を長さ⁺ASCII文字列で表現しているが、長さ1バイト中3ビットをエントリ属性(優先度フラグなど)として使うことを想定して、5ビットで表現できる範囲の長さとした。

#### *\<opt-name>*:
オプションの名前。アセンブリ言語のラベルとして使用される。

`<name>`がラベルとして使用できない文字を含む場合、このオプション名でラベル名を指定する。

#### *\<precedence-flag>*:

優先度フラグ情報。`immediate`または`level2`

(Moore74の13章より)
> FORTHコンパイラはそれ自体がFORTHで書かれているので、コンパイル中の言葉とコンパイラへの命令としての言葉を区別する方法がなければなりません。優先順位フィールドはこれを行う。これは、ある語がコンパイル中に実行されるかどうかを指定するものである。表1は、エントリの優先順位と変数STATEの値によって、ワードがいつコンパイルされ、いつ実行されるかがどのように決まるかを説明しています。
>
> ほとんどの単語は優先順位が0であり、普通にコンパイルされる。しかし、一部の単語、特にIF, ELSE, THEN, DO, LOOP, ';'はコンパイルが困難なため、コンパイル中に実行しなければならないという問題が生じる。これらの語はコンパイラ指令であり、定義の外側では使ってはいけません。ほとんどの指令は優先順位が1です。
>
> しかし、FORTHの性質上、さらに複雑なことが起こります。コンパイラ指令を定義できるようにするためには、コンパイラ指令さえもコンパイルされる状態を定義しておく必要があるのです。これは、IMMEDIATEという指令で、現在のエントリの優先順位を1にし、変数STATEも2にします。これで優先順位1の指令もコンパイルされるようになりますが(表1参照)、それでもコンパイルを止めるために実行しなければならない単語があります。というわけで、';'は優先順位2になっています。

`immediate`は、このワードを優先度1にする。具体的には先頭の文字列長さバイトのbit5(6ビット目)を立てる。`level2`は、優先度を2にする。bit6,5を1,0とする。Moore74によると、ワード定義の終端`;`(セミコロン)がそれに該当する。

> 未実装、実装次第コードを入れる

### ワード先頭バイトのビット7は立てておく

ワードリストは、各ワードの途中のアドレスを指している。具体的には、先頭の文字列、リンクの次のアドレスである(CFA Code Field Address)。

デバッグの都合上、ワードリストの各要素のワード名を印字したいことがある。ワード名文字列の先頭を探すために、バイトMSBを立てることで識別する。

* 名前はASCII文字列であること。
* 長さは5ビット、31文字までであること。
* 優先度に2ビット使うこと。

により、リンク領域(これは2バイトの固定長)を飛ばして逆方向にワードサーチを掛ける際に、ワードMSB(68000なのでビックエンディアンなのです)が1を見つけるだけでよいことが分かる。

### 生成されるアセンブリ言語のコード(ワードエントリ)

「辞書記述言語(?!)」で記述されたファイルをシェルスクリプト`makedict.sh`でアセンブリ言語の記述に変換する。採取的なバイナリは、初期化・サービスルーチンを記述する`codes.s`と、辞書コードをアセンブリして完成させる。

例えば、以下のようなワード定義`ttest`は、

```
word ttest
    lit
    #true_str
    types
    endword
```

以下のようなアセンブリ言語に変換される。

```
entry_024:
e_ttest:
    dc.b    5
    .ascii  "ttest"
    .align  2
    dc.w    entry_023
do_ttest:
    jmp     do_list
    dc.w    do_lit
/* str = #true_str */
    dc.w    true_str
    dc.w    do_types
    dc.w    do_exit
```

ラベル`e_ttest`から`do_ttest`までの間がヘッダ部分、名前文字列と前のエントリへのリンクである。

* ヘッダ先頭バイトは名前文字列の長さである。
* 2バイト目から名前文字列がASCIIコードで置かれる。ワード(2バイト)アライメントとする。
* その次が、「前のエントリへのリンク」である。各エントリ先頭には、`e_<name>`形式のラベルだけでなく、`entry_nnn`形式のラベルも定義され、次のエントリのリンクフィールドに前のエントリのラベルを置けるようにしてある。

ラベル`do_ttest`から後ろがコードフィールドとパラメータフィールドである。

* ワードエントリの場合、コードフィールドは、ルーチン`do_list`へのジャンプ命令である。  
  この機械語ルーチンでは、IPの値をリターンスタックに保存したあと、ジャンプ命令の次からのワードCFAアドレスのリストの先頭をIP(レジスタ`%a6`)に設定し、内部インタプリタ`do_next`にジャンプする。
* 参考までに`do_list`のリストを以下に示す。

```
/*
 * inner interpreter
 */
    .global do_list
do_list:                        /* %a0 points to the code of the word, 
                                 * where it has address of 'do_list' */
    move.w  %a6,-(%a4)          /* push IP */
    move.w  %a0,%a6             /* address points to the code area of new word
                                 * IP now points to the address of the first pointer */
    add.w   #6,%a6              /* IP points the first token address
                                 * the size of `jmp do_list` is 4 bytes
                                 */
    jmp     do_next
```

* 以後はワードのCFAアドレスが並ぶ。各エントリのCFAアドレスは、ラベル`do_<name>`で定義されているので、このラベルの値を並べることでリストができている。
* 最後にルーチン`do_exit`のアドレスが置かれる。  
  `do_exit`は、`do_list`と対をなすルーチンで、`do_list`で保存したIPを取り戻し、  
  IPがさすアドレスに間接ジャンプする。飛び先は「このワードの呼び出し元のワードリスト上で次のエントリのCFA」である。ややこしい。

```
    .global do_exit
do_exit:
    move.w  (%a4)+,%a6          /* pop IP from RSP */
    move.w  (%a6),%a0
    add.w   #2,%a6
    jmp     (%a0)
```

### 生成されるアセンブリ言語のコード(ワードエントリ)

* 機械語(コード)エントリの場合は、直接アセンブリ言語が記述される。

* 例えば、スタックの上2ワードを加算しスタック上に戻すワード`+`の定義は以下のように書く。  
  `code` ... `endcode`の間には68000のアセンブリ言語コードをそのまま書く。

```
code + plus
    move.w  (%a5)+,%d0
    add.w   (%a5)+,%d0
    move.w  %d0,-(%a5)
    endcode
```

* 生成されるアセンブリ言語は以下のようになる。

```
entry_009:
e_plus:
    dc.b    1
    .ascii  "+"
    .align  2
    dc.w    entry_008
do_plus:
    move.w  (%a5)+,%d0
    add.w   (%a5)+,%d0
    move.w  %d0,-(%a5)
    jmp     do_next
```

* 名前`+`はラベルとして使えないので、オプションの名前`plus`を指定しており、これがラベル`e_plus`, `do_plus`に使用される。その後ろにエントリ内部で指定したアセンブリ言語コード3行が並び、最後は`jmp do_next`である。
* 機械語ルーチンの中ではIPは触らない。このエントリを呼び出した元のワードリストの次の要素を指している。この場合、単純に「IPの指すエントリを実行しIPを2足す」だけ行うので、まさに`do_next`そのものである。

### precedenceビットの実装

* 辞書エントリ先頭1バイトの上位3ビットと下位5ビットに分ける。
* 文字列長さは下位5ビットのみ、上位3ビットはマスクして落とす。
* 最上位ビットは常に立てる。CFAアドレスからエントリ先頭の文字列を見つけるためのサーチで使用する。文字列を形成するバイトのMSBは立ててはいけない。日本語文字ダメよ。

実装

* `do_same`で、文字列先頭の上位3ビットをクリアして比較するようにした。
* `do_find`で、エントリ先頭アドレスからリンクポインタを手繰る時の文字列長に0x1fマスクを掛けるようにした。

### 現在の状態`STATE`とワードのprecedenceとの関係

|situation|STATE|0|1|2|
|--|--|--|--|--|
|実行中|0|execute|execute|execute|
|コンパイル中|1|compile|execute|execute|
|IMMEDIATEの直後|2|compile|compile|execute|
||||||

この実装は、コンパイル実装時に実装される。

### リターンスタックは Moore74に記述がある。

リターンスタックは Moore74に記述がある。よって、我々の narrowroad Forth インタプリタも2スタックで行く。

### 辞書関連、スタック操作(11/30)

`HERE` ... 辞書の末尾、次にエントリを置くアドレスを返す。`here`という名前の変数としての扱い。

```
code here
    move.w  (here_addr),-(%a5)
    endcode
```

`LAST` ... 最終エントリ変数のアドレスを返す。`last @`で最終エントリのアドレスを得る。

```
code last
    move.w  #last_addr,-(%a5)
    endcode
```

`WHERE` ... 最終エントリの名前を印字する。`last`で得たアドレスの指す場所に最終エントリのアドレスがある。エントリの先頭は名前文字列なので、それを`types`で印字する。

辞書エントリ先頭も上位3ビットクリアする必要があるが、2項演算子がまだ実装されていないので無理。

```
word where
    last
    atfetch
    types
    endword
```

### 論理演算子を実装する。

`AND`, `OR`, `XOR`である。popは一つだけで、あとはスタックトップを入れ替えるだけである。

```
code and
    move.w  (%a5)+,%d0
    and.w   %d0,(%a5)
    endcode
code or
    move.w  (%a5)+,%d0
    or.w   %d0,(%a5)
    endcode
code xor
    move.w  (%a5)+,%d0
    eor.w   %d0,(%a5)
    endcode
```

`NOT`は、非0のとき0, 0のとき1にする。

```
code not
    move.w  (%a5),%d0
    and.w   %d0,%d0
    beq     xcode_1
    move.w   #-1,%d0
xcode_1:
    add.w   #1,%d0
    move.w  %d0,(%a5)
    endcode
```

> ちなみに、このコードワード定義で`makedict.sh`は、「`code`から始まる行はエントリ開始とみなす」ので、最初ラベルに`code_1:`を使っていてハマった。とりあえず`code`から始まるラベルは使わないことで回避した。あと、`code`エントリでラベルを想定していなかったので、ラベルの場合(末尾が`:`の行)は先頭の4スペースは入れないようにした。

#### `TYPE0`: (addr n -- ) 文字列アドレスと文字数から印字する。

`%d1`にバイトカウンタとして使う。演算全て`.b`で行うと上位ビットに関わりなく計算できる。あたりまえだが。

```
code type0
    move.w  (%a5)+,%d1
    move.w  (%a5)+,%a0
    cmp.b   #0,%d1
type0_1:
    beq     type0_2
    move.b  (%a0)+,%d0
    jsr     (putch)
    add.b   #-1,%d1
    bra.b   type0_1
type0_2:
    endcode
```

#### `where`: 辞書エントリ先頭のMSB立てたバージョン

`type0`を使う前提で、辞書エントリ先頭のバイトカウントの上位3ビットをクリアしてカウンタとして使う。

```
word where
    last        // 最終辞書エントリの先頭アドレス
    atfetch     // を取り出しスタックに乗せる
    dup
    lit
    1
    add         // アドレスを1足して文字列先頭を指す
                // ようにする。
    swap        // それをプッシュして
    bytefetch   // 文字数カウンタを取り出し
    lit
    31          
    and         // 0x1fでANDする(上3ビットをクリアする)
    type0       // これでスタックトップが(addr n)になった
                // のでtype0を呼び出す
    endword
```

### 辞書エントリ生成をワードリストで書いてみよう

"Starting Forth"にこのあたりのワードの説明があった。

#### `CREATE`: 辞書エントリの作成

* 入力からワード1つを読み込み、そのワードを名前として持つエントリを作る。
* エントリは辞書の末尾(`HERE`, 実際は変数`H`の値)に置く。名前文字列の後ろにリンク(`LAST`の値を取り出しリンクに入れる)
* 辞書領域にデータを置く際には、`H @`(or `HERE`)で置き先のアドレスを得て、`ALLOT`で`H`を進めるという記法を用いる。

という仕事を行うワードが`CREATE`である。スタック上にPFA(CFAの次のアドレス)を置く。

narrowroad Forthインタプリタの場合、CFAが不定長なので、リストの場合のジャンプ命令を仮置きしておく(3ワード)。

辞書領域にデータを置く際には、`H @`(or `HERE`)で置き先のアドレスを得て、`ALLOT`で`H`を進めるという記法を用いる。

#### `PAD`: 文字列保持用のワークエリア

"Starting Forth"では、HEREの34バイト先となっている。辞書エントリが増えるにつれ`PAD`も先に進む。Moore74にはそういう話がない。行入力バッファの末尾を使えばよいとされている。

#### `S0`: スタックの底

Starting Forthでは、

* スタックポインタ初期値+2。スタックアンダーフローすると爆撃される。
* 入力メッセージバッファとして使う。

現実装は、

* 固定領域、辞書の後ろに十分スペースを置いて、128バイト長さのバッファを確保している。

#### `'S`: tick-S, スタックポインタの値(データスタックポインタ)

#### `>IN`: 入力ストリームの現在位置へのポインタ

linebufの現在読み込み位置がワードで見られる

#### `'`(tick): 入力ストリームの次のワードを辞書で検索する

* `do_find`を呼び出せばよい。定義中に記載しても入力ストリームから読み込もうとする。
* 見つからなければ `ABORT"` を実行する。

#### `[']`: コロン定義中で次のワードのアドレスをリテラルとしてコンパイルする

#### `WORD`: 入力ストリームから単語の切り出し

```
(char  -- addr)
```

入力ストリームから char で区切られる文字列を切り出し、addr にカウント付き文字列としておく。辞書定義で使うことが多いので、`HERE`上に置くことになる。

#### `SPACE`, `BL`

* `SPACE`: 空白文字を印字する。
* `BL` : 空白文字(10進数で32)をスタックに置く。

BLの定義が違うので変更すべき。

```
code space
    move.b  #' ',%d0
    jsr     (putch)
    endcode
code bl
    move.w  #' ',-(%a5)
    endcode
```

#### `INTERPRET`: outer interpreterをワード列で定義しなおす

* `FIND`: 入力ストリームからワードを切り出し、辞書を検索する。見つかれば辞書エントリのアドレスを返す。なければゼロを置く。  
  `(  -- a | 0)`
* `_find`: (小文字findの代わりに先頭にアンダースコアを付ける) ...
  `(a va --- ca na or a 0)`　`va`にある辞書を文字列`a`で検索する。
* `WORD`: 入力ストリームからワードを切り出し、`PAD`に置く。

```
word interpret
_interpret1:
    find
    bne
    #_interpret3:
    /* put a number on the stack */
    number
    /* if success, go to top of the loop */
    beq
    #_interpret1
    abort
    /* else, abort it */
    lit
    #abort_message
_interpret3:
    /* find it, now execute it */
    /* get cfa */
    dup 
    c@
    add
    lit
    2
    add
    /* now get cfa, ok jump it */
    execute
    bra
    #_interpreter1
    endword
```

> 12/1現在、未実装。

### 12/1のコミット実装

codes.s: 辞書エントリ先頭バイトのMSB ON対応。
  あちこちで and.b 0x1fしまくる。
  あと、dump_entryの後ろの断片コードを整理(削除)

base.dict:
* where書き直し, 辞書エントリ先頭のMSB ON対応。かなり膨らんだ。
* 論理演算子、and, or, xor, not追加
* type0追加。(addr n --), 文字列先頭とカウンタを載せて呼び出す形式。
* codeエントリでラベルを使えるようにした。
  但し`code`で始まるラベルは依然として使用できない

dictdump.c:
* 辞書エントリ先頭のMSB ON対応。これ抜きでは辞書エントリをディスアセンブルできなかった。

makedict.sh:
* 辞書エントリ先頭のMSB ON対応。
* //コメント対応(コメント部分を削除する)
* codeエントリでラベルを使えるようにした

### 12/2の差分

base.dict:
* テストエントリ削除、動作は安定し十分エントリ例が増えた。
  辞書を整理してすっきりさせておきたい。

### 四則演算子(12/2)

* `+`, `-`, `*`は問題ない。
* `/`は少し難しい。
  * 被除数`%d1`は32ビットなので、符号付き16ビットの値を32ビットに符号拡張しないといけない。
  * BFEXTS命令は68020以上でしか使えない。68000ではtest/braを使う。
  * and命令で符号ビットNに反映される。bpl/bne条件付きブランチを使う。

```
code / div
    move.w  (%a5)+,%d0
    move.w  (%a5),%d1
    and.w   %d1,%d1
    bpl     div_1
    or.l    #0xffff0000,%d1
div_1:
    divs.w  %d0,%d1
    move.w  %d1,(%a5)
    endcode
```

### 辞書エントリアセンブラを書こう(12/2)

疑似命令 `lit`, `bra`, `bne`のオペランドを同じ行に掛けるようにした。
また、`bra`, `bne` のオペランドとしてラベルを使えるようにした。 

今までは、`bra`, `bne`のオペランドを行数を数えて手計算する必要があったが、これでアセンブリ言語風にラベル定義とオペランドにラベルを書くことでオペランドを計算してくれる。

これで辞書エントリがアセンブリ言語風に掛けるようになった。

```
word branch
    bne  bra_1
    lit  #false_str
    bra  bra_2
bra_1:
    lit  #true_str
bra_2:
    types
    cr
    endword
```

* makedict.sh により、辞書アセンブリファイル`base.dict`からアセンブリ言語ファイル`dict.s`が生成される。
* `dict.s`をアセンブルし`dict.o`を生成する。これと、`codes.s`をアセンブルして得られるオブジェクトファイル`codes.o`をリンクし、`a.out`が生成される。
* `a.out`内のオブジェクトコードを16進ダンプし、アップロード用形式`narrowroad.X`, ブレークポイントは`bp.X`ファイルに変換する。
* `narrowroad.X`, `bp.X`をアップロード後runすればよい。

### 辞書エントリのデバッグ手順

### 辞書エントリ生成をワードリストで書いてみよう

"Starting Forth"にこのあたりのワードの説明があった。

#### `CREATE`: 辞書エントリの作成

* 入力からワード1つを読み込み、そのワードを名前として持つエントリを作る。
* エントリは辞書の末尾(`HERE`, 実際は変数`H`の値)に置く。名前文字列の後ろにリンク(`LAST`の値を取り出しリンクに入れる)
* 辞書領域にデータを置く際には、`H @`(or `HERE`)で置き先のアドレスを得て、`ALLOT`で`H`を進めるという記法を用いる。

という仕事を行うワードが`CREATE`である。スタック上にPFA(CFAの次のアドレス)を置く。

narrowroad Forthインタプリタの場合、CFAが不定長なので、リストの場合のジャンプ命令を仮置きしておく(3ワード)。

辞書領域にデータを置く際には、`H @`(or `HERE`)で置き先のアドレスを得て、`ALLOT`で`H`を進めるという記法を用いる。

#### `PAD`: 文字列保持用のワークエリア

"Starting Forth"では、HEREの34バイト先となっている。辞書エントリが増えるにつれ`PAD`も先に進む。Moore74にはそういう話がない。行入力バッファの末尾を使えばよいとされている。

### `H`, `HERE`, `ALLOT`, `PAD`の定義

`H @` が `HERE`に相当するということで。

`H`: ( -- addr) 辞書末尾ポインタを格納する領域のアドレス。
`HERE`: ( -- addr) 辞書末尾のアドレス
`ALLOT`: (n -- ): 辞書末尾を進める。

本実装では、辞書末尾は辞書先頭、ラベル`here_addr`に置いてある。

* `h`は`here_addr`をスタックに置く
* `here`は、`here_addr`番地の16ビット値をスタックに置く。
* `allot`は`here_addr`番地の値にスタックトップの値を加算して格納する。

```
word h 
    lit #here_addr
    endword

word here
    lit #here_addr
    atfetch
    endword

//   (n allot --)
word allot
    lit #here_addr
    dup
    atfetch
    rot
    add         // here n plut
    swap        // (addr value -- )
    exclamation // store it
    endword
```

### 辞書エントリの作成: Part1 `CREATE`

* 入力からワード1つを読み込み、そのワードを名前として持つエントリを作る。
* エントリは辞書の末尾(`HERE`, 実際は変数`H`の値)に置く。名前文字列の後ろにリンク(`LAST`の値を取り出しリンクに入れる)
* 辞書領域にデータを置く際には、`H @`(or `HERE`)で置き先のアドレスを得て、`ALLOT`で`H`を進めるという記法を用いる。

まず、WORDを作る。

#### WORD (c -- adr)

> 文字(通常は空白)を区切り文字として、入力ストリームから 1 つのワードを読み取る。文字列を 1 バイト目にカウントを入れたアドレス(HERE)に移動し、そのアドレスをスタックに残します

wordは辞書末尾に文字列をコピーしてくれるが、これはそのまま新しいエントリのヘッダとして使える。辞書にcodeエントリとして作成した。

```
//
// word ... read a word from input stream and
//          put it to the end-of-dictionary
//      (c -- addr)
//
code word
    move.w  (%a5)+,%d1      // delimit .. %d1
    move.w  (here_addr),%d0
    and.l   #0xffff,%d0
    move.l  %d0,%a1         // %a1, here + 1(string start point)
    move.l  %a1,-(%a7)      // push %a1
    add.l   #1,%a1          // start point is here + 1
    move.w  #31,%d2         // %d2, destination max size
    and.b   %d2,%d2
word_1:
    beq     word_2
    jsr     (getchar)       // buffered/block input
    move.b  %d0,(%a1)+
    cmp.b   %d1,%d0
    beq     word_2
    add.w   #-1,%d2
    bra     word_1
word_2:
    cmp.b   -(%a1),%d1      // last char is delimiter?
    beq     word_3
    add.l   #1,%a1          // restore %a1
word_3:
    move.l  (%a7)+,%a0      // restore top-of-entry addr
    move.l  %a1,%d0
    sub.l   %a0,%d0         // end-addr - start-addr -> %d0
    add.b   #-1,%D0         // dec 1 omiiting top one byte
    move.b  %d0,(%a0)       // put n to top-of-the entry
    move.w  %a0,-(%a5)
    endcode
```

辞書末尾をバッファとして使うというアイディアは思いつかなかった。独立な場所を確保するのが今風なのだが、デフォルトで語の定義にそのまま利用できる場所で、かつ他に移動させるにも問題ない場所、また通常の実行には問題にならない場所という、これ以上はないという好適な場所といえるだろう。

#### `CREATE`

* エントリは辞書の末尾(`HERE`, 実際は変数`H`の値)に置く。名前文字列の後ろにリンク(`LAST`の値を取り出しリンクに入れる)
* 辞書領域にデータを置く際には、`H @`(or `HERE`)で置き先のアドレスを得て、`ALLOT`で`H`を進めるという記法を用いる。

* `WORD`を呼び出し辞書末尾に名前文字列を置く
* リンク置き場所を算出して、`LAST`の値を入れる。
* `ALLOT`で`H`を進める。
* 先頭バイトのMSBを立てる。

|length(n)|n / 2|n / 2 + 1|link offset|
|:--:|:--:|:--:|:--:|
|1|0|1|2|
|2|1|2|4|
|3|1|2|4|
|4|2|3|6|
|5|3|3|6|

```
link_offset = (n / 2 + 1) * 2
```

だいたい動いたところで時間切れ。lastが変数アドレスを載せるだけというのに気づいて直したところで動作未確認。

あと、`Musashi`が印字途中でハングする件のデバッグが必要。

#### 12/2修正の概要

base.dict:

* 2項演算子追加: `+`, `-`, `*`, `/`, `lsr`(1ビット右シフト)
  + divは被除数を32bit化(符号拡張)しておく必要がある。さもなくば、除数または被除数が負数の場合おかしなことが起きる。
* `type0` (addr n --)の追加
* C@ -> c@, C! -> c!
* `here`を辞書定義に変えた(codes.s 側はコメントアウト)
* `allot`, `emit`
* `word` (c -- addr)の追加。辞書末尾に文字列を置き、そのアドレスを返す
* `create`作成中

* word定義で、`lit`, `bra`, `bne`にオペランド形式で書けるようにした。
* word定義で、ラベルを使えるようにした。`bra`, `bne`のオペランドもアセンブル時に自動計算されるようになった。

codes.s:

getchar: ストリームバッファ上に構成する1文字読み込み。バッファが隠ぺいされている。将来の入力リダイレクトの布石でもある。`word`実装の際に使用している。

do_word -> do_word_asm: アセンブリ言語版の`do_word`の名前バッティングを回避。将来的に outer interpreterがword定義化された際には使用されなくなる。

bl, spaceの定義を好感した。blはスタックに空白文字を置く。spaceは空白文字を印字する。

dump_stack, dump_entry: ワード実行中のトレース表示。シングルステップにまではできていない。

makedict.sh: lit, bra, bneのオペランド記述、ラベル算出対応。

### 付録. Moore_74に挙げられた基本ワード

これから以下のワードを実装することになる。進捗確認も込めて。

'l', 'm', and 'n' indicate numbers on the stack; 'a' indicates an address on the stack

Words concerned with the dictionary:

|||
|--|--|
|HERE|Address of next available word. 
|LAST                             @|Address of last entry. 
|WHERE|Type name of last entry. 
|n ,|Compile number into dictionary. 
|VOCABULARY word|Define the name of a vocabulary.
|FORGET word|Forget all entries following 'word". 
|n DP + !|Leave n locations for an array.
|||

Words concerned with the stack:

|||
|--|--|
|l m n DUP|Leave l m n n on the stack 
|" OVER|Leave l m n m on the stack 
|" DROP|Leave l m on the stack 
|" SWAP |Leave l n m on the stack 
|" ROT|Leave m n 1 on the stack
|n .|Type (and discard) number. 
|a ?|Type number at address a.
|a COUNT|Fetch the count field of a string.
|a n TYPE|Type n characters, starting at address a.
|||

Words concerned with arithmetic:

|||
|--|--|
|n CONSTANT word|Define 'word' so that its value (n) is placed onto the stack.
|n INTEGER word|Define 'word' so that the address of its parameter field is placed onto the stack.
|n a SET word|Define 'word' to store the number into the address.
|a @|Fetch the number from address a.
|n a !|Store the number into address a.
|n a +!|Add the number into address a.
|DECIMAL|Specify number base.
|OCTAL|Specify number base.
|HEX|Specify number base.
|n MINUS|Leaven -n on the stack
|n ABS|Leave |n| on the stack 
|m n +|Leave m+n on the stack
|m n \*|Leave m\*n on the stack 
|m n MAX|Leave max (m, n) on the stack
|m n MIN|Leave min (m, n) on the stack 
|m n -|Leave m-n on the stack 
|m n /|Leave m/n on the stack 
|m n MOD|Leave m mod n on the stack 
|l m n \*/|Leave l \* m / n on the stack 
|n 0=|Leave if n=0 then 1; otherwise 0. 
|n 0<|Leave n < 0 then 1; otherwise 0. 
|m n \<|Leave m\< n then 1; otherwise 0. 
|m n >|Leave m > n then 1; otherwise 0.
|||

Words concerned with the interpreter:

|||
|--|--|
|WORD|Read the next word in the input string.
|QUESTION|Type an error message-the last word read followed by? 
|n LOAD|Read text from block n.
|;S|End of text.
|IMMEDIATE |Set the precedence of the last entry to 1.
|: word|Define 'word' and begin compiling its definition.
|I|Put the current value of the loop index on the stack.
||(the following have precedence 1)
|n IF|Skip to ELSE (or THEN) if number is 0 (false).
|ELSE|Skip to THEN.
|THEN|Mark end of skip.
|m n DO |Begin loop; limit (m) and index (n) are placed on the return stack at execute time.
|LOOP|End loop; increment index by 1 and stop at limit.
|n +LOOP|End loop; increment index by n and stop at limit.
||(the following have precedence 2)
|;|End compilation.
|;CODE|End compilation and begin assembling code.
| EOT|End of input message from terminal. Await input and continue compilation.
|||

