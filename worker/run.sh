#!/usr/bin/env bash
# envのパスが合わない場合は適宜マシンごとに変更を加える
set -eu

# セット数（未指定または負の値を指定した場合は無限ループ）
readonly setNum=`head -n 1 ./config/setnum.txt | tr -d '\r' | tr -d '\n'`
echo setNum is $setNum

# 1セットあたりの試合数
readonly gameNum=`head -n 1 ./config/gamenum.txt | tr -d '\r' | tr -d '\n'`
echo gameNum is $gameNum

# 必ず選出されるクライアント
readonly fixedClient=`head -n 1 ./config/fixedclient.txt | tr -d '\r' | tr -d '\n'`
if [ -z "$fixedClient" ]; then
    echo No client is fixed.
else
    echo fixedClient is $fixedClient
fi

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
        elif [ ! -f "$c/client" ]; then
            # ディレクトリ直下に client というファイルが存在しないため無視する（標準エラー出力に出す）
            echo "! $c was ignored because ${c} does not have \"client\"" >&2
        else
            enabledClients+=($c)
        fi
    done

    if [ ${#enabledClients[@]} -lt 5 ]; then
        # 有効なクライアントが5個未満であるため終了
        echo "!!! Clients is too few" >&2
        exit 1
    fi

    entriedClients=()

    if [ -z "$fixedClient" ]; then
        # クライアント一覧から5個のクライアントをランダムに選出する
        defaultIFS=IFS
        IFS=$'\n'
        entriedClients=(`echo "${enabledClients[*]}" | shuf -n 5`)
        IFS=$defaultIFS
    else
        # fixedClient が指定されているときのみ
        
        # enabledClients から fixedClient を検索し、
        # 存在したら entriedClients に追加して enabledClients から削除する
        lastIndex=$((${#enabledClients[@]} - 1))
        for i in `seq 0 ${lastIndex}`; do
            if [ `basename ${enabledClients[$i]}` = ${fixedClient} ]; then
                entriedClients+=(${enabledClients[$i]})

                # エントリーしたクライアントを除外
                unset enabledClients[$i]
                enabledClients=(${enabledClients[@]})

                break
            fi
        done

        # enabledClients に fixedClient が存在しなかった場合終了
        if [ ${#entriedClients[@]} -eq 0 ]; then
            echo "!!! Client $fixedClient is not available." >&2
            exit 1
        fi

        # クライアント一覧から固定されたクライアント以外の4個のクライアントをランダムに選出する
        defaultIFS=IFS
        IFS=$'\n'
        entriedClients+=(`echo "${enabledClients[*]}" | shuf -n 4`)
        IFS=$defaultIFS
    fi

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
