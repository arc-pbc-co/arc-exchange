// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ProjectPool.sol";

/**
 * @title Marketplace
 * @notice Marketplace contract for purchasing project pool tokens
 * @dev Handles primary sales of pool tokens using USDC
 */
contract Marketplace is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Contracts
    ProjectPool public immutable projectPool;
    IERC20 public immutable usdc;

    // Treasury address for collected funds
    address public treasury;

    // Pool pricing (poolId => price per token in USDC smallest unit)
    mapping(uint256 => uint256) public poolPrices;

    // Pool supply caps
    mapping(uint256 => uint256) public poolMaxSupply;

    // Pool active status
    mapping(uint256 => bool) public poolActive;

    // Events
    event PoolListed(uint256 indexed poolId, uint256 price, uint256 maxSupply);
    event PoolUpdated(uint256 indexed poolId, uint256 price, bool active);
    event Purchase(
        address indexed buyer,
        uint256 indexed poolId,
        uint256 amount,
        uint256 totalPrice
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    constructor(
        address _projectPool,
        address _usdc,
        address _treasury,
        address defaultAdmin
    ) {
        require(_projectPool != address(0), "Marketplace: invalid pool address");
        require(_usdc != address(0), "Marketplace: invalid USDC address");
        require(_treasury != address(0), "Marketplace: invalid treasury address");

        projectPool = ProjectPool(_projectPool);
        usdc = IERC20(_usdc);
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
    }

    /**
     * @notice List a pool for sale
     * @param poolId Pool ID to list
     * @param pricePerToken Price per token in USDC (6 decimals)
     * @param maxSupply Maximum number of tokens available
     */
    function listPool(
        uint256 poolId,
        uint256 pricePerToken,
        uint256 maxSupply
    ) external onlyRole(ADMIN_ROLE) {
        require(pricePerToken > 0, "Marketplace: price must be > 0");
        require(maxSupply > 0, "Marketplace: supply must be > 0");

        poolPrices[poolId] = pricePerToken;
        poolMaxSupply[poolId] = maxSupply;
        poolActive[poolId] = true;

        emit PoolListed(poolId, pricePerToken, maxSupply);
    }

    /**
     * @notice Update pool listing
     * @param poolId Pool ID to update
     * @param pricePerToken New price per token
     * @param active Whether the pool is active for purchase
     */
    function updatePool(
        uint256 poolId,
        uint256 pricePerToken,
        bool active
    ) external onlyRole(ADMIN_ROLE) {
        poolPrices[poolId] = pricePerToken;
        poolActive[poolId] = active;

        emit PoolUpdated(poolId, pricePerToken, active);
    }

    /**
     * @notice Purchase pool tokens
     * @param poolId Pool ID to purchase
     * @param amount Number of tokens to purchase
     */
    function purchase(uint256 poolId, uint256 amount) external nonReentrant {
        require(poolActive[poolId], "Marketplace: pool not active");
        require(amount > 0, "Marketplace: amount must be > 0");
        require(
            projectPool.isVerifiedInvestor(msg.sender),
            "Marketplace: buyer not verified"
        );

        uint256 currentSupply = projectPool.totalSupply(poolId);
        require(
            currentSupply + amount <= poolMaxSupply[poolId],
            "Marketplace: exceeds max supply"
        );

        uint256 totalPrice = poolPrices[poolId] * amount;
        require(totalPrice > 0, "Marketplace: pool not listed");

        // Transfer USDC from buyer to treasury
        usdc.safeTransferFrom(msg.sender, treasury, totalPrice);

        // Mint pool tokens to buyer
        projectPool.mint(msg.sender, poolId, amount);

        emit Purchase(msg.sender, poolId, amount, totalPrice);
    }

    /**
     * @notice Get pool info
     * @param poolId Pool ID
     */
    function getPoolInfo(uint256 poolId)
        external
        view
        returns (
            uint256 price,
            uint256 maxSupply,
            uint256 currentSupply,
            bool active
        )
    {
        return (
            poolPrices[poolId],
            poolMaxSupply[poolId],
            projectPool.totalSupply(poolId),
            poolActive[poolId]
        );
    }

    /**
     * @notice Calculate total price for a purchase
     * @param poolId Pool ID
     * @param amount Number of tokens
     */
    function calculatePrice(uint256 poolId, uint256 amount) external view returns (uint256) {
        return poolPrices[poolId] * amount;
    }

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        require(newTreasury != address(0), "Marketplace: invalid treasury");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
}
