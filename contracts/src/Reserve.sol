// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ProjectPool} from "./ProjectPool.sol";

/**
 * @title Reserve
 * @notice Reserve contract for managing escrow and dividend distributions
 * @dev Handles:
 *      - Holding funds raised from pool sales
 *      - Distributing dividends/coupons to pool token holders
 *      - Managing pool-specific escrow accounts
 *
 * Features:
 * - Per-pool fund tracking
 * - Dividend distribution based on token holdings
 * - Claimable dividend system
 * - Emergency withdrawal capabilities
 */
contract Reserve is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Contracts
    ProjectPool public immutable PROJECT_POOL;
    IERC20 public immutable USDC;

    // Distribution data
    struct Distribution {
        uint256 poolId;
        uint256 totalAmount; // Total USDC to distribute
        uint256 totalSupplyAtSnapshot; // Token supply when distribution created
        uint256 amountPerToken; // USDC per token (scaled by 1e18)
        uint256 claimedAmount; // Total claimed so far
        uint256 createdAt;
        uint256 expiresAt; // Expiration for unclaimed funds (0 = no expiry)
        bool active;
    }

    // Pool escrow balances
    mapping(uint256 => uint256) public poolBalances;

    // Distributions
    uint256 public nextDistributionId;
    mapping(uint256 => Distribution) public distributions;

    // User claims: distributionId => user => claimed
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    // User claimable amounts (for view functions)
    mapping(uint256 => mapping(address => uint256)) public claimableAmounts;

    // Total reserves
    uint256 public totalReserves;

    // Events
    event FundsDeposited(uint256 indexed poolId, uint256 amount, address indexed from);
    event FundsWithdrawn(uint256 indexed poolId, uint256 amount, address indexed to);
    event DistributionCreated(
        uint256 indexed distributionId,
        uint256 indexed poolId,
        uint256 totalAmount,
        uint256 amountPerToken
    );
    event DistributionClaimed(
        uint256 indexed distributionId,
        address indexed user,
        uint256 amount
    );
    event DistributionCancelled(uint256 indexed distributionId);
    event ExpiredFundsReclaimed(uint256 indexed distributionId, uint256 amount);

    // Errors
    error InvalidAddress();
    error InvalidAmount();
    error InvalidPoolId();
    error InsufficientBalance(uint256 poolId, uint256 requested, uint256 available);
    error DistributionNotFound(uint256 distributionId);
    error DistributionNotActive(uint256 distributionId);
    error DistributionExpired(uint256 distributionId);
    error AlreadyClaimed(uint256 distributionId, address user);
    error NothingToClaim(uint256 distributionId, address user);
    error NotExpired(uint256 distributionId);
    error ZeroSupply(uint256 poolId);

    constructor(
        address _projectPool,
        address _usdc,
        address defaultAdmin
    ) {
        if (_projectPool == address(0)) revert InvalidAddress();
        if (_usdc == address(0)) revert InvalidAddress();
        if (defaultAdmin == address(0)) revert InvalidAddress();

        PROJECT_POOL = ProjectPool(_projectPool);
        USDC = IERC20(_usdc);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _grantRole(DISTRIBUTOR_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, defaultAdmin);
    }

    // ============ Fund Management ============

    /**
     * @notice Deposit funds into a pool's escrow
     * @param poolId Pool ID
     * @param amount Amount of USDC to deposit
     */
    function deposit(uint256 poolId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        USDC.safeTransferFrom(msg.sender, address(this), amount);

        poolBalances[poolId] += amount;
        totalReserves += amount;

        emit FundsDeposited(poolId, amount, msg.sender);
    }

    /**
     * @notice Withdraw funds from a pool's escrow (admin only)
     * @param poolId Pool ID
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function withdraw(
        uint256 poolId,
        uint256 amount,
        address to
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (poolBalances[poolId] < amount) {
            revert InsufficientBalance(poolId, amount, poolBalances[poolId]);
        }

        poolBalances[poolId] -= amount;
        totalReserves -= amount;

        USDC.safeTransfer(to, amount);

        emit FundsWithdrawn(poolId, amount, to);
    }

    // ============ Distribution Management ============

    /**
     * @notice Create a new distribution for a pool
     * @param poolId Pool ID to distribute to
     * @param amount Total USDC amount to distribute
     * @param expiresAt Timestamp when unclaimed funds can be reclaimed (0 = no expiry)
     * @return distributionId The ID of the created distribution
     */
    function createDistribution(
        uint256 poolId,
        uint256 amount,
        uint256 expiresAt
    ) external onlyRole(DISTRIBUTOR_ROLE) nonReentrant returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        uint256 supply = PROJECT_POOL.totalSupply(poolId);
        if (supply == 0) revert ZeroSupply(poolId);

        // Transfer funds to this contract
        USDC.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate amount per token (scaled by 1e18 for precision)
        uint256 amountPerToken = (amount * 1e18) / supply;

        uint256 distributionId = nextDistributionId++;

        distributions[distributionId] = Distribution({
            poolId: poolId,
            totalAmount: amount,
            totalSupplyAtSnapshot: supply,
            amountPerToken: amountPerToken,
            claimedAmount: 0,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            active: true
        });

        emit DistributionCreated(distributionId, poolId, amount, amountPerToken);

        return distributionId;
    }

    /**
     * @notice Create distribution using pool's existing escrow balance
     * @param poolId Pool ID
     * @param amount Amount from pool balance to distribute
     * @param expiresAt Expiration timestamp
     */
    function createDistributionFromBalance(
        uint256 poolId,
        uint256 amount,
        uint256 expiresAt
    ) external onlyRole(DISTRIBUTOR_ROLE) nonReentrant returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        if (poolBalances[poolId] < amount) {
            revert InsufficientBalance(poolId, amount, poolBalances[poolId]);
        }

        uint256 supply = PROJECT_POOL.totalSupply(poolId);
        if (supply == 0) revert ZeroSupply(poolId);

        // Deduct from pool balance
        poolBalances[poolId] -= amount;
        totalReserves -= amount;

        // Calculate amount per token
        uint256 amountPerToken = (amount * 1e18) / supply;

        uint256 distributionId = nextDistributionId++;

        distributions[distributionId] = Distribution({
            poolId: poolId,
            totalAmount: amount,
            totalSupplyAtSnapshot: supply,
            amountPerToken: amountPerToken,
            claimedAmount: 0,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            active: true
        });

        emit DistributionCreated(distributionId, poolId, amount, amountPerToken);

        return distributionId;
    }

    /**
     * @notice Claim distribution for a specific distribution ID
     * @param distributionId Distribution ID to claim
     */
    function claim(uint256 distributionId) external nonReentrant whenNotPaused {
        Distribution storage dist = distributions[distributionId];

        if (!dist.active) revert DistributionNotActive(distributionId);
        if (dist.expiresAt != 0 && block.timestamp > dist.expiresAt) {
            revert DistributionExpired(distributionId);
        }
        if (hasClaimed[distributionId][msg.sender]) {
            revert AlreadyClaimed(distributionId, msg.sender);
        }

        // Get user's balance at snapshot (current balance as proxy - in production use snapshots)
        uint256 userBalance = PROJECT_POOL.balanceOf(msg.sender, dist.poolId);
        if (userBalance == 0) revert NothingToClaim(distributionId, msg.sender);

        // Calculate claimable amount
        uint256 claimAmount = (userBalance * dist.amountPerToken) / 1e18;
        if (claimAmount == 0) revert NothingToClaim(distributionId, msg.sender);

        // Mark as claimed
        hasClaimed[distributionId][msg.sender] = true;
        dist.claimedAmount += claimAmount;

        // Transfer funds
        USDC.safeTransfer(msg.sender, claimAmount);

        emit DistributionClaimed(distributionId, msg.sender, claimAmount);
    }

    /**
     * @notice Batch claim multiple distributions
     * @param distributionIds Array of distribution IDs to claim
     */
    function claimBatch(uint256[] calldata distributionIds) external nonReentrant whenNotPaused {
        uint256 totalClaim;

        for (uint256 i = 0; i < distributionIds.length; i++) {
            uint256 distId = distributionIds[i];
            Distribution storage dist = distributions[distId];

            if (!dist.active) continue;
            if (dist.expiresAt != 0 && block.timestamp > dist.expiresAt) continue;
            if (hasClaimed[distId][msg.sender]) continue;

            uint256 userBalance = PROJECT_POOL.balanceOf(msg.sender, dist.poolId);
            if (userBalance == 0) continue;

            uint256 claimAmount = (userBalance * dist.amountPerToken) / 1e18;
            if (claimAmount == 0) continue;

            hasClaimed[distId][msg.sender] = true;
            dist.claimedAmount += claimAmount;
            totalClaim += claimAmount;

            emit DistributionClaimed(distId, msg.sender, claimAmount);
        }

        if (totalClaim > 0) {
            USDC.safeTransfer(msg.sender, totalClaim);
        }
    }

    /**
     * @notice Cancel a distribution (returns funds to admin)
     * @param distributionId Distribution ID to cancel
     */
    function cancelDistribution(uint256 distributionId) external onlyRole(ADMIN_ROLE) {
        Distribution storage dist = distributions[distributionId];

        if (!dist.active) revert DistributionNotActive(distributionId);

        uint256 remainingAmount = dist.totalAmount - dist.claimedAmount;
        dist.active = false;

        if (remainingAmount > 0) {
            USDC.safeTransfer(msg.sender, remainingAmount);
        }

        emit DistributionCancelled(distributionId);
    }

    /**
     * @notice Reclaim expired unclaimed funds
     * @param distributionId Distribution ID
     */
    function reclaimExpired(uint256 distributionId) external onlyRole(ADMIN_ROLE) {
        Distribution storage dist = distributions[distributionId];

        if (!dist.active) revert DistributionNotActive(distributionId);
        if (dist.expiresAt == 0 || block.timestamp <= dist.expiresAt) {
            revert NotExpired(distributionId);
        }

        uint256 remainingAmount = dist.totalAmount - dist.claimedAmount;
        dist.active = false;

        if (remainingAmount > 0) {
            USDC.safeTransfer(msg.sender, remainingAmount);
        }

        emit ExpiredFundsReclaimed(distributionId, remainingAmount);
    }

    // ============ Admin Functions ============

    /**
     * @notice Pause the reserve
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the reserve
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of any token
     * @param token Token address
     * @param to Recipient
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert InvalidAddress();
        IERC20(token).safeTransfer(to, amount);
    }

    // ============ View Functions ============

    /**
     * @notice Get distribution details
     * @param distributionId Distribution ID
     */
    function getDistribution(uint256 distributionId)
        external
        view
        returns (
            uint256 poolId,
            uint256 totalAmount,
            uint256 totalSupplyAtSnapshot,
            uint256 amountPerToken,
            uint256 claimedAmount,
            uint256 remainingAmount,
            uint256 createdAt,
            uint256 expiresAt,
            bool active
        )
    {
        Distribution storage dist = distributions[distributionId];
        return (
            dist.poolId,
            dist.totalAmount,
            dist.totalSupplyAtSnapshot,
            dist.amountPerToken,
            dist.claimedAmount,
            dist.totalAmount - dist.claimedAmount,
            dist.createdAt,
            dist.expiresAt,
            dist.active
        );
    }

    /**
     * @notice Calculate claimable amount for a user
     * @param distributionId Distribution ID
     * @param user User address
     */
    function getClaimableAmount(uint256 distributionId, address user)
        external
        view
        returns (uint256)
    {
        Distribution storage dist = distributions[distributionId];

        if (!dist.active) return 0;
        if (dist.expiresAt != 0 && block.timestamp > dist.expiresAt) return 0;
        if (hasClaimed[distributionId][user]) return 0;

        uint256 userBalance = PROJECT_POOL.balanceOf(user, dist.poolId);
        if (userBalance == 0) return 0;

        return (userBalance * dist.amountPerToken) / 1e18;
    }

    /**
     * @notice Get all claimable distributions for a user
     * @param user User address
     * @param poolId Pool ID to check
     * @return distributionIds Array of claimable distribution IDs
     * @return amounts Array of claimable amounts
     */
    function getClaimableDistributions(address user, uint256 poolId)
        external
        view
        returns (uint256[] memory distributionIds, uint256[] memory amounts)
    {
        // Count claimable distributions
        uint256 count;
        for (uint256 i = 0; i < nextDistributionId; i++) {
            Distribution storage dist = distributions[i];
            if (dist.poolId != poolId) continue;
            if (!dist.active) continue;
            if (dist.expiresAt != 0 && block.timestamp > dist.expiresAt) continue;
            if (hasClaimed[i][user]) continue;

            uint256 userBalance = PROJECT_POOL.balanceOf(user, poolId);
            if (userBalance > 0) {
                uint256 claimAmount = (userBalance * dist.amountPerToken) / 1e18;
                if (claimAmount > 0) count++;
            }
        }

        // Populate arrays
        distributionIds = new uint256[](count);
        amounts = new uint256[](count);
        uint256 index;

        for (uint256 i = 0; i < nextDistributionId; i++) {
            Distribution storage dist = distributions[i];
            if (dist.poolId != poolId) continue;
            if (!dist.active) continue;
            if (dist.expiresAt != 0 && block.timestamp > dist.expiresAt) continue;
            if (hasClaimed[i][user]) continue;

            uint256 userBalance = PROJECT_POOL.balanceOf(user, poolId);
            if (userBalance > 0) {
                uint256 claimAmount = (userBalance * dist.amountPerToken) / 1e18;
                if (claimAmount > 0) {
                    distributionIds[index] = i;
                    amounts[index] = claimAmount;
                    index++;
                }
            }
        }
    }

    /**
     * @notice Get pool balance
     * @param poolId Pool ID
     */
    function getPoolBalance(uint256 poolId) external view returns (uint256) {
        return poolBalances[poolId];
    }

    /**
     * @notice Check if user has claimed a distribution
     * @param distributionId Distribution ID
     * @param user User address
     */
    function hasUserClaimed(uint256 distributionId, address user) external view returns (bool) {
        return hasClaimed[distributionId][user];
    }
}
