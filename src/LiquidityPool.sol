// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import "./LPToken.sol";

contract LiquidityPool is ReentrancyGuard {
    using Math for uint256;

    struct PoolState {
        uint256 reserveA;
        uint256 reserveB;
        uint256 lastK;
    }

    // Immutable state
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    LPToken public immutable lpToken;
    
    // Constants
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant FEE_NUMERATOR = 3; // 0.3% fee
    uint256 private constant MINIMUM_TRADE_DELAY = 2; // blocks
    
    // Private state
    PoolState private _poolState;
    
    // Last trade tracking
    mapping(address => uint256) private _lastTradeBlock;

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

    // View functions
    function getReserves() public view returns (uint256, uint256) {
        return (_poolState.reserveA, _poolState.reserveB);
    }

    function getLastTradeBlock(address trader) public view returns (uint256) {
        return _lastTradeBlock[trader];
    }

    // Private functions
    function _updateAndCheckK() private {
        uint256 newK = _poolState.reserveA * _poolState.reserveB;
        if (_poolState.lastK != 0) {
            require(newK >= _poolState.lastK, "K value decreased");
        }
        _poolState.lastK = newK;
    }

    function _checkTradeDelay() private {
        require(
            block.number >= _lastTradeBlock[msg.sender] + MINIMUM_TRADE_DELAY,
            "Must wait before trading again"
        );
        _lastTradeBlock[msg.sender] = block.number;
    }

    function addLiquidity(uint256 amountADesired, uint256 amountBDesired) 
        external 
        nonReentrant 
        returns (uint256 amountA, uint256 amountB, uint256 liquidity) 
    {
        require(amountADesired >= MINIMUM_LIQUIDITY, "Insufficient token A amount");
        require(amountBDesired >= MINIMUM_LIQUIDITY, "Insufficient token B amount");

        uint256 _reserveA = _poolState.reserveA;
        uint256 _reserveB = _poolState.reserveB;

        if (_reserveA == 0 && _reserveB == 0) {
            amountA = Math.min(amountADesired, amountBDesired);
            amountB = amountA;
            
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Insufficient initial liquidity");

            tokenA.transferFrom(msg.sender, address(this), amountA);
            tokenB.transferFrom(msg.sender, address(this), amountB);
            
            lpToken.mint(address(this), MINIMUM_LIQUIDITY);
        } else {
            uint256 amountBOptimal = quote(amountADesired, _reserveA, _reserveB);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, _reserveB, _reserveA);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }

            tokenA.transferFrom(msg.sender, address(this), amountA);
            tokenB.transferFrom(msg.sender, address(this), amountB);

            liquidity = Math.min(
                (amountA * lpToken.totalSupply()) / _reserveA,
                (amountB * lpToken.totalSupply()) / _reserveB
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        _poolState.reserveA += amountA;
        _poolState.reserveB += amountB;
        _updateAndCheckK();

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

        amountA = (liquidity * _poolState.reserveA) / totalSupply;
        amountB = (liquidity * _poolState.reserveB) / totalSupply;
        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        uint256 newReserveA = _poolState.reserveA - amountA;
        uint256 newReserveB = _poolState.reserveB - amountB;
        
        uint256 oldK = _poolState.reserveA * _poolState.reserveB;
        uint256 newK = newReserveA * newReserveB;
        uint256 ratio = ((totalSupply - liquidity) * 1e18) / totalSupply;
        require(
            (newK * 1e18) >= (oldK * ratio * ratio / 1e18), 
            "K value check failed"
        );

        _poolState.reserveA = newReserveA;
        _poolState.reserveB = newReserveB;

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
            _poolState.reserveA += amountIn;
            _poolState.reserveB -= amountOut;
        } else {
            amountOut = getAmountOut(amountIn, _reserveB, _reserveA);
            require(amountOut <= _reserveA / 3, "Output amount too large");
            
            tokenB.transferFrom(msg.sender, address(this), amountIn);
            tokenA.transfer(msg.sender, amountOut);
            _poolState.reserveB += amountIn;
            _poolState.reserveA -= amountOut;
        }

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
        view 
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