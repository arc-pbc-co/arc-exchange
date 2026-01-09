// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ProjectPool} from "./ProjectPool.sol";

/**
 * @title Marketplace
 * @notice Marketplace contract for purchasing project pool tokens
 * @dev Handles primary sales of pool tokens using USDC
 *
 * Features:
 * - Primary sales with USDC payments
 * - Configurable pricing per pool
 * - Fee collection for platform
 * - Pausable for emergency situations
 * - Purchase limits per transaction
 */
contract Marketplace is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Contracts
    ProjectPool public immutable PROJECT_POOL;
    IERC20 public immutable USDC;

    // Treasury address for collected funds
    address public treasury;

    // Platform fee in basis points (100 = 1%)
    uint256 public platformFeeBps;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% max fee

    // Pool listing data
    struct PoolListing {
        uint256 pricePerToken; // Price in USDC (6 decimals)
        uint256 maxSupply; // Max tokens available
        uint256 minPurchase; // Minimum tokens per purchase
        uint256 maxPurchase; // Maximum tokens per purchase (0 = unlimited)
        uint256 startTime; // Sale start timestamp
        uint256 endTime; // Sale end timestamp (0 = no end)
        bool active;
    }

    // Pool listings
    mapping(uint256 => PoolListing) public listings;

    // Purchase tracking
    mapping(uint256 => mapping(address => uint256)) public userPurchases;
    mapping(uint256 => uint256) public totalPurchased;

    // Events
    event PoolListed(
        uint256 indexed poolId,
        uint256 pricePerToken,
        uint256 maxSupply,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 startTime,
        uint256 endTime
    );
    event ListingUpdated(uint256 indexed poolId, uint256 pricePerToken, bool active);
    event Purchase(
        address indexed buyer,
        uint256 indexed poolId,
        uint256 amount,
        uint256 totalPrice,
        uint256 platformFee
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);

    // Errors
    error InvalidAddress();
    error InvalidPrice();
    error InvalidSupply();
    error InvalidPurchaseLimits();
    error InvalidTimeRange();
    error PoolNotListed(uint256 poolId);
    error PoolNotActive(uint256 poolId);
    error SaleNotStarted(uint256 poolId, uint256 startTime);
    error SaleEnded(uint256 poolId, uint256 endTime);
    error BelowMinPurchase(uint256 poolId, uint256 minPurchase);
    error ExceedsMaxPurchase(uint256 poolId, uint256 maxPurchase);
    error ExceedsMaxSupply(uint256 poolId, uint256 available);
    error BuyerNotVerified(address buyer);
    error FeeTooHigh(uint256 requested, uint256 max);
    error ZeroAmount();

    constructor(
        address _projectPool,
        address _usdc,
        address _treasury,
        address defaultAdmin,
        uint256 _platformFeeBps
    ) {
        if (_projectPool == address(0)) revert InvalidAddress();
        if (_usdc == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (defaultAdmin == address(0)) revert InvalidAddress();
        if (_platformFeeBps > MAX_FEE_BPS) revert FeeTooHigh(_platformFeeBps, MAX_FEE_BPS);

        PROJECT_POOL = ProjectPool(_projectPool);
        USDC = IERC20(_usdc);
        treasury = _treasury;
        platformFeeBps = _platformFeeBps;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, defaultAdmin);
    }

    // ============ Pool Listing Management ============

    /**
     * @notice List a pool for sale
     * @param poolId Pool ID to list
     * @param pricePerToken Price per token in USDC (6 decimals)
     * @param maxSupply Maximum number of tokens available
     * @param minPurchase Minimum tokens per purchase
     * @param maxPurchase Maximum tokens per purchase (0 = unlimited)
     * @param startTime Sale start timestamp (0 = immediate)
     * @param endTime Sale end timestamp (0 = no end)
     */
    function listPool(
        uint256 poolId,
        uint256 pricePerToken,
        uint256 maxSupply,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 startTime,
        uint256 endTime
    ) external onlyRole(ADMIN_ROLE) {
        if (pricePerToken == 0) revert InvalidPrice();
        if (maxSupply == 0) revert InvalidSupply();
        if (maxPurchase != 0 && minPurchase > maxPurchase) revert InvalidPurchaseLimits();
        if (endTime != 0 && endTime <= startTime) revert InvalidTimeRange();

        listings[poolId] = PoolListing({
            pricePerToken: pricePerToken,
            maxSupply: maxSupply,
            minPurchase: minPurchase,
            maxPurchase: maxPurchase,
            startTime: startTime == 0 ? block.timestamp : startTime,
            endTime: endTime,
            active: true
        });

        emit PoolListed(poolId, pricePerToken, maxSupply, minPurchase, maxPurchase, startTime, endTime);
    }

    /**
     * @notice Update pool listing price and status
     * @param poolId Pool ID to update
     * @param pricePerToken New price per token
     * @param active Whether the listing is active
     */
    function updateListing(
        uint256 poolId,
        uint256 pricePerToken,
        bool active
    ) external onlyRole(ADMIN_ROLE) {
        if (!listings[poolId].active && listings[poolId].pricePerToken == 0) {
            revert PoolNotListed(poolId);
        }
        if (pricePerToken == 0) revert InvalidPrice();

        listings[poolId].pricePerToken = pricePerToken;
        listings[poolId].active = active;

        emit ListingUpdated(poolId, pricePerToken, active);
    }

    /**
     * @notice Update purchase limits for a listing
     * @param poolId Pool ID
     * @param minPurchase New minimum purchase
     * @param maxPurchase New maximum purchase
     */
    function updatePurchaseLimits(
        uint256 poolId,
        uint256 minPurchase,
        uint256 maxPurchase
    ) external onlyRole(ADMIN_ROLE) {
        if (!listings[poolId].active && listings[poolId].pricePerToken == 0) {
            revert PoolNotListed(poolId);
        }
        if (maxPurchase != 0 && minPurchase > maxPurchase) revert InvalidPurchaseLimits();

        listings[poolId].minPurchase = minPurchase;
        listings[poolId].maxPurchase = maxPurchase;
    }

    /**
     * @notice Extend or modify sale time
     * @param poolId Pool ID
     * @param endTime New end time (0 = no end)
     */
    function extendSale(uint256 poolId, uint256 endTime) external onlyRole(ADMIN_ROLE) {
        if (!listings[poolId].active && listings[poolId].pricePerToken == 0) {
            revert PoolNotListed(poolId);
        }
        if (endTime != 0 && endTime <= block.timestamp) revert InvalidTimeRange();

        listings[poolId].endTime = endTime;
    }

    // ============ Purchasing ============

    /**
     * @notice Purchase pool tokens
     * @param poolId Pool ID to purchase
     * @param amount Number of tokens to purchase
     */
    function purchase(uint256 poolId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        PoolListing storage listing = listings[poolId];

        // Validate listing
        if (listing.pricePerToken == 0) revert PoolNotListed(poolId);
        if (!listing.active) revert PoolNotActive(poolId);
        if (block.timestamp < listing.startTime) {
            revert SaleNotStarted(poolId, listing.startTime);
        }
        if (listing.endTime != 0 && block.timestamp > listing.endTime) {
            revert SaleEnded(poolId, listing.endTime);
        }

        // Validate purchase limits
        if (amount < listing.minPurchase) {
            revert BelowMinPurchase(poolId, listing.minPurchase);
        }
        if (listing.maxPurchase != 0 && amount > listing.maxPurchase) {
            revert ExceedsMaxPurchase(poolId, listing.maxPurchase);
        }

        // Check supply
        uint256 available = listing.maxSupply - totalPurchased[poolId];
        if (amount > available) {
            revert ExceedsMaxSupply(poolId, available);
        }

        // Verify buyer is whitelisted
        if (!PROJECT_POOL.isVerifiedInvestor(msg.sender)) {
            revert BuyerNotVerified(msg.sender);
        }

        // Calculate prices
        uint256 subtotal = listing.pricePerToken * amount;
        uint256 platformFee = (subtotal * platformFeeBps) / 10000;
        uint256 totalPrice = subtotal + platformFee;

        // Update state before external calls
        totalPurchased[poolId] += amount;
        userPurchases[poolId][msg.sender] += amount;

        // Transfer USDC
        USDC.safeTransferFrom(msg.sender, treasury, totalPrice);

        // Mint pool tokens to buyer
        PROJECT_POOL.mint(msg.sender, poolId, amount);

        emit Purchase(msg.sender, poolId, amount, totalPrice, platformFee);
    }

    /**
     * @notice Batch purchase from multiple pools
     * @param poolIds Array of pool IDs
     * @param amounts Array of amounts to purchase
     */
    function purchaseBatch(
        uint256[] calldata poolIds,
        uint256[] calldata amounts
    ) external nonReentrant whenNotPaused {
        require(poolIds.length == amounts.length, "Marketplace: arrays length mismatch");

        uint256 totalCost;
        uint256 totalFees;

        // Validate all purchases first
        for (uint256 i = 0; i < poolIds.length; i++) {
            if (amounts[i] == 0) revert ZeroAmount();

            PoolListing storage listing = listings[poolIds[i]];

            if (listing.pricePerToken == 0) revert PoolNotListed(poolIds[i]);
            if (!listing.active) revert PoolNotActive(poolIds[i]);
            if (block.timestamp < listing.startTime) {
                revert SaleNotStarted(poolIds[i], listing.startTime);
            }
            if (listing.endTime != 0 && block.timestamp > listing.endTime) {
                revert SaleEnded(poolIds[i], listing.endTime);
            }
            if (amounts[i] < listing.minPurchase) {
                revert BelowMinPurchase(poolIds[i], listing.minPurchase);
            }
            if (listing.maxPurchase != 0 && amounts[i] > listing.maxPurchase) {
                revert ExceedsMaxPurchase(poolIds[i], listing.maxPurchase);
            }

            uint256 available = listing.maxSupply - totalPurchased[poolIds[i]];
            if (amounts[i] > available) {
                revert ExceedsMaxSupply(poolIds[i], available);
            }

            uint256 subtotal = listing.pricePerToken * amounts[i];
            uint256 fee = (subtotal * platformFeeBps) / 10000;
            totalCost += subtotal + fee;
            totalFees += fee;
        }

        // Verify buyer
        if (!PROJECT_POOL.isVerifiedInvestor(msg.sender)) {
            revert BuyerNotVerified(msg.sender);
        }

        // Transfer total USDC
        USDC.safeTransferFrom(msg.sender, treasury, totalCost);

        // Update state and mint tokens
        for (uint256 i = 0; i < poolIds.length; i++) {
            totalPurchased[poolIds[i]] += amounts[i];
            userPurchases[poolIds[i]][msg.sender] += amounts[i];
            PROJECT_POOL.mint(msg.sender, poolIds[i], amounts[i]);

            uint256 subtotal = listings[poolIds[i]].pricePerToken * amounts[i];
            uint256 fee = (subtotal * platformFeeBps) / 10000;
            emit Purchase(msg.sender, poolIds[i], amounts[i], subtotal + fee, fee);
        }
    }

    // ============ Admin Functions ============

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert InvalidAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Update platform fee
     * @param newFeeBps New fee in basis points
     */
    function setPlatformFee(uint256 newFeeBps) external onlyRole(ADMIN_ROLE) {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 oldFee = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(oldFee, newFeeBps);
    }

    /**
     * @notice Pause the marketplace
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the marketplace
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of stuck tokens
     * @param token Token address to withdraw
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert InvalidAddress();
        IERC20(token).safeTransfer(to, amount);
        emit FundsWithdrawn(token, to, amount);
    }

    // ============ View Functions ============

    /**
     * @notice Get listing information
     * @param poolId Pool ID
     */
    function getListing(uint256 poolId)
        external
        view
        returns (
            uint256 pricePerToken,
            uint256 maxSupply,
            uint256 sold,
            uint256 available,
            uint256 minPurchase,
            uint256 maxPurchase,
            uint256 startTime,
            uint256 endTime,
            bool active,
            bool saleActive
        )
    {
        PoolListing storage listing = listings[poolId];
        uint256 _sold = totalPurchased[poolId];

        bool _saleActive = listing.active &&
            block.timestamp >= listing.startTime &&
            (listing.endTime == 0 || block.timestamp <= listing.endTime);

        return (
            listing.pricePerToken,
            listing.maxSupply,
            _sold,
            listing.maxSupply - _sold,
            listing.minPurchase,
            listing.maxPurchase,
            listing.startTime,
            listing.endTime,
            listing.active,
            _saleActive
        );
    }

    /**
     * @notice Calculate total price for a purchase
     * @param poolId Pool ID
     * @param amount Number of tokens
     * @return subtotal Price without fees
     * @return fee Platform fee
     * @return total Total price including fees
     */
    function calculatePrice(uint256 poolId, uint256 amount)
        external
        view
        returns (uint256 subtotal, uint256 fee, uint256 total)
    {
        subtotal = listings[poolId].pricePerToken * amount;
        fee = (subtotal * platformFeeBps) / 10000;
        total = subtotal + fee;
    }

    /**
     * @notice Get user's purchase history for a pool
     * @param poolId Pool ID
     * @param user User address
     */
    function getUserPurchases(uint256 poolId, address user) external view returns (uint256) {
        return userPurchases[poolId][user];
    }

    /**
     * @notice Check if user can purchase from a pool
     * @param poolId Pool ID
     * @param user User address
     * @param amount Amount to purchase
     */
    function canPurchase(
        uint256 poolId,
        address user,
        uint256 amount
    ) external view returns (bool, string memory) {
        PoolListing storage listing = listings[poolId];

        if (listing.pricePerToken == 0) return (false, "Pool not listed");
        if (!listing.active) return (false, "Pool not active");
        if (block.timestamp < listing.startTime) return (false, "Sale not started");
        if (listing.endTime != 0 && block.timestamp > listing.endTime) return (false, "Sale ended");
        if (amount < listing.minPurchase) return (false, "Below minimum purchase");
        if (listing.maxPurchase != 0 && amount > listing.maxPurchase) return (false, "Exceeds maximum purchase");
        if (amount > listing.maxSupply - totalPurchased[poolId]) return (false, "Exceeds available supply");
        if (!PROJECT_POOL.isVerifiedInvestor(user)) return (false, "User not verified");

        return (true, "");
    }
}
