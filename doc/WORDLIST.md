# 付録. ワード実装状況{id=App-1}

> C103 「野望編」付録形式に変更した。以後、この形式で更新してゆく

POLだけでなく、Moore74, Starting-Forth, Programming Forth(Stephjen Pelc, 2011)も参考にして独断と趣味で選んだ。

**(済)**:が打たれているものが現在実装済のものである。

type, categoryフィールドの意味は以下の通り

#### type:

|||
|--|--|
native|辞書に書かない。`codes.s`内の機械語ルーチン
code|辞書に書く機械語ワード、nextで内部インタプリタにジャンプする。
word|辞書に書くワードリストのワード、IPが順次各ワードのCFA(通常listルーチン)にジャンプしてゆく。最後はexitでIPを戻して呼び出し元に戻る。
|||

#### category:

|||
|--|--|
|inner|内部インタプリタ
outer|外部インタプリタ
i/o|入出力ルーチン、今回はシリアルI/Oと行バッファリングのみ。
user|ユーザ変数。ユーザ定義でなく、システムが提供する変数。なぜユーザ変数というかはよく分からない。
arith|算術オペレータ
dict|コンパイル用ワード
stream|ストリーム入力(`getchar`のみ)
define|定義ワード、`:`, `VARIABLE`, `CONSTANT`など、辞書エントリを定義する際に先頭に現れるワード
print|印字関連
input|入力関連
string|文字列処理
|||

#### その他記法説明

|||
|--|--|
|**xt**|execution token。呼び出すアドレス。辞書エントリのCFAである。
|**(優先度1)**|コンパイル中でも実行されるワード
|||

## narrowroad-forth ワード表

