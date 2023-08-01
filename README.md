# narrowroad-m68k

narrowroad, a kind of Forth implementation  for Motorola 68000 CPU.

narrowroadは、同人誌「Octalのほそ道」(C102頒布予定)の中で実装を進めている Forth処理系です。本リポジトリは Motorola 68000 用の実装です。

「Octalのほそ道」のテーマは、1970年ごろにForth処理系を開発したCharles Mooreさんのたどった道をたどるというものです。彼の論文を読み解きながら、自分の手で、未知のCPUのアセンブラで開発して、その過程を誌面に記していました。

C102で頒布した時点では、はっきり言って1 + 2 = 3を計算して3を印字するだけのものでした。実装を継続し、それなりのForth処理系に仕立てたいと考えて、同人誌に収めたコードにより本リポジトリを立て、以後の開発はこちら側で行うと考えています。

## 本リポジトリの内容

同人誌に収録したソースコードを入れています。外部インタプリタ`outer.s`は、それ自体にインタプリタと辞書を含み、このファイル単独でアセンブルしてForth処理系を実行できます。

その他のソースコード`*.s`は、開発過程で作成したもので、おまけで付けてあります。

シェルスクリプト(`*.sh`)は、アセンブル、アップロードファイル生成を行うものです。ソー

```
$ sh as.sh outer.s
```
によりソースコード`outer.s`がアセンブルされ、バイナリファイル`a.out`が生成されます。これを直接実行できるハードウェアは存在せず、私が作成したSBC(Single Board Computer) [EMU68kplus](https://github.com/tendai22/emu68kplus)上で動作するようにしています。

プログラムの実行は、emu68kplusにシリアルポート経由でアップロードすることで行います。emu68kplusが起動すると、シリアル入力からアップロードされたファイルをRAM上に展開する簡易モニタが実行されているので、それにめがけて(例えばTeratermのテキストアップロード機能を用いて)以下のコマンドで形式変換したファイルをアップロードします。

```
$ sh dump.sh > outer.X
```
シェルスクリプト`dump.sh`は、直前にアセンブラが生成したバイナリ`a.out`のバイナリデータをアップロード可能な形式に変換します。この`outer.X`ファイルをアップロードし、リセット解除するとプログラム実行が開始されます。

## SBCエミュレータ

SBCエミュレータ [`Musashi`改](https://github.com/tendai22/Musashi) を用いると、ハードウェアなしでLinux上で外部インタプリタを試すことができます。この中の`example/m68kcpu.c`の命令実行ループの中に仕込みを入れて、ブレークポイントとシングルステップ機能を入れて、narrowroadのアセンブラプログラムを開発していました。

`Musashi`改をcloneしmakeすると、コマンド`sim`が生成されます。この引数に`outer.X`を指定するとプログラム実行を開始します。`Musashi`リポジトリで得られた`sim`コマンドを本リポジトリにコピーして、

```
$ ./sim outer.X
```
と実行すればよい。

## 現時点の到達点であり出発点: 外部インタプリタ`outer.s`

* 内部インタプリタ、外部インタプリタは実装済、動作する。
* 辞書は手組みで、`+`(加算)、`.`(スタックトップ整数印字)ぐらいしか意味のあるワードはない。
* もちろん、エディタ、HDDサポートも一切ありません。

