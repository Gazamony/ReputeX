// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LaunchpadToken.sol";

/**
 * @title BondingCurveAMM
 * @dev Automated Market Maker using a linear bonding curve for token trading
 * Implements buy and sell mechanics with fee structures and slippage protection
 */
contract BondingCurveAMM is ReentrancyGuard, Pausable, Ownable {
    
    LaunchpadToken public token;
    address public factory;
    bool public tradingPaused;
    
    uint256 public scale;
    uint256 public basePrice;
    uint256 public buyFeePercentage;
    uint256 public sellFeePercentage;
    uint256 public feeCollected;
    
    uint256 public totalIOPnRaised;
    uint256 public tokensSold;
    uint256 public maxSlippagePercentage;
    
    event BuyExecuted(
        address indexed buyer,
        uint256 tokenAmount,
        uint256 iopnAmount,
        uint256 feeAmount
    );
    event SellExecuted(
        address indexed seller,
        uint256 tokenAmount,
        uint256 iopnAmount,
        uint256 feeAmount
    );
    event FeesWithdrawn(uint256 amount, address indexed recipient);
    event TradingPaused();
    event TradingResumed();
    event LiquidityMigrated(address indexed dexRouter, uint256 liquidity);

    /**
     * @dev Initialize the bonding curve AMM
     */
    function initialize(
        address _token,
        address _owner,
        address _factory
    ) external {
        require(_token != address(0), "Invalid token address");
        require(_owner != address(0), "Invalid owner address");
        require(_factory != address(0), "Invalid factory address");
        require(address(token) == address(0), "Already initialized");
        
        token = LaunchpadToken(_token);
        factory = _factory;
        scale = 1e18;
        basePrice = 1e12;
        buyFeePercentage = 100;
        sellFeePercentage = 100;
        maxSlippagePercentage = 500;
        tradingPaused = false;
        feeCollected = 0;
        totalIOPnRaised = 0;
        tokensSold = 0;
        
        _transferOwnership(_owner);
    }

    /**
     * @dev Linear bonding curve: price = basePrice + (supply / scale) * k
     */
    function calculatePrice(uint256 tokenSupply) public view returns (uint256) {
        uint256 increment = (tokenSupply / scale) * 1e12;
        return basePrice + increment;
    }

    /**
     * @dev Calculate average price for buying tokens
     */
    function calculateBuyPrice(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Amount must be greater than 0");
        
        uint256 currentSupply = tokensSold;
        uint256 nextSupply = currentSupply + tokenAmount;
        
        uint256 currentPrice = calculatePrice(currentSupply);
        uint256 nextPrice = calculatePrice(nextSupply);
        uint256 averagePrice = (currentPrice + nextPrice) / 2;
        
        return averagePrice * tokenAmount / 1e18;
    }

    /**
     * @dev Calculate average price for selling tokens
     */
    function calculateSellPrice(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(tokenAmount <= tokensSold, "Cannot sell more than available");
        
        uint256 currentSupply = tokensSold;
        uint256 nextSupply = currentSupply - tokenAmount;
        
        uint256 currentPrice = calculatePrice(currentSupply);
        uint256 nextPrice = calculatePrice(nextSupply);
        uint256 averagePrice = (currentPrice + nextPrice) / 2;
        
        return averagePrice * tokenAmount / 1e18;
    }

    /**
     * @dev Buy tokens from the bonding curve with slippage protection
     */
    function buyTokens(
        uint256 tokenAmount,
        uint256 maxPrice
    ) external payable nonReentrant whenNotPaused {
        require(!tradingPaused, "Trading is paused");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(msg.value > 0, "Must send IOPn");
        
        uint256 cost = calculateBuyPrice(tokenAmount);
        uint256 fee = (cost * buyFeePercentage) / 10000;
        uint256 totalCost = cost + fee;
        
        require(msg.value >= totalCost, "Insufficient IOPn sent");
        require(maxPrice == 0 || (cost / tokenAmount) <= maxPrice, "Price exceeds max");
        
        tokensSold += tokenAmount;
        totalIOPnRaised += cost;
        feeCollected += fee;
        
        require(
            token.transfer(msg.sender, tokenAmount),
            "Token transfer failed"
        );
        
        if (msg.value > totalCost) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - totalCost
            }("");
            require(success, "Refund failed");
        }
        
        emit BuyExecuted(msg.sender, tokenAmount, cost, fee);
    }

    /**
     * @dev Sell tokens back to the bonding curve with slippage protection
     */
    function sellTokens(
        uint256 tokenAmount,
        uint256 minReturn
    ) external nonReentrant whenNotPaused {
        require(!tradingPaused, "Trading is paused");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        
        uint256 return_amount = calculateSellPrice(tokenAmount);
        uint256 fee = (return_amount * sellFeePercentage) / 10000;
        uint256 netReturn = return_amount - fee;
        
        require(netReturn >= minReturn, "Return below minimum");
        require(address(this).balance >= netReturn, "Insufficient contract balance");
        
        tokensSold -= tokenAmount;
        feeCollected += fee;
        
        require(
            token.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );
        
        (bool success, ) = payable(msg.sender).call{ value: netReturn }("");
        require(success, "IOPn transfer failed");
        
        emit SellExecuted(msg.sender, tokenAmount, netReturn, fee);
    }

    /**
     * @dev Pause trading on bonding curve
     */
    function pauseTrading() external onlyOwner {
        require(!tradingPaused, "Trading already paused");
        tradingPaused = true;
        emit TradingPaused();
    }

    /**
     * @dev Resume trading on bonding curve
     */
    function resumeTrading() external onlyOwner {
        require(tradingPaused, "Trading not paused");
        tradingPaused = false;
        emit TradingResumed();
    }

    /**
     * @dev Migrate liquidity to DEX once threshold reached
     */
    function migrateLiquidity(
        address dexRouter,
        uint256 iopnAmount,
        uint256 tokenAmount
    ) external nonReentrant onlyOwner {
        require(dexRouter != address(0), "Invalid DEX router");
        require(tradingPaused, "Must pause trading first");
        require(iopnAmount > 0 && tokenAmount > 0, "Invalid amounts");
        
        require(
            token.approve(dexRouter, tokenAmount),
            "Token approval failed"
        );
        
        (bool success, ) = payable(owner()).call{ value: iopnAmount }("");
        require(success, "IOPn transfer failed");
        
        require(
            token.transfer(owner(), tokenAmount),
            "Token transfer failed"
        );
        
        emit LiquidityMigrated(dexRouter, iopnAmount);
    }

    /**
     * @dev Withdraw accumulated fees
     */
    function withdrawFees(address payable recipient) external onlyOwner nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        require(feeCollected > 0, "No fees to withdraw");
        
        uint256 amount = feeCollected;
        feeCollected = 0;
        
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Fee withdrawal failed");
        
        emit FeesWithdrawn(amount, recipient);
    }

    /**
     * @dev Get market cap in IOPn
     */
    function getMarketCap() external view returns (uint256) {
        if (tokensSold == 0) return 0;
        uint256 currentPrice = calculatePrice(tokensSold);
        return (currentPrice * tokensSold) / 1e18;
    }

    /**
     * @dev Get current token price in IOPn
     */
    function getCurrentPrice() external view returns (uint256) {
        return calculatePrice(tokensSold);
    }

    /**
     * @dev Set max slippage percentage
     */
    function setMaxSlippage(uint256 percentage) external onlyOwner {
        require(percentage <= 10000, "Slippage too high");
        maxSlippagePercentage = percentage;
    }

    /**
     * @dev Accept IOPn transfers
     */
    receive() external payable {}
}
