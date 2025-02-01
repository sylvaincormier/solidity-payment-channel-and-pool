// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import "./LPToken.sol";

contract LiquidityPool is ReentrancyGuard {
    using Math for uint256;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    LPToken public immutable lpToken;
    
    uint256 public reserveA;
    uint256 public reserveB;
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant FEE_NUMERATOR = 3; // 0.3% fee

    // Events
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool isAtoB);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Zero address");
        require(_tokenA != _tokenB, "Same token");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LPToken();
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function addLiquidity(uint256 amountADesired, uint256 amountBDesired) 
        external 
        nonReentrant 
        returns (uint256 amountA, uint256 amountB, uint256 liquidity) 
    {
        // Transfer tokens to this contract
        tokenA.transferFrom(msg.sender, address(this), amountADesired);
        tokenB.transferFrom(msg.sender, address(this), amountBDesired);

        // Calculate amounts
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;

        if (_reserveA == 0 && _reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            lpToken.mint(address(0), MINIMUM_LIQUIDITY); // Lock the minimum liquidity
        } else {
            uint256 amountBOptimal = quote(amountADesired, _reserveA, _reserveB);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, _reserveB, _reserveA);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
            liquidity = Math.min(
                (amountA * lpToken.totalSupply()) / _reserveA,
                (amountB * lpToken.totalSupply()) / _reserveB
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        // Update reserves
        reserveA += amountA;
        reserveB += amountB;

        // Refund excess tokens
        if (amountA < amountADesired) {
            tokenA.transfer(msg.sender, amountADesired - amountA);
        }
        if (amountB < amountBDesired) {
            tokenB.transfer(msg.sender, amountBDesired - amountB);
        }

        lpToken.mint(msg.sender, liquidity);
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) 
        external 
        nonReentrant 
        returns (uint256 amountA, uint256 amountB) 
    {
        // Transfer LP tokens from user
        lpToken.burn(msg.sender, liquidity);

        // Calculate token amounts
        amountA = (liquidity * reserveA) / lpToken.totalSupply();
        amountB = (liquidity * reserveB) / lpToken.totalSupply();

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        // Update reserves
        reserveA -= amountA;
        reserveB -= amountB;

        // Transfer tokens to user
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swap(uint256 amountIn, bool isAtoB) 
        external 
        nonReentrant 
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "Insufficient input amount");
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        require(_reserveA > 0 && _reserveB > 0, "Insufficient liquidity");

        // Calculate amount out
        if (isAtoB) {
            amountOut = getAmountOut(amountIn, _reserveA, _reserveB);
            // Transfer tokens
            tokenA.transferFrom(msg.sender, address(this), amountIn);
            tokenB.transfer(msg.sender, amountOut);
            // Update reserves
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            amountOut = getAmountOut(amountIn, _reserveB, _reserveA);
            // Transfer tokens
            tokenB.transferFrom(msg.sender, address(this), amountIn);
            tokenA.transfer(msg.sender, amountOut);
            // Update reserves
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, amountIn, amountOut, isAtoB);
    }

    function quote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        pure 
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "Insufficient amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        amountOut = (amountIn * reserveOut) / reserveIn;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        pure 
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}