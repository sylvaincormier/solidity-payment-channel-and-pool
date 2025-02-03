// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

contract PaymentChannel is ReentrancyGuard {
    using ECDSA for bytes32;

    address public payer;
    address public payee;
    uint256 public expiresAt;
    uint256 public depositAmount;
    bool public isClosed;

    constructor(address _payee, uint256 _duration) payable {
        require(_payee != address(0), "Invalid payee address");
        require(msg.value > 0, "Deposit required");
        require(_duration > 0, "Duration must be greater than 0");

        payer = msg.sender;
        payee = _payee;
        depositAmount = msg.value;
        expiresAt = block.timestamp + _duration;
    }

    function getHash(uint256 amount) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), amount));
    }

    function verify(uint256 amount, bytes memory signature) public view returns (bool) {
        bytes32 messageHash = getHash(amount);
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        return ECDSA.recover(ethSignedMessageHash, signature) == payer;
    }

    function claim(uint256 amount, bytes memory signature) external nonReentrant {
        require(!isClosed, "Channel is closed");
        require(msg.sender == payee, "Only payee can claim");
        require(block.timestamp < expiresAt, "Channel has expired");
        require(amount <= depositAmount, "Amount exceeds deposit");
        require(verify(amount, signature), "Invalid signature");

        isClosed = true;

        // Transfer amount to payee
        (bool success,) = payee.call{value: amount}("");
        require(success, "Transfer failed");

        // Return remaining funds to payer
        if (amount < depositAmount) {
            (success,) = payer.call{value: depositAmount - amount}("");
            require(success, "Refund failed");
        }
    }

    function refund() external nonReentrant {
        require(!isClosed, "Channel is closed");
        require(msg.sender == payer, "Only payer can refund");
        require(block.timestamp >= expiresAt, "Channel hasn't expired");

        isClosed = true;
        (bool success,) = payer.call{value: depositAmount}("");
        require(success, "Refund failed");
    }

    function extend(uint256 newDuration) external {
        require(msg.sender == payer, "Only payer can extend");
        require(!isClosed, "Channel is closed");
        require(newDuration > 0, "Duration must be greater than 0");
        require(block.timestamp + newDuration > expiresAt, "New expiration must be later than current");

        expiresAt = block.timestamp + newDuration;
    }
}
