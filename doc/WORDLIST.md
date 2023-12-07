## narrowroad-forth ワード表

POLだけでなく、Moore74, Starting-Forth, Programming Forth(Stephjen Pelc, 2011)も参考にして独断と趣味で選んだ。

type:
* native: 辞書に書かない。`codes.s`内の機械語ルーチン
* code: 辞書に書く機械語ワード、nextで内部インタプリタにジャンプする。
 * word: 辞書に書くワードリストのワード、IPが順次各ワードのCFA(通常listルーチン)にジャンプしてゆく。最後はexitでIPを戻して呼び出し元に戻る。

category:
* inner: 内部インタプリタ
* outer: 外部インタプリタ
* i/o: 入出力ルーチン、今回はシリアルI/Oと行バッファリングのみ。
* user: ユーザ変数。ユーザ定義でなく、システムが提供する変数。なぜユーザ変数というかはよく分からない。
* arith: 算術オペレータ
* dict: コンパイル用ワード
* stream: ストリーム入力(`getchar`のみ)
* define: 定義語
* print:
* input:
* string:

**execution token(xt)**: 呼び出すアドレス。辞書エントリのCFAである。

||cat|name|type|description|
|--|--|--|--|--|
|x|inner|next|native|ワードリスト内の間接ジャンプ。機械語エントリの最後に`jmp (do_next)`を置く。辞書コンパイラが勝手に置く。
|x|inner|list|native|ワードリスト先頭の機械語コード、IPをRSPに保存してdo_listの次のワードリストにIPを移す
|x|inner|exit|native,<br>code|ワードリスト最後の機械語コード、RSPからIPを戻してnextにジャンプする。コロン定義ワード中でも利用できるので辞書エントリも作っておく。
|x|i/o|getch|native|1バイト入力。キー入力が来るまで待つ。
|x|i/o|putch|native|1バイト出力、Musashiシミュレータの場合1文字1ms程度(おおよそ9600bps)で出力する。
||i/o|kbhit|native|キー入力の有無を見る。未実装。
|x|stream|getchar|native|行入力(_accept)を下位に持つ1文字入力ルーチン。wordが使用する。プロンプトの出力もここで行う。
||outer|interpret|word|外部インタプリタ。WORD, FIND, NUMBERのあと実行またはコンパイルの無限ループ
|x|outer|word|word|入力ストリームから文字列を切り出し辞書末尾(here)に置く。ワード定義の際はその位置でそのまま使える。
|x|outer|find|code|(c-addr -- 0\|xt 1\|xt -1): 切り出したワードを辞書検索する。現在は単一辞書を想定している。見つからなければ0を返す。<br>見つかれば1,-1(immediateワードの場合)の下にexecution tokenを返す。
|x|outer|execute|code|ワードのCFAにジャンプする。コンパイルはinterpret内部で分岐処理する。Moore74によればstateの値により実行またはコンパイルをするらしい。
|x|outer|number|code|(addr -- n1 .. nn, n2): n2==0, fail, 1: single-precision, 2: double-precision。切り出したワードを数字に変換しスタックに載せる。
||outer|digit|code|(c base -- n t/f): ASCII文字1文字を数字に変換する。codes.s中のコードを辞書に切り出す。nativeに相当ルーチンがあるが、ワードエントリとしては未実装。
||outer|ok|code|( -- ): プロンプトを印字する。
|x|outer|create|word|ストリームから1ワード入力し、辞書末尾に置く。
|x|outer|lit|code|ワードリストに置かれる。数値をスタックに積む仮想機械命令
|x|outer|bra|code|ワードリストに置かれる。無条件相対ブランチ
|x|outer|bne|code|ワードリストに置かれる。条件付き相対ブランチ。非ゼロでジャンプする
||outer|quit|code|リターンスタックをリセットし(データスタックはリセットしない)、入力をシステムコンソールにリダイレクトし、外部インタプリタを実行する。
||outer|query<br>expect|code|(addr n -- addr): 行入力、1行入力を待ち、末尾にヌル文字を置きリターンする。Starting Forthでは、`S0 @ 80 EXPECT INTERPRET`としている。FORTH-79 Standardでは`QUERY`というらしい。<br>`S0`はデータスタック最上位でここより高いアドレスは未使用で空いているということ。
||outer|abort|word|quitを呼び出す。
||outer|abort"|word|(x "<text>" --  ): 文字列をキー入力から読み取り、スタックトップの値がゼロであればそのまま進む(エラー扱いしない)。非ゼロであれば文字列を印字しquotを呼び出す。
||outer|question|word|エラーメッセージ印字、最後のワード + `?`を印字する。両スタックを空にしてオペレータに制御を返す。OKは表示されない。
||outer|'(tick)|word|ワードをストリームから読み込み、辞書サーチして、execution tokenを返す
|x|outer|execute|word|スタック上のexecution tokenを実行する。
||outer|_execute|code|executeの実体、%a0レジスタ渡し
||outer|;S|code?<br>word?|end of text。ディスクシステムで、各テキストブロックの末尾に必ず`;S`を置くことと、リターンスタックから前のブロックとポインタを取り戻すもの。
|x|user|here|code|辞書末尾、次にワードエントリを置く場所を指す。`H`はhereの値を格納する場所へのアドレスを返す。`h @`と`here`が等価である。
|x|user|last|code|辞書末尾(最新)のエントリの1バイト目(文字列カウント+優先度フラグ)を指す。
|x|user|state|code|実行状態を示す。キー入力されたワードを実行するモードで0、コンパイル時には1となる。
|x|user|tail|code|デバッグ用。エントリも未定義だが、コンパイル時の挙動デバッグのため、このアドレスからダンプするコマンドがある。
|x|user|base|code|number/.(period)など数値変換ワードの基底を保持している。
||user|dp|code|辞書にものを並べてゆく際のポインタ, allotは`dp + !`と定義される。
|x|mem|!|code|(n addr --): addrにnを書き込む
|x|mem|@|code|(addr -- n): addrから読み込みスタックに置く
|x|mem|c!|code|(c addr --): addrにバイトcを書き込む
|x|mem|c@|code|(addr -- c): addrから1バイト読み込みスタックに置く
|x|dict|;|word|コンパイルの終了
|x|dict|[|code|コンパイルモードに入る(STATEを1増やす)
|x|dict|]|code|コンパイルモードから抜ける(STATEを1減らす)
||dict|forget|word|ワード定義を忘れる
|x|dict|allot|word|作りかけの辞書エントリへのポインタをn増やす
||dict|cells|code|n個のセルのメモリサイズ。移植性向上
||dict|chars|code|n文字のメモリサイズ、移植性向上
||dict|,(camma)|code|辞書に1セルの値を置く。litを置くには`#do_lit , ,`、2度目のカンマでスタック上の値を置くことになる。
||dict|c,(c-camma)|code|辞書に1バイトを置く。
|x|dict|put_link|word|ひとつ前の辞書エントリへのリンクを置く。createの下請けワード
||dict|immediate|word|mark precedence to the last entry to 1
|x|dict|put_list|code|do_listへのジャンプ命令を置く。createの下請けワード
||dict|set|code|(n a -- word):ストリームから1ワード読み込みアドレスに置く。
||dict|if<br>else<br>then|word|(優先度1)IF ... ELSE ... THEN構造
||dict|do|word|(優先度1)(m n --), mはlimit, nはindexをリターンスタックに置く。有限回ループ。最低1回かならず実行される。
||dict|?do|word|(優先度1)(m n --): doと似ているが、初回にチェックし、m == nの時はbodyを実行しない。
||dict|leave|word?<br>code?|do .. ループを抜ける
||dict|i|word|リターンスタック先頭をパラメータスタックにプッシュする。RSPは変更しない。
||dict|loop|word|(優先度1)do ... loopの末尾を閉じる。インデックスをインクリメントし、インデックスがlimitと同じかそれ以上になれば抜ける。
||dict|begin<br>again|word|(優先度1):無限ループ、エラーが起これば(`THROW`, `ABORT`, `QUIT`等)抜ける。
||dict|begin<br>until|word|(優先度1): untilの時点でスタックトップを見てゼロなら抜ける。
||dict|(eot)|code|ヌル文字`\0`, 行入力ルーチンは1行を得る(cr/lfを受け取る)と、それをヌル文字に変換してバッファ末尾に置く。ヌル文字1バイトから成るワードとして定義しておき、外部インタプリタを抜ける処理を行う。
|x|define|:|word|コロン定義ワードの定義
||define|variable|word|変数定義
||define|constant|word|定数定義
||define|interger|word|変数定義
||define|."|word|(優先度1)文字列定義、ワード定義中に使用する。辞書領域に文字列を定義する。実行時にはその文字列を印字する
||define|[char]|word|(優先度1)次の1文字ワードの文字コードをスタックに置くコードを吐く(lit xxx)
||define|char|word|インタプリタ時に、次の1文字ワードの文字コードをスタックに置くコードを吐く。
||define|create .(1)..<br> DOES> .(2)..|word|DOES>は、CREATEされたワードの定義をいったん終了させて、その後ろに無名ワードの定義を開始する。<br>最初のワード先頭のトークンにSTATE値により飛び先を変える判断を置く。リターンスタックにそのオペランドを保持しておき、DOES>が出てきた時点でリターンスタックの値が指すオペランドの飛び先を確定させる。という感じかな。<br>(1)前半はコンパイル時の挙動、(2)後半は実行時の挙動を書く。実行時には定義されたワードのPFAがスタック上に置かれる。
||define|\>BODY|word|create ... does> ... ワードのCFAを取り、それに結びついた固有デンター領域のメモリアドレス(PFA?)を返す。
|x|stack|dup|code|(n -- n n)
|x|stack|over|code|(m n -- m n m)
|x|stack|drop|code|(m n -- m)
|x|stack|swap|code|(m n -- n m)
|x|stack|rot|code|(l m n -- m n l)
||rstack|\>R|code| スタックトップをRSにプッシュ
||rstack|R\>|code|RSトップをスタックにプッシュ
|x|print|.|code|(n -- ):数値出力。baseの値に基づき基数を決める。
||print|?|code|(addr -- )数値出力。addrの先のワードを取り込み印字。
||print|count|word|(addr -- addr+1 n)文字列のcountフィールドと本体のアドレスを返す。
|x|print|emit|code|スタック上の値を印字する。
||print|type|word|(a n --): アドレスaから文字n個を印字する
|x|print|decimal|word
||print|octal|word
|x|print|hex|word
||input|key|code|キーボードからの1文字入力、いまはストリーム入力からの1文字と同一とする。
||input|key?|code|kbhit
||input|accept|code|(addr +n -- len): ストリーム入力をバッファに読み込み、読み込み長を返す。アセンブラ版を辞書に移動させる。実際はgetchar/keyで入力する。
|-|input|expect|code|(addr +n -- ): acceptと同じ、ただし末尾に2バイトのnullを置く。本システムではacceptを使い、expectは使わない。
||input|S"|code|( -- caddr len): ダブルクォートのみの単語までの文字列を入力し、どこかのバッファに置く。とりあえず辞書末尾かな。
||input|C"|code|( -- caddr): 長さ付文字列をバッファに置く。とりあえず辞書末尾(DP)。
||string|count|word|(caddr -- caddr+1 length): 長さ付文字列を入力とし、文字列本体と長さをスタックに積む。
||arith|minus|code|(n -- -n)
||arith|abs|code|(n -- `|n|`)
|x|arith|+|code|(m n -- (m + n))
|x|arith|-|code|(m n -- (m - n))
|x|arith|\*|code|(m n -- (m * n))
|x|arith|/|code|(m n -- (m / n))
||arith|max|code|(m n -- max(m,n)) 
||arith|min|code|(m n -- min(m,n))
||arith|mod|code|(m n -- (m % n))
||arith|\*/|word|(l m n -- mm):l \* m / nを置く。固定小数点数用
||arith|0=|code|非ゼロでfalse, ゼロでtrue
||arith|0\<|code|(m n -- (m < n))
||arith|0\>|code|(m n -- (m > n))

#### 今回は実装しないが、次回実装予定

|cat|name|stack spec|description|
|--|--|--|--|
|double|...|...|倍精度整数、2ワードを使って32ビット整数を表現する。68000とASCIIART.BAS的にはぜひ欲しいが今回は時間切れでパス


#### 採用しないワード

|cat|name|stack spec|description|
|--|--|--|--|
|...|pad|...|文字列バッファとして用いる。ANS Forthで定義されるワード。昔はなかったので、昔風味の本システムでは採用しない。行バッファの存在は`getchar`の下に隠蔽されている。
|...|#,\<#,#>|...|書式出力。強力なので本物のアプリケーション作るなら欲しいが、今回はそこまでは要らない。実装が結構面倒そうなので省略する。
|dict|vocabrary|...|複数辞書のサポート
|dict|context|...|カレント辞書の指定
|....|wordlist|...|検索対象としてのwordlistも使わない。検索対象は辞書のみとする。
|i/o|block,...|...|ディスクI/O、ブロック番号を指定してR/W、キャッシュバッファ、バッファ内部のR/Wなど。これも使わなそうだけど大変そうなのでバッサリ省く。
