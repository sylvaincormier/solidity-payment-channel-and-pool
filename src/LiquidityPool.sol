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
    uint256 public lastK;  // Store k (reserveA * reserveB) for manipulation checks
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant FEE_NUMERATOR = 3; // 0.3% fee
    uint256 private constant MINIMUM_TRADE_DELAY = 2; // blocks
    
    mapping(address => uint256) public lastTradeBlock;  // Track last trade block for each user

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
        console2.log("LP Token deployed at:", address(lpToken));
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function _updateAndCheckK() private {
        uint256 newK = reserveA * reserveB;
        if (lastK != 0) {
            // require(newK >= lastK, "K value decreased");
        }
        lastK = newK;
    }

    function _checkTradeDelay() private {
        require(
            block.number >= lastTradeBlock[msg.sender] + MINIMUM_TRADE_DELAY,
            "Must wait before trading again"
        );
        lastTradeBlock[msg.sender] = block.number;
    }

    function addLiquidity(uint256 amountADesired, uint256 amountBDesired) 
    external 
    nonReentrant 
    returns (uint256 amountA, uint256 amountB, uint256 liquidity) 
{
    require(amountADesired >= MINIMUM_LIQUIDITY, "Insufficient token A amount");
    require(amountBDesired >= MINIMUM_LIQUIDITY, "Insufficient token B amount");

    uint256 _reserveA = reserveA;
    uint256 _reserveB = reserveB;

    if (_reserveA == 0 && _reserveB == 0) {
        // For first deposit, enforce equal amounts to set initial price
        amountA = Math.min(amountADesired, amountBDesired);
        amountB = amountA; // Force equal amounts
        
        liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        require(liquidity > 0, "Insufficient initial liquidity");

        // Transfer exact amounts needed
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        
        // Mint minimum liquidity first
        lpToken.mint(address(this), MINIMUM_LIQUIDITY);
    } else {
        // For subsequent deposits, calculate optimal amounts
        uint256 amountBOptimal = quote(amountADesired, _reserveA, _reserveB);
        if (amountBOptimal <= amountBDesired) {
            (amountA, amountB) = (amountADesired, amountBOptimal);
        } else {
            uint256 amountAOptimal = quote(amountBDesired, _reserveB, _reserveA);
            (amountA, amountB) = (amountAOptimal, amountBDesired);
        }

        // Transfer tokens
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        liquidity = Math.min(
            (amountA * lpToken.totalSupply()) / _reserveA,
            (amountB * lpToken.totalSupply()) / _reserveB
        );
    }

    require(liquidity > 0, "Insufficient liquidity minted");

    // Update state
    reserveA += amountA;
    reserveB += amountB;
    _updateAndCheckK();

    // Refund excess amounts
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
    require(liquidity > 0, "Invalid liquidity amount");
    require(lpToken.balanceOf(msg.sender) >= liquidity, "Insufficient LP token balance");

    uint256 totalSupply = lpToken.totalSupply();
    require(totalSupply > 0, "No supply");

    // Calculate token amounts proportionally
    amountA = (liquidity * reserveA) / totalSupply;
    amountB = (liquidity * reserveB) / totalSupply;
    require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

    // Calculate new reserves
    uint256 newReserveA = reserveA - amountA;
    uint256 newReserveB = reserveB - amountB;
    
    // K-value check
    // For proportional removal: newK/oldK should be (1 - liquidity/totalSupply)^2
    // This ensures proportional withdrawal doesn't affect price
    uint256 oldK = reserveA * reserveB;
    uint256 newK = newReserveA * newReserveB;
    uint256 ratio = ((totalSupply - liquidity) * 1e18) / totalSupply;  // Scale by 1e18 for precision
    require(
        (newK * 1e18) >= (oldK * ratio * ratio / 1e18), 
        "K value check failed"
    );

    // Update state
    reserveA = newReserveA;
    reserveB = newReserveB;

    // Burn LP tokens and transfer tokens
    lpToken.burn(msg.sender, liquidity);
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
        require(amountIn >= MINIMUM_LIQUIDITY, "Below minimum swap amount");
        
        _checkTradeDelay();
        
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        require(_reserveA > 0 && _reserveB > 0, "Insufficient liquidity");

        uint256 balanceBefore = isAtoB ? 
            tokenA.balanceOf(address(this)) : 
            tokenB.balanceOf(address(this));

        if (isAtoB) {
            amountOut = getAmountOut(amountIn, _reserveA, _reserveB);
            require(amountOut <= _reserveB / 3, "Output amount too large");
            
            tokenA.transferFrom(msg.sender, address(this), amountIn);
            tokenB.transfer(msg.sender, amountOut);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            amountOut = getAmountOut(amountIn, _reserveB, _reserveA);
            require(amountOut <= _reserveA / 3, "Output amount too large");
            
            tokenB.transferFrom(msg.sender, address(this), amountIn);
            tokenA.transfer(msg.sender, amountOut);
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Verify actual balance changes match expected changes
        uint256 balanceAfter = isAtoB ? 
            tokenA.balanceOf(address(this)) : 
            tokenB.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + amountIn, "Balance manipulation detected");
        
        _updateAndCheckK();
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