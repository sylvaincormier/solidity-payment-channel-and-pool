// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "forge-std/console2.sol";

contract LPToken is ERC20 {
    address public immutable pool;

    constructor() ERC20("Liquidity Pool Token", "LPT") {
        pool = msg.sender;
        console2.log("LP Token constructor - Pool address set to:", msg.sender);
    }

    function mint(address account, uint256 amount) external {
        console2.log("LP Token mint called by:", msg.sender);
        console2.log("Minting to address:", account);
        console2.log("Amount:", amount);
        
        require(msg.sender == pool, "Only pool can mint");
        require(account != address(0), "Cannot mint to zero address");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        require(msg.sender == pool, "Only pool can burn");
        require(account != address(0), "Cannot burn from zero address");
        _burn(account, amount);
    }
}