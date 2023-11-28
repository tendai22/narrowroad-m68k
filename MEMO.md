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

### IF/ELSE/THENとループ導入: 仮想命令(ブランチ)の追加

ワードコンパイル導入に先立ち、必要なワードを追加してゆく。ワードリストの要素は、通常実行ルーチンのアドレス(ジャンプ先)だが、「そのワードを取り出してそこへジャンプする」以外の処理が必要になる。ここではその「命令」3つを挙げる。

* `lit`: リテラル、次のワードの値をスタックに積む。数値をコンパイルするとき生成されるコードに埋め込む。
* `bra`, `bne`: 無条件ブランチと条件付きブランチ。
* `bne`はスタックの値がfalseの時にジャンプする。`IF/ELSE/THEN`で、true節とfalse節の飛び越えに用いる。ワードIFのコンパイルの際に、`bne`をtrue節の前に置き、あとでELSE/THENに出会ったときにその位置へのジャンプ(IPにそのアドレスをセット)する。
* `bra`はtrue節の最後に置き、あとでfalse節の最後のアドレスが確定した時点でここにジャンプ先を置く。
* ループを組むときにも用いる。
* 条件ワード: 比較演算子の類、スタックの上2ワードに適用する2項演算子。true(1)/false(0)をスタックに置く。`0=`, `0<`, `<`, `>`, 

プログラマが打ち込むプログラムでは使わない。辞書エントリとしては存在しないが、終了時 next/exitにジャンプする。

### リターンスタックは Moore74に記述がある。

リターンスタックは Moore74に記述がある。よって、我々の narrowroad Forth インタプリタも2スタックで行く。

### Moore_74に挙げられた基本ワード

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

