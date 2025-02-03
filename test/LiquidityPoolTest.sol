// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {TestTokenA, TestTokenB} from "../src/TestTokens.sol";
import {LPToken} from "../src/LPToken.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public pool;
    TestTokenA public tokenA;
    TestTokenB public tokenB;

    address public alice;
    address public bob;
    address public carol;
    uint256 public constant INITIAL_MINT_AMOUNT = 1000000 * 10 ** 18;
    uint256 public constant INITIAL_LIQUIDITY = 100 * 10 ** 18;

    function setUp() public {
        // Create test addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Deploy tokens and pool
        tokenA = new TestTokenA();
        tokenB = new TestTokenB();
        pool = new LiquidityPool(address(tokenA), address(tokenB));

        // Setup Alice
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_MINT_AMOUNT);
        tokenB.mint(alice, INITIAL_MINT_AMOUNT);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        // Setup Bob
        vm.startPrank(bob);
        tokenA.mint(bob, INITIAL_MINT_AMOUNT);
        tokenB.mint(bob, INITIAL_MINT_AMOUNT);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        // Setup Carol
        vm.startPrank(carol);
        tokenA.mint(carol, INITIAL_MINT_AMOUNT);
        tokenB.mint(carol, INITIAL_MINT_AMOUNT);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    // Basic Functionality Tests
    function testInitialLiquidity() public {
        vm.prank(alice);
        (uint256 amountA, uint256 amountB, uint256 lpTokens) = pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        assertEq(amountA, INITIAL_LIQUIDITY, "Incorrect token A amount");
        assertEq(amountB, INITIAL_LIQUIDITY, "Incorrect token B amount");
        assertGt(lpTokens, 0, "No LP tokens minted");

        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        assertEq(reserveA, INITIAL_LIQUIDITY, "Incorrect reserve A");
        assertEq(reserveB, INITIAL_LIQUIDITY, "Incorrect reserve B");
    }

    function testMultipleDeposits() public {
        // First deposit by Alice
        vm.prank(alice);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        // Second deposit by Bob
        vm.prank(bob);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        assertEq(reserveA, INITIAL_LIQUIDITY * 2, "Incorrect reserve A after multiple deposits");
        assertEq(reserveB, INITIAL_LIQUIDITY * 2, "Incorrect reserve B after multiple deposits");
    }

    function testSwap() public {
        // Add initial liquidity
        vm.startPrank(alice);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.stopPrank();

        uint256 swapAmount = 10 * 10 ** 18; // 10 tokens

        // Record balances before swap
        uint256 bobTokenABefore = tokenA.balanceOf(bob);
        uint256 bobTokenBBefore = tokenB.balanceOf(bob);

        // Wait required blocks and perform swap
        vm.roll(block.number + 3);
        vm.prank(bob);
        uint256 amountOut = pool.swap(swapAmount, true); // true for A to B

        // Verify balances
        assertEq(tokenA.balanceOf(bob), bobTokenABefore - swapAmount, "Incorrect token A balance after swap");
        assertEq(tokenB.balanceOf(bob), bobTokenBBefore + amountOut, "Incorrect token B balance after swap");
    }

    function testRemoveLiquidity() public {
        // Add liquidity
        vm.startPrank(alice);
        (,, uint256 lpTokens) = pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        // Wait and remove half liquidity
        vm.roll(block.number + 3);
        uint256 burnAmount = lpTokens / 2;

        // Record balances before removal
        uint256 aliceTokenABefore = tokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = tokenB.balanceOf(alice);

        // Remove liquidity
        (uint256 amountA, uint256 amountB) = pool.removeLiquidity(burnAmount);

        // Verify balances
        assertEq(tokenA.balanceOf(alice), aliceTokenABefore + amountA, "Incorrect token A balance after removal");
        assertEq(tokenB.balanceOf(alice), aliceTokenBBefore + amountB, "Incorrect token B balance after removal");
        vm.stopPrank();
    }

    // Security Tests
    function test_RevertWhen_FlashLoanAttack() public {
        // Add initial liquidity
        vm.startPrank(alice);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.startPrank(bob);
        // First swap
        vm.roll(block.number + 3);
        pool.swap(10 * 10 ** 18, true);

        // Try immediate second swap
        vm.expectRevert("Must wait before trading again");
        pool.swap(10 * 10 ** 18, false);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapAmountTooLarge() public {
        // Add initial liquidity
        vm.startPrank(alice);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.roll(block.number + 3);

        vm.startPrank(bob);
        vm.expectRevert("Output amount too large");
        pool.swap(INITIAL_LIQUIDITY, true); // Try to swap entire pool
        vm.stopPrank();
    }

    function testK_ValueProtection() public {
        // Add initial liquidity
        vm.startPrank(alice);
        pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.stopPrank();

        uint256 initialK = INITIAL_LIQUIDITY * INITIAL_LIQUIDITY;

        // Perform swap
        vm.roll(block.number + 3);
        vm.prank(bob);
        pool.swap(10 * 10 ** 18, true);

        // Verify K hasn't decreased
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        uint256 newK = reserveA * reserveB;
        assertGe(newK, initialK, "K value should not decrease");
    }

    // Edge Cases and Additional Tests
    function test_RevertWhen_AddingInsufficientLiquidity() public {
        uint256 tinyAmount = 100;
        vm.prank(alice);
        vm.expectRevert("Insufficient token A amount");
        pool.addLiquidity(tinyAmount, INITIAL_LIQUIDITY);
    }

    function testAsymmetricLiquidity() public {
        vm.startPrank(alice);

        // Try to add asymmetric liquidity (2:1 ratio)
        uint256 amountA = INITIAL_LIQUIDITY;
        uint256 amountB = INITIAL_LIQUIDITY * 2;

        console2.log("Adding asymmetric liquidity - A:", amountA, "B:", amountB);
        (uint256 actualA, uint256 actualB,) = pool.addLiquidity(amountA, amountB);
        console2.log("Actual amounts added - A:", actualA, "B:", actualB);

        // Should use the smaller amount (amountA) for both tokens
        assertEq(actualA, amountA, "Incorrect token A amount");
        assertEq(actualB, amountA, "Token B amount should match A for first deposit");
        vm.stopPrank();
    }

    function testMinimumLiquidity() public {
        vm.prank(alice);
        (,, uint256 lpTokens) = pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        assertGt(lpTokens, pool.MINIMUM_LIQUIDITY(), "LP tokens should be greater than minimum liquidity");
    }

    function test_RevertWhen_RemovingTooMuchLiquidity() public {
        vm.startPrank(alice);

        // Add initial liquidity
        (,, uint256 lpTokens) = pool.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        // Wait required blocks
        vm.roll(block.number + 3);

        // Try to remove more than available
        uint256 tooMuchLiquidity = lpTokens + 1;
        vm.expectRevert("Insufficient LP token balance");
        pool.removeLiquidity(tooMuchLiquidity);

        vm.stopPrank();
    }
}
