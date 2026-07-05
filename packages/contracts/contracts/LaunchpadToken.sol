// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title LaunchpadToken
 * @dev ERC20 token created by the LaunchpadFactory
 * Supports specialized features like quantum-resistant structures and custom logic
 */
contract LaunchpadToken is ERC20, Ownable, Pausable {
    /// @dev Tracks if this token has been launched on DEX
    bool public isLaunched;
    
    /// @dev Reference to the bonding curve contract that manages this token
    address public bondingCurve;
    
    /// @dev Maximum supply cap (can be set during deployment)
    uint256 public maxSupply;
    
    /// @dev Burn mechanism for deflationary features
    bool public burningEnabled;
    uint256 public burnPercentage;
    
    event LaunchpadTokenCreated(
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply
    );
    event BondingCurveSet(address indexed bondingCurve);
    event TokenLaunched(address indexed dexRouter, uint256 liquidity);
    event BurningEnabled(uint256 burnPercentage);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply_,
        address creator
    ) ERC20(name, symbol) {
        require(creator != address(0), "Invalid creator address");
        require(
            maxSupply_ == 0 || initialSupply <= maxSupply_,
            "Initial supply exceeds max supply"
        );
        
        maxSupply = maxSupply_;
        isLaunched = false;
        burningEnabled = false;
        burnPercentage = 0;
        
        _mint(creator, initialSupply);
        _transferOwnership(creator);
        
        emit LaunchpadTokenCreated(creator, name, symbol, initialSupply);
    }

    function setBondingCurve(address bondingCurveAddr) external onlyOwner {
        require(bondingCurveAddr != address(0), "Invalid bonding curve address");
        bondingCurve = bondingCurveAddr;
        emit BondingCurveSet(bondingCurveAddr);
    }

    function enableBurning(uint256 percentage) external onlyOwner {
        require(percentage <= 10000, "Burn percentage too high");
        burningEnabled = true;
        burnPercentage = percentage;
        emit BurningEnabled(percentage);
    }

    function disableBurning() external onlyOwner {
        burningEnabled = false;
    }

    function markLaunched() external onlyOwner {
        require(!isLaunched, "Token already launched");
        isLaunched = true;
        emit TokenLaunched(msg.sender, 0);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        if (burningEnabled && from != address(0) && to != address(0)) {
            uint256 burnAmount = (amount * burnPercentage) / 10000;
            if (burnAmount > 0) {
                super._update(from, address(0), burnAmount);
                amount -= burnAmount;
            }
        }
        super._update(from, to, amount);
    }

    function mint(address to, uint256 amount) external {
        require(
            msg.sender == bondingCurve || msg.sender == owner(),
            "Only bonding curve or owner can mint"
        );
        require(
            maxSupply == 0 || totalSupply() + amount <= maxSupply,
            "Exceeds max supply"
        );
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
