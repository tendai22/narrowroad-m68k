### narrowroad-m68k v200時点の課題(12/18)

* 入力系の再構築、現状ではワード処理ごとにプロンプトが出てしまっている。伝統にしたがい行入力と文字スキャンを分けるべき。acceptの復活。
* Starting Forthに従う。
  + `S0`: スタックの後ろに行入力バッファを取る。
  + `>IN`: 行入力バッファ内の解釈インデックス、`WORD`はこのインデックスに基づき文字を読み、このインデックスを進める。
  + バッファ終端をヌル文字で発見する。`WORD`ループでヌル文字チェックを入れる。
  + PAD: 独立したバッファ。WORDの行き先をHEREにしているので当面使わない

### _read_ch: 1文字入力を作った(12/18)

* wordで使用される。
* S0[>IN]から1文字読み取る。
* EOT('\0')に達するとずっとEOTを返し続ける(`>IN`をそれ以上増やさない)

### accept, word, find, numberをデバッグした(12/18)

* 辞書版でデバッグ、動作し始めている。
* 外部インタプリタの `find`の返り値の処理が未対応。

### 外部ファイル読み込み案(12/19)

* acceptを介して読み込む(つまり、外部ファイル入力も行単位で処理される)
* acceptは`getchar`を使って1文字読み込む。
* `getchar`が、「外部ファイルをすべて読み込んだあとシリアル入力に切り替える」とする(テストしていないがコード書き済)。
* 外部インタプリタのプロンプト有無判断は、`getchar`入力の外部ファイルデータ残りが0かどうか、で判断する(`_rest_stream`を作る)。`getchar`を呼び出す前に判断できるようにすること。

### 残件思いつくまま(12/19)

* 外部インタプリタをまず動かす(`find`の返り値処理とcompile/execute区別が未だ)。
* 外部ファイル読み込み(→これで組み込みForthコードが使える)
* 行末コメント, 括弧コメント対応
  * `accept`でコメントを削除して読み込む。
  * `//`のコメントを削除(バッファ入力後にスキャン)。使えると便利だが結構面倒くさい。
  * `( ... )`も削除する(読み込み時に削除)。
* 追加定義辞書のダンプ(デバッグ時に見るため、ファイルとして落としたいのでエミュレータに組み込む、バイナリをファイルにはいてmakedict.shを手で起動するか)
* ループ構造: 
  + begin ... again : 無限ループ
  + begin ... until / until: (f -- ): ループ末尾でfalseなら抜ける
  + begin xxx while yyy repeat / while (f -- ): 初回に xxx, ループで yyy実行、whileで脱出判定
  + do ... loop / do: (limit index --) / loop: ( -- )(常にプラス1)
  + do ... /loop / do: (u-limit u-index --), /loop (u -- )(符号なし整数)
  + do ... +loop / do: (limit index --), +loop (n -- ) (nずつ増やす)
  + leave: 次の loop/+loopでループを終了させる
* 文字列定義: ダミー名を付した辞書エントリ、パラメータフィールドにカウント付き文字列として展開する。CFAはパラメータフィールドアドレス(カウント付き文字列のポインタ)を返す。
* `QUIT`: 外部インタプリタのコロン定義化
* ABORTの実装
* この辺でひと段落かな。
* codes.sのシンプル化。puthexもbase.dictに移す。
* codes.sに残すもの。
  * execute
  * list, next, exit
  * putch, getch, kbhit
  * quit呼び出し(quitで外部インタプリタ完全初期化、辞書は触らない)
  * abortの飛び先
* base.dictに移すもの
  * outer: 外部インタプリタ
  * check_if_compile
  * lit, bra, bne(名前が表示されるように)
  * dump_stack,
  * getchar
  * putstr
  * puthex8,4,2,1
  * putnum, put1digit
  * crlf, space
  * typeb
  * accept
  * tonumber, number 
  * do_number_asm(消す。もう使っていない)
  * do_word_asm(消す、もう使っていない)
  * do_same(ワード化する)
  * do_find_asm(消す、もう使っていない)
  * dump_entry