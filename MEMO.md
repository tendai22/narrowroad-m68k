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
* abcが動作しない。nop not foundが出る。