name|cat/type|description|
|--|--|--|
next|inner/native|**(済)**:ワードリスト内の間接ジャンプ。機械語エントリの最後に`jmp (do_next)`を置く。辞書コンパイラが勝手に置く。定義ワードを自作する場合はこのワードが欲しくなる。
list|inner/native|**(済)**:ワードリスト先頭の機械語コード、IPをRSPに保存してdo_listの次のワードリストにIPを移す
exit|inner/native,<br>code|**(済)**:ワードリスト最後の機械語コード、RSPからIPを戻してnextにジャンプする。コロン定義ワード中でも利用できるので辞書エントリも作っておく。
getch|i/o/native|**(済)**:1バイト入力。キー入力が来るまで待つ。
putch|i/o/native|**(済)**:1バイト出力、Musashiシミュレータの場合1文字1ms程度(おおよそ9600bps)で出力する。
kbhit|i/o/native|キー入力の有無を見る。未実装。
getchar|stream/native|**(済)**:行入力(_accept)を下位に持つ1文字入力ルーチン。acceptが使用する。プロンプトの出力は外部インタプリタで行う。
_rest_stream|ストリームの残文字数を返す(wordデータ)。外部インタプリタがプロンプト出すかどうかの判定で用いる。
interpret|outer/word|外部インタプリタ。WORD, FIND, NUMBERのあと実行またはコンパイルの無限ループ
word|outer/word|**(済)**:S0/\>INから文字列を切り出し辞書末尾(here)に置く。ワード定義の際はその位置でそのまま使える。
find|outer/code|**(済)**:(c-addr -- 0\|xt 1\|xt -1): 切り出したワードを辞書検索する。現在は単一辞書を想定している。見つからなければ0を返す。<br>見つかれば1,-1(immediateワードの場合)の下にexecution tokenを返す。
execute|outer/code|**(済)**:ワードのCFAにジャンプする。コンパイルはinterpret内部で分岐処理する。Moore74によればstateの値により実行またはコンパイルをするらしい。
number|outer/code|**(済)**:(addr -- n1 .. nn, n2): n2==0, fail, 1: single-precision, 2: double-precision。切り出したワードを数字に変換しスタックに載せる。
digit|outer/code|(c base -- n t/f): ASCII文字1文字を数字に変換する。codes.s中のコードを辞書に切り出す。nativeに相当ルーチンがあるが、ワードエントリとしては未実装。
ok|outer/code|( -- ): プロンプトを印字する。
create|outer/word|**(済)**:ストリームから1ワード入力し、辞書末尾に置く。
lit|outer/code|**(済)**:ワードリストに置かれる。数値をスタックに積む仮想機械命令
bra|outer/code|**(済)**:ワードリストに置かれる。無条件相対ブランチ
bne|outer/code|**(済)**:ワードリストに置かれる。条件付き相対ブランチ。非ゼロでジャンプする
quit|outer/code|リターンスタックをリセットし(データスタックはリセットしない)、入力をシステムコンソールにリダイレクトし、外部インタプリタを実行する。
query<br>expect|outer/code|(addr n -- addr): 行入力、1行入力を待ち、末尾にヌル文字を置きリターンする。Starting Forthでは、`S0 @ 80 EXPECT INTERPRET`としている。FORTH-79 Standardでは`QUERY`というらしい。<br>`S0`はデータスタック最上位でここより高いアドレスは未使用で空いているということ。
abort|outer/word|quitを呼び出す。
abort"|outer/word|(x "<text>" --  ): 文字列をキー入力から読み取り、スタックトップの値がゼロであればそのまま進む(エラー扱いしない)。非ゼロであれば文字列を印字しquotを呼び出す。
question|outer/word|エラーメッセージ印字、最後のワード + `?`を印字する。両スタックを空にしてオペレータに制御を返す。OKは表示されない。
'(tick)|outer/word|ワードをストリームから読み込み、辞書サーチして、execution tokenを返す
execute|outer/word|**(済)**:スタック上のexecution tokenを実行する。
_execute|outer/code|executeの実体、%a0レジスタ渡し
;S|outer/code?<br>word?|end of text。ディスクシステムで、各テキストブロックの末尾に必ず`;S`を置くことと、リターンスタックから前のブロックとポインタを取り戻すもの。
here|user/code|**(済)**:辞書末尾、次にワードエントリを置く場所を指す。`H`はhereの値を格納する場所へのアドレスを返す。`h @`と`here`が等価である。
last|user/code|**(済)**:辞書末尾(最新)のエントリの1バイト目(文字列カウント+優先度フラグ)を指す。
state|user/code|**(済)**:実行状態を示す。キー入力されたワードを実行するモードで0、コンパイル時には1となる。
tail|user/code|**(済)**:デバッグ用。エントリも未定義だが、コンパイル時の挙動デバッグのため、このアドレスからダンプするコマンドがある。
base|user/code|**(済)**:number/.(period)など数値変換ワードの基底を保持している。
dp|user/code|辞書にものを並べてゆく際のポインタ, allotは`dp + !`と定義される。
!|mem/code|**(済)**:(n addr --): addrにnを書き込む
@|mem/code|**(済)**:(addr -- n): addrから読み込みスタックに置く
c!|mem/code|**(済)**:(c addr --): addrにバイトcを書き込む
c@|mem/code|**(済)**:(addr -- c): addrから1バイト読み込みスタックに置く
;|dict/word|**(済)**:コンパイルの終了
[|dict/code|**(済)**:コンパイルモードに入る(STATEを1増やす)
]|dict/code|**(済)**:コンパイルモードから抜ける(STATEを1減らす)
forget|dict/word|ワード定義を忘れる
allot|dict/word|**(済)**:作りかけの辞書エントリへのポインタをn増やす
cells|dict/code|n個のセルのメモリサイズ。移植性向上
chars|dict/code|n文字のメモリサイズ、移植性向上
,(camma)|dict/code|辞書に1セルの値を置く。litを置くには`#do_lit , ,`、2度目のカンマでスタック上の値を置くことになる。
c,<br>(c-camma)|dict/code|辞書に1バイトを置く。
put_link|dict/word|**(済)**:ひとつ前の辞書エントリへのリンクを置く。createの下請けワード
immediate|dict/word|最新の辞書エントリに`(優先度1)`ビットを立てる。
put_list|dict/code|**(済)**:`do_list`へのジャンプ命令を置く。`create`の下請けワード
set|dict/code|(n a -- word):ストリームから1ワード読み込みアドレスに置く。
if<br>else<br>then|dict/word|**(済)**:(優先度1)IF ... ELSE ... THEN構造
do|dict/word|(優先度1)(m n --), mはlimit, nはindexをリターンスタックに置く。有限回ループ。最低1回かならず実行される。
?do|dict/word|(優先度1)(m n --): doと似ているが、初回にチェックし、m == nの時はbodyを実行しない。
leave|dict/word?<br>code?|do .. ループを抜ける
i|dict/word|リターンスタック先頭をパラメータスタックにプッシュする。RSPは変更しない。
loop|dict/word|(優先度1)do ... loopの末尾を閉じる。インデックスをインクリメントし、インデックスがlimitと同じかそれ以上になれば抜ける。
begin<br>again|dict/word|(優先度1):無限ループ、エラーが起これば(`THROW`, `ABORT`, `QUIT`等)抜ける。
begin<br>until|dict/word|(優先度1): untilの時点でスタックトップを見てゼロなら抜ける。
(eot)|dict/code|ヌル文字`\0`, 行入力ルーチンは1行を得る(cr/lfを受け取る)と、それをヌル文字に変換してバッファ末尾に置く。ヌル文字1バイトから成るワードとして定義しておき、外部インタプリタを抜ける処理を行う。
:|define/word|**(済)**:コロン定義ワードの定義
variable|define/word|変数定義。次のワードをストリーム入力から読み込み辞書エントリを作る。パラメータフィールドに変数の値を格納する。定義されたワードの実行によりパラメータフィールドのアドレスを返す。
constant|define/word|定数定義。次のワードをストリーム入力から読み込み辞書エントリを作る。パラメータフィールドに定数の値を格納する。定義されたワードの実行によりパラメータフィールドに格納された値を返す。
interger|define/word|変数定義。`VARIABLE`に同じ。
."|define/word|(優先度1)文字列定義、ワード定義中に使用する。辞書領域に文字列を定義する。実行時にはその文字列を印字する
[char]|define/word|(優先度1)次の1文字ワードの文字コードをスタックに置くコードを吐く(lit xxx)
char|define/word|インタプリタ時に、次の1文字ワードの文字コードをスタックに置くコードを吐く。
`<BUILD`.(1)..<br> `DOES>` .(2)..|define/word|(主に)定義ワードを定義する際に用いる。<br>(1)前半はコンパイル時の挙動、(2)後半は実行時の挙動を書く。<br>実行時には定義されたワードのPFAがスタック上に置かれる。<br>`<BULLD`に遭遇すると、STATE値により飛び先を変える判断を置く。`DOES>`は、CREATEされたワードの定義をいったん終了させて、その後ろに無名ワードの定義を開始する。<br>最初のワード先頭のトークンにリターンスタックにそのオペランドを保持しておき、DOES>が出てきた時点でリターンスタックの値が指すオペランドの飛び先を確定させる。という感じかな。<br>
\>BODY|define/word|create ... does> ... ワードのCFAを取り、それに結びついた固有データ領域のメモリアドレス(PFA?)を返す。
dup|stack/code|**(済)**:(n -- n n)
over|stack/code|**(済)**:(m n -- m n m)
drop|stack/code|**(済)**:(m n -- m)
swap|stack/code|**(済)**:(m n -- n m)
rot|stack/code|**(済)**:(l m n -- m n l)
\>R|rstack/code| スタックトップをRSにプッシュ
R\>|rstack/code|RSトップをスタックにプッシュ
.|print/code|**(済)**:(n -- ):数値出力。baseの値に基づき基数を決める。
?|print/code|(addr -- )数値出力。addrの先のワードを取り込み印字。
count|print/word|(addr -- addr+1 n)文字列のcountフィールドと本体のアドレスを返す。
emit|print/code|**(済)**:スタック上の値を印字する。
type|print/word|(a n --): アドレスaから文字n個を印字する
decimal|print/word|**(済)**:baseを10にする。10進変換指示。
octal|print/word|
hex|print/word|**(済)**:baseを16にする。
key|input/code|キーボードからの1文字入力、いまはストリーム入力からの1文字と同一とする。
key?|input/code|kbhit
accept|input/code|(addr +n -- len): ストリーム入力をバッファに読み込み、読み込み長を返す。アセンブラ版を辞書に移動させる。実際は`getchar`で入力する。
expect|input/code|(addr +n -- ): acceptと同じ、ただし末尾に2バイトのnullを置く。本システムではacceptを使い、expectは使わない。
s"|input/code|( -- caddr len): ダブルクォートのみの単語までの文字列を入力し、どこかのバッファに置く。とりあえず辞書末尾かな。
s"|input/code|( -- caddr): 長さ付文字列をバッファに置く。とりあえず辞書末尾(DP)。
s0|input/var|( -- addr): 行入力バッファアドレスの変数(のアドレスをスタックに置く)。`s0 @`で行入力バッファアドレスを得る。外部インタプリタの`accept`の入力バッファ
\>in|input/var|( -- n): 行入力バッファ中のカレントインデックス。ポインタでなくインデックス。`s0 @ >in @ +`で現在の文字を指すアドレスを得る。
_read_ch|input/word|( -- ch): 行入力バッファから1文字読み込みスタックに置く。カレントポインタを1増やす。行末でEOT(`\0`)を置く。一度`\0`を読み込むとりせっつするまではEOTを返す。リセットは`0 \>in !`。
count|string/word|(caddr -- caddr+1 length): 長さ付文字列を入力とし、文字列本体と長さをスタックに積む。
minus|arith/code|(n -- -n)
abs|arith/code|(n -- \|n\|)
+|arith/code|**(済)**:(m n -- (m + n))
-|arith/code|**(済)**:(m n -- (m - n))
\*|arith/code|**(済)**:(m n -- (m * n))
/|arith/code|**(済)**:(m n -- (m / n))
max|arith/code|(m n -- max(m,n)) 
min|arith/code|(m n -- min(m,n))
mod|arith/code|(m n -- (m % n))
\*/|arith/word|(l m n -- mm):l \* m / nを置く。固定小数点数用
0=|arith/code|非ゼロでfalse, ゼロでtrue
0\<|arith/code|(m n -- (m < n))
0\>|arith/code|(m n -- (m > n))
||||

#### 今回は実装しないが、次回実装予定

|cat|name|stack spec|description|
|--|--|--|--|
|double|...|...|倍長整数、2ワードを使って32ビット整数を表現する。68000とASCIIART.BAS的にはぜひ欲しいが今回は時間切れでパス
|||

#### 採用しないワード

複数辞書、エディタ、ディスクアクセス関連ワードは実装しない。

|cat|name|stack spec|description|
|--|--|--|--|
|...|pad|...|文字列バッファとして用いる。ANS Forthで定義されるワード。昔はなかったので、昔風味の本システムでは採用しない。
|...|#,\<#,#>|...|書式出力。強力なので本物のアプリケーション作るなら欲しいが、今回はそこまでは要らない。実装が結構面倒そうなので省略する。
|dict|vocabrary|...|複数辞書のサポート
|dict|context|...|カレント辞書の指定
|....|wordlist|...|検索対象としてのwordlistも使わない。検索対象は辞書のみとする。
|i/o|block,...|...|ディスクI/O、ブロック番号を指定してR/W、キャッシュバッファ、バッファ内部のR/Wなど。これも使わなそうだけど大変そうなのでバッサリ省く。
|||
