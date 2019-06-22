#!/usr/local/bash -eu

# $1: セット数（未指定または負の値を指定した場合は無限ループ）
defaultSetNum=-1
setNum=${1:-defaultSetNum}
echo setNum is $setNum

# $2: 1セットあたりの試合数
defaultGameNum=10000
gameNum=${2:-defaultGameNum}
echo gameNum is $gameNum

# セットを回すためのループ
setCount=0
while : ; do
    if [ $setNum -gt 0 -a $setCount -ge $setNum ]; then
        break
    fi

    echo Starting set $(($setCount + 1))...

    # クライアント一覧を取得 -> allClients
    allClients="./clients/*"

    # allClients から、有効なクライアントのみを列挙 -> enabledClients
    enabledClients=()
    for c in ${allClients[@]}; do
        if [ -f $c ]; then
            # ディレクトリではないため無視する
            :
        elif [[ `basename $c` =~ ^\..+ ]]; then
            # ディレクトリ名が "." から始まるため無視する
            echo "$c was ignored"
        elif [ ! -e "$c/client" ]; then
            # ディレクトリ直下に client が存在しないため無視する（標準エラー出力に出す）
            echo "$c was ignored because ${c} does not have \"client\"" >&2
        else
            enabledClients+=($c)
        fi
    done

    if [ ${#enabledClients[@]} -lt 5 ]; then
        # 有効なクライアントが5個未満であるため終了
        echo "Clients is too few" >&2
        exit 1
    fi

    # クライアント一覧から5個のクライアントをランダムに選出する
    # TODO: このクライアントを固定にするリスト.txt
    defaultIFS=IFS
    IFS=$'\n'
    entriedClients=(`echo "${enabledClients[*]}" | shuf -n 5`)
    IFS=$defaultIFS

    # サーバ起動
    echo Starting server...
    ./server -g $gameNum >> .log &
    serverPID=$!

    # クライアント起動
    for c in ${entriedClients[@]}; do
        sleep 1
        clientName=`basename $c`
        echo "Starting $clientName..."
        # PWD=`pwd`
        cd "$c"
        `./client -n $clientName &>> .log &`
        cd ../..
    done

    # サーバとクライアントの終了を待機
    echo Waiting for finishing of $gameNum games...
    wait

    # サーバの出力から、マスタへ送信するログファイルを生成
    echo Starting to generate log files...

    # マスタにログファイルを送信
    echo Sending log files to Master...

    echo End of set $(($setCount + 1))
    let setCount++ || :
done

# セットを回すためのループ終了
echo Finish
exit 0
