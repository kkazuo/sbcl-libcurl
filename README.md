# SBCL の外部関数呼び出し機能を使って libcurl で HTTP リクエストしてみる実験

以下で動くと思う。

    sbcl --load sbcl-libcurl.lisp --eval '(sbcl-libcurl::xxx)' --no-userinit --non-interactive

確かにデータは取れるので、頑張ればいろいろできるのだろうとは思うが、面倒になって途中でめげてしまった。

# LICENSE

MIT
