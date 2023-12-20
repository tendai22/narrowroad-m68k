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

* `WORD`が直接1文字入力することは断念した。インタプリタが行入力単位処理が存在する(プロンプト出す)、伝統的に、主要な実装はすべて「1行入力->バッファからWORDはワード切り出す」となっており、そこから外れることは気持ち悪い。
* 一方、外部ファイル入力とキー入力は1文字入力単位で統一したい気持ちも高い。
* プロンプト出しは、「行入力してから出す」ではだめで、「行入力開始の最初の1文字読み込みに入る前に出す」でないとプロンプト出しにならない。
* 外部ファイル読み込み時はプロンプト出しはさせない(させたくない、してはいけない)。
* とすると、外部ファイル入力時を文字読み込みに入る前に知る方法を用意する必要がある。

ここまで考えて以下の方針を決めた。

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
* 追加定義辞書のダンプ(デバッグ時に見るため、ファイルとして落としたいのでエミュレータに組み込む、バイナリをファイルにはいてmakedict.shを手で起動するか、SBC版はダンプ先が面倒、フラッシュ書き込み？)
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

### DOループ実装の注意(12/19)

* Starting Forthから
* 増やした時は`>=`だが、減らすときは`<`である(イコールは入らない)
* `LEAVE`は、インデックスを上限値にセットする(減らすとき大丈夫なのか？)
* `DO`ループは少なくとも1回は実行される。
* `I`はリターンスタックの1番目をパラメータスタックに戻す
* `I'`はリターンスタックの2番目をパラメータスタックに戻す
* `J`はリターンスタックの3番目をパラメータスタックに戻す
* `DO`はインデックスと上限値をパラメータスタックからリターンスタックに移動させる。


### Starting Forthの注3

Many professional FORTH programmers who have been writing complex applications for years have never had to use floating-point. And their applications often involve solutions of differential equations, Fast Fourier Transforms, non-linear least squares fitting, linear regression, etc. Problems that traditionally required a main-frame have been done on slower minicomputers and microprocessors, in some cases with an overall increase in computation rate.

何年も複雑なアプリケーションを書き続けているプロの FORTH プログラマの多くは、浮動小数点を使ったことがありません。そして彼らのアプリケーションは、微分方程式の解法、高速フーリエ変換、非線形最小二乗法、線形回帰などを含むことが多い。従来はメインフレームが必要だった問題が、より低速のミニコンピュータやマイクロプロセッサで処理されるようになり、場合によっては全体的な計算速度が向上することもある。

Most problems with physical inputs and outputs, including weather modeling, image reconstruction, automated electrical measurements, and the like all involve input and output variables that inherently have a dynamic range of no more than a few thousand to one, and thus fit comfortably into a 16-bit integer word. Intermediate calculation steps (such as summation) can be handled by the judicious use of scaling and double-length integers where required. For example, one common calculation step might involve multiplying each data point by a parameter (or by itself) and summing the result. In fixed point, this would be a 16 x 16-bit multiply and 32-bit summation. In floating-point, numbers are likely stored as 24-bit mantissa and 8-bit exponents. The 24-bit multiply will take about 1.5 times longer and the 32-bit addition 3-10 times longer than in fixed point. There is also the overhead of floating all the input data and fixing all the output data, approximately equal to one floating point addition each. When these operat ~ons are performed thousands or millions of times, the overall saving by remaining in integer form is enormous.

気象モデリング、画像再構成、自動電気測定など、物理的な入出力を伴うほとんどの問題は、本質的に数千分の1以下のダイナミックレンジしか持たない入出力変数を含むため、16ビット整数ワードに快適に収まる。中間的な計算ステップ(総和など)は、必要に応じて倍長整数とスケーリングを使用することで処理できます。例えば、一般的な計算ステップでは、各データポイントにパラメータ（またはそれ自身）を乗算し、その結果を合計することがあります。固定小数点では、これは 16 x 16 ビットの乗算と 32 ビットの和算になります。浮動小数点では、数値は 24 ビットの仮数と 8 ビットの指数として格納されます。24ビットの乗算には約1.5倍、32ビットの加算には固定小数点の3～10倍の時間がかかります。また、すべての入力データを浮動小数点化し、すべての出力データを固定小数点化するオーバーヘッドが発生します。これらの演算が何千回、何百万回と実行される場合、整数のままであることによる全体的な節約は、固定小数点演算の3倍から10倍になる、整数形式のままであることによる全体的な節約は莫大である。

### Starting Forth "Why FORTH Programmers Advocate Fixed-Point"

Many respectable languages and many distinguished programmers use floating-point arithmetic as a matter of course. Their opinion might be expressed like this: "Why should I have to worry about moving decimal points around? That's what computers are for."

