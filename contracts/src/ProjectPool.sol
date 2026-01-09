// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ProjectPool
 * @notice ERC-1155 multi-token contract for project pool shares
 * @dev Each token ID represents a different investment pool
 *      Only verified (KYC'd/accredited) investors can hold or transfer tokens
 */
contract ProjectPool is ERC1155, ERC1155Supply, AccessControl {
    using Strings for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Mapping of verified investors
    mapping(address => bool) public isVerifiedInvestor;

    // Pool metadata URIs (token ID => URI)
    mapping(uint256 => string) private _tokenURIs;

    // Pool counter
    uint256 public nextPoolId;

    // Events
    event InvestorVerified(address indexed investor);
    event InvestorRevoked(address indexed investor);
    event PoolCreated(uint256 indexed poolId, string uri);

    constructor(address defaultAdmin, string memory baseUri) ERC1155(baseUri) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
    }

    /**
     * @notice Verify an investor (mark as KYC'd and accredited)
     * @param investor Address to verify
     */
    function verifyInvestor(address investor) external onlyRole(ADMIN_ROLE) {
        isVerifiedInvestor[investor] = true;
        emit InvestorVerified(investor);
    }

    /**
     * @notice Batch verify multiple investors
     * @param investors Array of addresses to verify
     */
    function verifyInvestorBatch(address[] calldata investors) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < investors.length; i++) {
            isVerifiedInvestor[investors[i]] = true;
            emit InvestorVerified(investors[i]);
        }
    }

    /**
     * @notice Revoke investor verification
     * @param investor Address to revoke
     */
    function revokeInvestor(address investor) external onlyRole(ADMIN_ROLE) {
        isVerifiedInvestor[investor] = false;
        emit InvestorRevoked(investor);
    }

    /**
     * @notice Create a new pool
     * @param metadataUri IPFS URI for pool metadata
     * @return poolId The ID of the created pool
     */
    function createPool(string calldata metadataUri) external onlyRole(ADMIN_ROLE) returns (uint256) {
        uint256 poolId = nextPoolId++;
        _tokenURIs[poolId] = metadataUri;
        emit PoolCreated(poolId, metadataUri);
        return poolId;
    }

    /**
     * @notice Mint pool tokens to a verified investor
     * @param to Address to receive tokens
     * @param poolId Pool ID to mint
     * @param amount Number of tokens to mint
     */
    function mint(address to, uint256 poolId, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(isVerifiedInvestor[to], "ProjectPool: recipient not verified");
        _mint(to, poolId, amount, "");
    }

    /**
     * @notice Batch mint multiple pool tokens
     * @param to Address to receive tokens
     * @param poolIds Array of pool IDs
     * @param amounts Array of amounts
     */
    function mintBatch(
        address to,
        uint256[] calldata poolIds,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(isVerifiedInvestor[to], "ProjectPool: recipient not verified");
        _mintBatch(to, poolIds, amounts, "");
    }

    /**
     * @notice Get the URI for a specific pool
     * @param poolId Pool ID
     */
    function uri(uint256 poolId) public view override returns (string memory) {
        string memory tokenUri = _tokenURIs[poolId];
        if (bytes(tokenUri).length > 0) {
            return tokenUri;
        }
        return string(abi.encodePacked(super.uri(poolId), poolId.toString(), ".json"));
    }

    /**
     * @notice Update pool metadata URI
     * @param poolId Pool ID
     * @param newUri New metadata URI
     */
    function setPoolUri(uint256 poolId, string calldata newUri) external onlyRole(ADMIN_ROLE) {
        _tokenURIs[poolId] = newUri;
        emit URI(newUri, poolId);
    }

    /**
     * @dev Override to enforce verified investor requirement on transfers
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(ERC1155, ERC1155Supply) {
        // Skip verification for minting (from == address(0)) and burning (to == address(0))
        if (to != address(0)) {
            require(isVerifiedInvestor[to], "ProjectPool: recipient not verified");
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
