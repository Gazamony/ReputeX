// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./LaunchpadToken.sol";
import "./BondingCurveAMM.sol";

/**
 * @title LaunchpadFactory
 * @dev Factory contract for deploying new tokens and their associated bonding curves
 * Implements ReentrancyGuard for security and manages token lifecycle
 */
contract LaunchpadFactory is Ownable, ReentrancyGuard {
    using Clones for address;

    address public tokenImplementation;
    address public bondingCurveImplementation;
    address public dexRouter;
    uint256 public platformFeePercentage;
    address public treasuryAddress;
    uint256 public marketCapThreshold;
    
    address[] public createdTokens;
    mapping(address => TokenInfo) public tokenInfo;
    mapping(address => address) public tokenBondingCurve;
    mapping(address => bool) public isValidToken;
    
    struct TokenInfo {
        address tokenAddress;
        address bondingCurveAddress;
        address creator;
        string name;
        string symbol;
        uint256 initialSupply;
        uint256 createdAt;
        bool migratedToDEX;
    }
    
    event TokenCreated(
        address indexed tokenAddress,
        address indexed bondingCurveAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply
    );
    event DexRouterUpdated(address newRouter);
    event PlatformFeeUpdated(uint256 newFee);
    event TreasuryUpdated(address newTreasury);
    event ThresholdUpdated(uint256 newThreshold);
    event TokenMigratedToDEX(
        address indexed token,
        address indexed dexRouter,
        uint256 liquidity
    );

    constructor(
        address _tokenImplementation,
        address _bondingCurveImplementation,
        address _dexRouter,
        address _treasuryAddress
    ) {
        require(_tokenImplementation != address(0), "Invalid token implementation");
        require(_bondingCurveImplementation != address(0), "Invalid bonding curve implementation");
        require(_dexRouter != address(0), "Invalid DEX router");
        require(_treasuryAddress != address(0), "Invalid treasury address");
        
        tokenImplementation = _tokenImplementation;
        bondingCurveImplementation = _bondingCurveImplementation;
        dexRouter = _dexRouter;
        treasuryAddress = _treasuryAddress;
        platformFeePercentage = 250;
        marketCapThreshold = 1000000000000000000000;
    }

    /**
     * @dev Create a new token with bonding curve
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply
    ) external nonReentrant returns (address tokenAddress, address bondingCurveAddress) {
        require(initialSupply > 0, "Initial supply must be greater than 0");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");

        tokenAddress = tokenImplementation.clone();
        LaunchpadToken(tokenAddress).initialize(
            name,
            symbol,
            initialSupply,
            maxSupply,
            msg.sender
        );

        bondingCurveAddress = bondingCurveImplementation.clone();
        BondingCurveAMM(bondingCurveAddress).initialize(
            tokenAddress,
            msg.sender,
            address(this)
        );

        LaunchpadToken(tokenAddress).setBondingCurve(bondingCurveAddress);
        tokenBondingCurve[tokenAddress] = bondingCurveAddress;

        TokenInfo memory info = TokenInfo(
            tokenAddress,
            bondingCurveAddress,
            msg.sender,
            name,
            symbol,
            initialSupply,
            block.timestamp,
            false
        );
        tokenInfo[tokenAddress] = info;
        isValidToken[tokenAddress] = true;
        createdTokens.push(tokenAddress);

        emit TokenCreated(
            tokenAddress,
            bondingCurveAddress,
            msg.sender,
            name,
            symbol,
            initialSupply
        );

        return (tokenAddress, bondingCurveAddress);
    }

    /**
     * @dev Migrate token liquidity to DEX once threshold is reached
     */
    function migrateTokenToDEX(address tokenAddress) external nonReentrant onlyValidToken(tokenAddress) {
        TokenInfo storage info = tokenInfo[tokenAddress];
        require(!info.migratedToDEX, "Token already migrated");
        
        address bondingCurveAddress = tokenBondingCurve[tokenAddress];
        BondingCurveAMM bondingCurve = BondingCurveAMM(bondingCurveAddress);
        
        require(
            bondingCurve.getMarketCap() >= marketCapThreshold,
            "Market cap threshold not reached"
        );

        bondingCurve.pauseTrading();

        uint256 iopnBalance = address(bondingCurveAddress).balance;
        uint256 tokenBalance = LaunchpadToken(tokenAddress).balanceOf(bondingCurveAddress);

        bondingCurve.migrateLiquidity(dexRouter, iopnBalance, tokenBalance);

        info.migratedToDEX = true;
        LaunchpadToken(tokenAddress).markLaunched();
        
        emit TokenMigratedToDEX(tokenAddress, dexRouter, iopnBalance);
    }

    /**
     * @dev Update DEX router address
     */
    function setDexRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid DEX router address");
        dexRouter = newRouter;
        emit DexRouterUpdated(newRouter);
    }

    /**
     * @dev Update platform fee percentage
     */
    function setPlatformFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 10000, "Fee too high");
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(newFeePercentage);
    }

    /**
     * @dev Update treasury address
     */
    function setTreasuryAddress(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        treasuryAddress = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @dev Update market cap threshold for DEX migration
     */
    function setMarketCapThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0, "Threshold must be greater than 0");
        marketCapThreshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    /**
     * @dev Get number of created tokens
     */
    function getCreatedTokensCount() external view returns (uint256) {
        return createdTokens.length;
    }

    /**
     * @dev Get paginated list of created tokens
     */
    function getCreatedTokens(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory) {
        require(offset < createdTokens.length, "Offset out of bounds");
        uint256 end = offset + limit;
        if (end > createdTokens.length) {
            end = createdTokens.length;
        }
        
        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = createdTokens[i];
        }
        return result;
    }

    modifier onlyValidToken(address tokenAddress) {
        require(isValidToken[tokenAddress], "Invalid token");
        _;
    }
}
