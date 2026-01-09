// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ProjectPool
 * @notice ERC-1155 multi-token contract for project pool shares
 * @dev Each token ID represents a different investment pool
 *      Only verified (KYC'd/accredited) investors can hold or transfer tokens
 *
 * Features:
 * - Multi-token standard (ERC-1155) for multiple pools
 * - Investor verification (whitelist) required for all transfers
 * - Pausable for emergency situations
 * - Pool metadata management
 * - Role-based access control
 */
contract ProjectPool is ERC1155, ERC1155Supply, ERC1155Pausable, AccessControl {
    using Strings for uint256;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // Pool data structure
    struct PoolInfo {
        string metadataUri;
        uint256 maxSupply;
        bool transferable; // Whether secondary transfers are allowed
        bool active;
        uint256 createdAt;
    }

    // Mapping of verified investors
    mapping(address => bool) public isVerifiedInvestor;

    // Pool information (token ID => PoolInfo)
    mapping(uint256 => PoolInfo) public pools;

    // Pool counter
    uint256 public nextPoolId;

    // Base URI for metadata
    string private _baseUri;

    // Events
    event InvestorVerified(address indexed investor, uint256 timestamp);
    event InvestorRevoked(address indexed investor, uint256 timestamp);
    event InvestorVerifiedBatch(address[] investors, uint256 timestamp);
    event PoolCreated(
        uint256 indexed poolId,
        string metadataUri,
        uint256 maxSupply,
        bool transferable
    );
    event PoolUpdated(uint256 indexed poolId, bool active, bool transferable);
    event PoolMetadataUpdated(uint256 indexed poolId, string newUri);

    // Errors
    error NotVerifiedInvestor(address account);
    error PoolNotActive(uint256 poolId);
    error PoolNotTransferable(uint256 poolId);
    error MaxSupplyExceeded(uint256 poolId, uint256 requested, uint256 available);
    error PoolDoesNotExist(uint256 poolId);
    error ZeroAddress();
    error InvalidMaxSupply();
    error ArrayLengthMismatch();

    constructor(
        address defaultAdmin,
        string memory baseUri
    ) ERC1155(baseUri) {
        if (defaultAdmin == address(0)) revert ZeroAddress();

        _baseUri = baseUri;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(VERIFIER_ROLE, defaultAdmin);
    }

    // ============ Investor Verification ============

    /**
     * @notice Verify an investor (mark as KYC'd and accredited)
     * @param investor Address to verify
     */
    function verifyInvestor(address investor) external onlyRole(VERIFIER_ROLE) {
        if (investor == address(0)) revert ZeroAddress();
        isVerifiedInvestor[investor] = true;
        emit InvestorVerified(investor, block.timestamp);
    }

    /**
     * @notice Batch verify multiple investors
     * @param investors Array of addresses to verify
     */
    function verifyInvestorBatch(address[] calldata investors) external onlyRole(VERIFIER_ROLE) {
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i] == address(0)) revert ZeroAddress();
            isVerifiedInvestor[investors[i]] = true;
        }
        emit InvestorVerifiedBatch(investors, block.timestamp);
    }

    /**
     * @notice Revoke investor verification
     * @param investor Address to revoke
     */
    function revokeInvestor(address investor) external onlyRole(VERIFIER_ROLE) {
        isVerifiedInvestor[investor] = false;
        emit InvestorRevoked(investor, block.timestamp);
    }

    /**
     * @notice Batch revoke multiple investors
     * @param investors Array of addresses to revoke
     */
    function revokeInvestorBatch(address[] calldata investors) external onlyRole(VERIFIER_ROLE) {
        for (uint256 i = 0; i < investors.length; i++) {
            isVerifiedInvestor[investors[i]] = false;
            emit InvestorRevoked(investors[i], block.timestamp);
        }
    }

    // ============ Pool Management ============

    /**
     * @notice Create a new pool
     * @param metadataUri IPFS URI for pool metadata
     * @param maxSupply Maximum number of tokens for this pool (0 = unlimited)
     * @param transferable Whether secondary transfers are allowed
     * @return poolId The ID of the created pool
     */
    function createPool(
        string calldata metadataUri,
        uint256 maxSupply,
        bool transferable
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        uint256 poolId = nextPoolId++;

        pools[poolId] = PoolInfo({
            metadataUri: metadataUri,
            maxSupply: maxSupply,
            transferable: transferable,
            active: true,
            createdAt: block.timestamp
        });

        emit PoolCreated(poolId, metadataUri, maxSupply, transferable);
        return poolId;
    }

    /**
     * @notice Update pool settings
     * @param poolId Pool ID to update
     * @param active Whether the pool is active
     * @param transferable Whether secondary transfers are allowed
     */
    function updatePool(
        uint256 poolId,
        bool active,
        bool transferable
    ) external onlyRole(ADMIN_ROLE) {
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);

        pools[poolId].active = active;
        pools[poolId].transferable = transferable;

        emit PoolUpdated(poolId, active, transferable);
    }

    /**
     * @notice Update pool metadata URI
     * @param poolId Pool ID
     * @param newUri New metadata URI
     */
    function setPoolUri(uint256 poolId, string calldata newUri) external onlyRole(ADMIN_ROLE) {
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);

        pools[poolId].metadataUri = newUri;
        emit URI(newUri, poolId);
        emit PoolMetadataUpdated(poolId, newUri);
    }

    // ============ Minting ============

    /**
     * @notice Mint pool tokens to a verified investor
     * @param to Address to receive tokens
     * @param poolId Pool ID to mint
     * @param amount Number of tokens to mint
     */
    function mint(
        address to,
        uint256 poolId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        if (!isVerifiedInvestor[to]) revert NotVerifiedInvestor(to);
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);
        if (!pools[poolId].active) revert PoolNotActive(poolId);

        // Check max supply if set
        if (pools[poolId].maxSupply > 0) {
            uint256 available = pools[poolId].maxSupply - totalSupply(poolId);
            if (amount > available) {
                revert MaxSupplyExceeded(poolId, amount, available);
            }
        }

        _mint(to, poolId, amount, "");
    }

    /**
     * @notice Batch mint multiple pool tokens to a single recipient
     * @param to Address to receive tokens
     * @param poolIds Array of pool IDs
     * @param amounts Array of amounts
     */
    function mintBatch(
        address to,
        uint256[] calldata poolIds,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        if (!isVerifiedInvestor[to]) revert NotVerifiedInvestor(to);
        if (poolIds.length != amounts.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < poolIds.length; i++) {
            if (poolIds[i] >= nextPoolId) revert PoolDoesNotExist(poolIds[i]);
            if (!pools[poolIds[i]].active) revert PoolNotActive(poolIds[i]);

            if (pools[poolIds[i]].maxSupply > 0) {
                uint256 available = pools[poolIds[i]].maxSupply - totalSupply(poolIds[i]);
                if (amounts[i] > available) {
                    revert MaxSupplyExceeded(poolIds[i], amounts[i], available);
                }
            }
        }

        _mintBatch(to, poolIds, amounts, "");
    }

    /**
     * @notice Mint tokens to multiple recipients for a single pool
     * @param recipients Array of recipient addresses
     * @param poolId Pool ID to mint
     * @param amounts Array of amounts for each recipient
     */
    function mintToMultiple(
        address[] calldata recipients,
        uint256 poolId,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);
        if (!pools[poolId].active) revert PoolNotActive(poolId);

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        if (pools[poolId].maxSupply > 0) {
            uint256 available = pools[poolId].maxSupply - totalSupply(poolId);
            if (totalAmount > available) {
                revert MaxSupplyExceeded(poolId, totalAmount, available);
            }
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            if (!isVerifiedInvestor[recipients[i]]) revert NotVerifiedInvestor(recipients[i]);
            _mint(recipients[i], poolId, amounts[i], "");
        }
    }

    // ============ Burning ============

    /**
     * @notice Burn pool tokens (for redemption)
     * @param from Address to burn from
     * @param poolId Pool ID
     * @param amount Amount to burn
     */
    function burn(
        address from,
        uint256 poolId,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        _burn(from, poolId, amount);
    }

    // ============ Pausable ============

    /**
     * @notice Pause all token transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause token transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get the URI for a specific pool
     * @param poolId Pool ID
     */
    function uri(uint256 poolId) public view override returns (string memory) {
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);

        string memory tokenUri = pools[poolId].metadataUri;
        if (bytes(tokenUri).length > 0) {
            return tokenUri;
        }
        return string(abi.encodePacked(_baseUri, poolId.toString(), ".json"));
    }

    /**
     * @notice Get pool information
     * @param poolId Pool ID
     */
    function getPoolInfo(uint256 poolId)
        external
        view
        returns (
            string memory metadataUri,
            uint256 maxSupply,
            uint256 currentSupply,
            bool transferable,
            bool active,
            uint256 createdAt
        )
    {
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);

        PoolInfo storage pool = pools[poolId];
        return (
            pool.metadataUri,
            pool.maxSupply,
            totalSupply(poolId),
            pool.transferable,
            pool.active,
            pool.createdAt
        );
    }

    /**
     * @notice Get remaining mintable supply for a pool
     * @param poolId Pool ID
     * @return Remaining supply (type(uint256).max if unlimited)
     */
    function remainingSupply(uint256 poolId) external view returns (uint256) {
        if (poolId >= nextPoolId) revert PoolDoesNotExist(poolId);

        if (pools[poolId].maxSupply == 0) {
            return type(uint256).max; // Unlimited
        }
        return pools[poolId].maxSupply - totalSupply(poolId);
    }

    /**
     * @notice Check if a pool exists
     * @param poolId Pool ID
     */
    function poolExists(uint256 poolId) external view returns (bool) {
        return poolId < nextPoolId;
    }

    // ============ Internal Overrides ============

    /**
     * @dev Override to enforce verified investor requirement on transfers
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(ERC1155, ERC1155Supply, ERC1155Pausable) {
        // Skip verification for minting (from == address(0)) and burning (to == address(0))
        if (to != address(0)) {
            if (!isVerifiedInvestor[to]) revert NotVerifiedInvestor(to);
        }

        // Check transferability for secondary transfers (not minting or burning)
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (!pools[ids[i]].transferable) {
                    revert PoolNotTransferable(ids[i]);
                }
            }
        }

        super._update(from, to, ids, values);
    }

    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