多くの立派な言語と多くの著名なプログラマーは、当然のように浮動小数点演算を使っている。彼らの意見はこうだ： 「小数点の移動について心配する必要があるのか？そのためにコンピューターがあるんだ」。

That's a valid question--in fact it expresses the most significant advantage to floating-point implementation. For translating a mathematical equation into program code, having a floating-point language makes the programmer's life easier.

実際、これは浮動小数点実装の最も重要な利点を表している。数式をプログラムコードに変換する場合、浮動小数点言語があればプログラマは楽になります。

The typical FORTH programmer, however, perceives the role of a computer differently. A FORTH programmer is most interested in maximizing the efficiency of the machine.   That means he or she wants to make the program run as fast as possible and require as little computer memory as possible.

しかし、典型的なFORTHプログラマは、コンピュータの役割を異なったものとして捉えています。FORTHプログラマーは、マシンの効率を最大化することに最も関心があります。  つまり、プログラムをできるだけ速く走らせ、コンピュータのメモリをできるだけ少なくしたいのです。

To a FORTH programmer, if a problem is worth doing on a computer at all, it is worth doing on a computer well. The philosophy is, "If you just want a quick answer to a few calculations, you might as well use a hand-held calculator." You won't care i f the calculator takes half a second to display the result. But if you have invested in a computer, you probably have to repeat the same set of calculations over and over and over again. Fixed-point arithmetic will give you the speed you need.  

FORTHプログラマーにとって、ある問題をコンピュータで処理する価値があるならば、それはコンピュータでうまく処理する価値がある。その哲学は、"ちょっとした計算ですぐに答えが知りたいなら、手持ちの電卓を使った方がいい "というものです。電卓が結果を表示するのに0.5秒かかっても気にしないでしょう。しかし、コンピュータに投資しているのであれば、同じ計算を何度も何度も繰り返さなければならないだろう。固定小数点演算を使えば、必要なスピードが得られる。 

Is the extra speed that noticeable? Yes, it is. A floating - point multiplication or division can take three times as long as its equivalent fixed-point calculation. The difference is really noticeable in programs which have to do a lot of calculations before sending results to a terminal or taking some action. [3] Most mini- and microcomputers don't "think" in floating-point; you pay a heavy penalty for making them act as though they do.

その速度はそれほど顕著なものなのだろうか? そうです。浮動小数点数の掛け算や割り算は、同等の固定小数点数の計算に比べて3倍の時間がかかることがあります。この差は、結果を端末に送ったり、何らかのアクションを起こしたりする前に多くの計算をしなければならないプログラムで顕著に現れます。[3] ほとんどのミニコンピュータやマイクロコンピュータは、浮動小数点で「考える」ことはしません。

Here are some of the reasons you might prefer to have floating-point capability.

以下に、浮動小数点演算機能を搭載した方が良い理由をいくつか挙げます。

1. You want to use your computer like a calculator on floating-point data.

2. You value the initial programming time more highly than the execution time spent every time the calculation is performed.

3. You want a number to be able to describe a very large dynamic range (greater than -2 billion to +2 billion). 

4. Your system includes a discrete hardware floating-point multiply (a separate "chip" whose only job is to perform floating-point multiplication at super high speeds).

All of these are valid reasons. Even Charles Moore, perhaps the staunchest advocate of simplicity in the programming community, has occasionally employed floating-point routines when the hardware supported it. Other FORTH programmers have written floating-point routines for their mini- and microcomputers. But the mainstream FORTH philosophy remains: "In most cases, you don't need to pay for floating-point."

1. コンピュータを浮動小数点数電卓のように使いたい。

2. 計算を実行するたびにかかる実行時間よりも、最初に必要なプログラミング時間を重視したい。

3. 非常に大きなダイナミックレンジ(-20億から＋20億以上)を表現できる数値が欲しい。

4. システムに個別のハードウェア浮動小数点乗算器(超高速で浮動小数点乗算を実行するに特化した別チップ）を搭載している。


これらはすべて正当な理由である。プログラミング界で最も単純化を堅く支持するといってもいいだろうチャールズ・ムーアでさえ、ハードウェアがサポートしていれば、浮動小数点ルーチンを使うことがありました。他のFORTHプログラマーも、ミニコンピュータやマイクロコンピュータのために浮動小数点ルーチンを書いています。しかし、FORTH哲学の主流は変わっていません: "ほとんどの場合、浮動小数点にお金を払う必要はない"。

FORTH backs its philosophy by supplying the programmer with a unique set of high-level commands called "scaling operators." We'll introduce the first of these commands in the next section. (The final example in Chap. 12 illustrates the use of scaling techniques.)

FORTHは、プログラマに "スケーリング演算子"と呼ばれるユニークな高レベルコマンド群を提供することで、その哲学を裏付けています。これらのコマンドの最初のものを次の章で紹介します(第12章の最後の例は、スケーリング技法の使用法を示している)。
