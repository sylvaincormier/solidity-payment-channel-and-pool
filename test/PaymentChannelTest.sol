// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PaymentChannel} from "../src/PaymentChannel.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract PaymentChannelTest is Test {
    using MessageHashUtils for bytes32;
    
    PaymentChannel public channel;
    address public payer;
    uint256 public payerPrivateKey;
    address public payee;
    uint256 public initialDeposit;
    uint256 public duration;

    function setUp() public {
        // Create deterministic addresses using private key 1
        payerPrivateKey = 0x1234; // Use a known private key
        payer = vm.addr(payerPrivateKey);
        payee = makeAddr("payee");
        initialDeposit = 1 ether;
        duration = 1 days;

        // Fund the payer account
        vm.deal(payer, 10 ether);

        // Create channel as payer
        vm.prank(payer);
        channel = new PaymentChannel{value: initialDeposit}(payee, duration);
    }

    function testChannelDeployment() public {
        assertEq(channel.payer(), payer);
        assertEq(channel.payee(), payee);
        assertEq(address(channel).balance, initialDeposit);
        assertEq(channel.depositAmount(), initialDeposit);
        assertTrue(channel.expiresAt() > block.timestamp);
    }

    function testSignatureVerification() public {
        uint256 amount = 0.5 ether;
        
        // Create signature as payer
        bytes32 messageHash = channel.getHash(amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(payerPrivateKey, messageHash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify signature
        assertTrue(channel.verify(amount, signature));
    }

    function testClaimPayment() public {
        uint256 amount = 0.5 ether;
        
        // Create signature as payer
        bytes32 messageHash = channel.getHash(amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(payerPrivateKey, messageHash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);

        // Record balances before claim
        uint256 payeeBalanceBefore = payee.balance;
        uint256 payerBalanceBefore = payer.balance;

        // Claim payment as payee
        vm.prank(payee);
        channel.claim(amount, signature);

        // Verify balances after claim
        assertEq(payee.balance, payeeBalanceBefore + amount);
        assertEq(payer.balance, payerBalanceBefore + (initialDeposit - amount));
        assertTrue(channel.isClosed());
    }

    function testRefund() public {
        // Fast forward past expiration
        vm.warp(block.timestamp + duration + 1);

        // Record balance before refund
        uint256 payerBalanceBefore = payer.balance;

        // Claim refund as payer
        vm.prank(payer);
        channel.refund();

        // Verify balances
        assertEq(payer.balance, payerBalanceBefore + initialDeposit);
        assertTrue(channel.isClosed());
    }

    function testChannelExtension() public {
        uint256 initialExpiration = channel.expiresAt();
        uint256 newDuration = 2 days;

        // Extend channel as payer
        vm.prank(payer);
        channel.extend(newDuration);

        // Verify new expiration
        assertTrue(channel.expiresAt() > initialExpiration);
        assertEq(channel.expiresAt(), block.timestamp + newDuration);
    }

    function test_RevertWhen_ClaimingAfterExpiration() public {
        uint256 amount = 0.5 ether;
        
        // Create signature as payer
        bytes32 messageHash = channel.getHash(amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(payerPrivateKey, messageHash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);

        // Fast forward past expiration
        vm.warp(block.timestamp + duration + 1);

        // Try to claim (should fail)
        vm.expectRevert("Channel has expired");
        vm.prank(payee);
        channel.claim(amount, signature);
    }

    function test_RevertWhen_DoubleSpending() public {
        uint256 amount = 0.5 ether;
        
        // Create signature as payer
        bytes32 messageHash = channel.getHash(amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(payerPrivateKey, messageHash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);

        // First claim
        vm.prank(payee);
        channel.claim(amount, signature);

        // Second claim (should fail)
        vm.expectRevert("Channel is closed");
        vm.prank(payee);
        channel.claim(amount, signature);
    }
}