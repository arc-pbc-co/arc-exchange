// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/ProjectPool.sol";

contract ProjectPoolTest is Test {
    ProjectPool public pool;
    address public admin;
    address public investor1;
    address public investor2;
    address public unverifiedUser;

    function setUp() public {
        admin = makeAddr("admin");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        unverifiedUser = makeAddr("unverified");

        vm.prank(admin);
        pool = new ProjectPool(admin, "https://api.arcexchange.io/metadata/");
    }

    function test_InitialState() public view {
        assertEq(pool.nextPoolId(), 0);
        assertTrue(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pool.hasRole(pool.ADMIN_ROLE(), admin));
        assertTrue(pool.hasRole(pool.MINTER_ROLE(), admin));
    }

    function test_VerifyInvestor() public {
        assertFalse(pool.isVerifiedInvestor(investor1));

        vm.prank(admin);
        pool.verifyInvestor(investor1);

        assertTrue(pool.isVerifiedInvestor(investor1));
    }

    function test_VerifyInvestorBatch() public {
        address[] memory investors = new address[](2);
        investors[0] = investor1;
        investors[1] = investor2;

        vm.prank(admin);
        pool.verifyInvestorBatch(investors);

        assertTrue(pool.isVerifiedInvestor(investor1));
        assertTrue(pool.isVerifiedInvestor(investor2));
    }

    function test_RevokeInvestor() public {
        vm.startPrank(admin);
        pool.verifyInvestor(investor1);
        assertTrue(pool.isVerifiedInvestor(investor1));

        pool.revokeInvestor(investor1);
        assertFalse(pool.isVerifiedInvestor(investor1));
        vm.stopPrank();
    }

    function test_CreatePool() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest123");

        assertEq(poolId, 0);
        assertEq(pool.nextPoolId(), 1);
        assertEq(pool.uri(poolId), "ipfs://QmTest123");
    }

    function test_MintToVerifiedInvestor() public {
        vm.startPrank(admin);
        pool.verifyInvestor(investor1);
        uint256 poolId = pool.createPool("ipfs://QmTest123");
        pool.mint(investor1, poolId, 100);
        vm.stopPrank();

        assertEq(pool.balanceOf(investor1, poolId), 100);
        assertEq(pool.totalSupply(poolId), 100);
    }

    function test_RevertMintToUnverifiedInvestor() public {
        vm.startPrank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest123");

        vm.expectRevert("ProjectPool: recipient not verified");
        pool.mint(unverifiedUser, poolId, 100);
        vm.stopPrank();
    }

    function test_TransferBetweenVerifiedInvestors() public {
        vm.startPrank(admin);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        uint256 poolId = pool.createPool("ipfs://QmTest123");
        pool.mint(investor1, poolId, 100);
        vm.stopPrank();

        vm.prank(investor1);
        pool.safeTransferFrom(investor1, investor2, poolId, 50, "");

        assertEq(pool.balanceOf(investor1, poolId), 50);
        assertEq(pool.balanceOf(investor2, poolId), 50);
    }

    function test_RevertTransferToUnverifiedInvestor() public {
        vm.startPrank(admin);
        pool.verifyInvestor(investor1);
        uint256 poolId = pool.createPool("ipfs://QmTest123");
        pool.mint(investor1, poolId, 100);
        vm.stopPrank();

        vm.prank(investor1);
        vm.expectRevert("ProjectPool: recipient not verified");
        pool.safeTransferFrom(investor1, unverifiedUser, poolId, 50, "");
    }

    function test_SetPoolUri() public {
        vm.startPrank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest123");
        pool.setPoolUri(poolId, "ipfs://QmNewUri456");
        vm.stopPrank();

        assertEq(pool.uri(poolId), "ipfs://QmNewUri456");
    }

    function test_RevertUnauthorizedVerify() public {
        vm.prank(investor1);
        vm.expectRevert();
        pool.verifyInvestor(investor2);
    }

    function test_RevertUnauthorizedMint() public {
        vm.prank(admin);
        pool.verifyInvestor(investor1);

        vm.prank(investor1);
        vm.expectRevert();
        pool.mint(investor1, 0, 100);
    }
}
