// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ArcToken} from "../src/ArcToken.sol";

contract ArcTokenTest is Test {
    ArcToken public token;
    address public admin;
    address public minter;
    address public user1;
    address public user2;

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(admin);
        token = new ArcToken(admin);

        // Grant minter role
        bytes32 minterRole = token.MINTER_ROLE();
        vm.prank(admin);
        token.grantRole(minterRole, minter);
    }

    function test_InitialState() public view {
        assertEq(token.name(), "ARC Token");
        assertEq(token.symbol(), "ARC");
        assertEq(token.totalSupply(), 0);
        assertEq(token.MAX_SUPPLY(), 1_000_000_000 * 10 ** 18);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), admin));
    }

    function test_Mint() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(minter);
        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_MintBatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000 * 10 ** 18;
        amounts[1] = 2000 * 10 ** 18;

        vm.prank(minter);
        token.mintBatch(recipients, amounts);

        assertEq(token.balanceOf(user1), 1000 * 10 ** 18);
        assertEq(token.balanceOf(user2), 2000 * 10 ** 18);
        assertEq(token.totalSupply(), 3000 * 10 ** 18);
    }

    function test_RevertMintExceedsMaxSupply() public {
        uint256 maxSupply = token.MAX_SUPPLY();
        uint256 amount = maxSupply + 1;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                ArcToken.MaxSupplyExceeded.selector,
                amount,
                maxSupply
            )
        );
        token.mint(user1, amount);
    }

    function test_RevertMintToZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(ArcToken.ZeroAddress.selector);
        token.mint(address(0), 1000);
    }

    function test_RevertMintZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(ArcToken.ZeroAmount.selector);
        token.mint(user1, 0);
    }

    function test_RevertUnauthorizedMint() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1000);
    }

    function test_Burn() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(minter);
        token.mint(user1, amount);

        vm.prank(user1);
        token.burn(500 * 10 ** 18);

        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
    }

    function test_Pause() public {
        vm.prank(minter);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(admin);
        token.pause();

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 100 * 10 ** 18);
    }

    function test_Unpause() public {
        vm.prank(minter);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(admin);
        token.pause();

        vm.prank(admin);
        token.unpause();

        vm.prank(user1);
        token.transfer(user2, 100 * 10 ** 18);

        assertEq(token.balanceOf(user2), 100 * 10 ** 18);
    }

    function test_RemainingSupply() public {
        vm.prank(minter);
        token.mint(user1, 1000 * 10 ** 18);

        assertEq(token.remainingSupply(), token.MAX_SUPPLY() - 1000 * 10 ** 18);
    }

    function test_IsMaxSupplyReached() public view {
        assertFalse(token.isMaxSupplyReached());
    }

    function test_Transfer() public {
        vm.prank(minter);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        token.transfer(user2, 400 * 10 ** 18);

        assertEq(token.balanceOf(user1), 600 * 10 ** 18);
        assertEq(token.balanceOf(user2), 400 * 10 ** 18);
    }

    function test_Approve_TransferFrom() public {
        vm.prank(minter);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        token.approve(user2, 500 * 10 ** 18);

        vm.prank(user2);
        token.transferFrom(user1, user2, 500 * 10 ** 18);

        assertEq(token.balanceOf(user2), 500 * 10 ** 18);
    }

    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 1, token.MAX_SUPPLY());

        vm.prank(minter);
        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }
}
