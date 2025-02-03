// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TestTokenA is ERC20 {
    constructor() ERC20("Test Token A", "TTA") {}

    function mint(address account, uint256 amount) public {
        require(account != address(0), "TestToken: mint to the zero address");
        _mint(account, amount);
    }
}

contract TestTokenB is ERC20 {
    constructor() ERC20("Test Token B", "TTB") {}

    function mint(address account, uint256 amount) public {
        require(account != address(0), "TestToken: mint to the zero address");
        _mint(account, amount);
    }
}
