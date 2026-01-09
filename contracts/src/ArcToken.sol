// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title ArcToken
 * @notice ERC-20 token for the ARC Exchange ecosystem
 * @dev Platform utility token used for participating in project pools
 *
 * Features:
 * - ERC20 with burning capability
 * - Pausable for emergency situations
 * - Role-based access control for minting
 * - EIP-2612 permit for gasless approvals
 * - Max supply cap of 1 billion tokens
 */
contract ArcToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens

    // Events
    event MaxSupplyMinted(uint256 totalSupply);

    // Errors
    error MaxSupplyExceeded(uint256 requested, uint256 available);
    error ZeroAddress();
    error ZeroAmount();

    constructor(address defaultAdmin) ERC20("ARC Token", "ARC") ERC20Permit("ARC Token") {
        if (defaultAdmin == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
    }

    /**
     * @notice Mint new tokens
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = MAX_SUPPLY - totalSupply();
        if (amount > available) {
            revert MaxSupplyExceeded(amount, available);
        }

        _mint(to, amount);

        if (totalSupply() == MAX_SUPPLY) {
            emit MaxSupplyMinted(MAX_SUPPLY);
        }
    }

    /**
     * @notice Mint tokens to multiple recipients in a single transaction
     * @param recipients Array of addresses to receive tokens
     * @param amounts Array of amounts to mint to each recipient
     */
    function mintBatch(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "ArcToken: arrays length mismatch");

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        uint256 available = MAX_SUPPLY - totalSupply();
        if (totalAmount > available) {
            revert MaxSupplyExceeded(totalAmount, available);
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            _mint(recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Pause all token transfers
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause token transfers
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Get the remaining mintable supply
     * @return The number of tokens that can still be minted
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @notice Check if max supply has been reached
     * @return True if max supply has been minted
     */
    function isMaxSupplyReached() external view returns (bool) {
        return totalSupply() >= MAX_SUPPLY;
    }

    // Required overrides for multiple inheritance

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
