// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ProjectPool} from "../src/ProjectPool.sol";

contract ProjectPoolTest is Test {
    ProjectPool public pool;
    address public admin;
    address public verifier;
    address public minter;
    address public investor1;
    address public investor2;
    address public unverifiedUser;

    function setUp() public {
        admin = makeAddr("admin");
        verifier = makeAddr("verifier");
        minter = makeAddr("minter");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        unverifiedUser = makeAddr("unverified");

        vm.prank(admin);
        pool = new ProjectPool(admin, "https://api.arcexchange.io/metadata/");

        // Grant roles
        vm.startPrank(admin);
        pool.grantRole(pool.VERIFIER_ROLE(), verifier);
        pool.grantRole(pool.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(pool.nextPoolId(), 0);
        assertTrue(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pool.hasRole(pool.ADMIN_ROLE(), admin));
        assertTrue(pool.hasRole(pool.MINTER_ROLE(), admin));
        assertTrue(pool.hasRole(pool.PAUSER_ROLE(), admin));
        assertTrue(pool.hasRole(pool.VERIFIER_ROLE(), admin));
    }

    // ============ Investor Verification Tests ============

    function test_VerifyInvestor() public {
        assertFalse(pool.isVerifiedInvestor(investor1));

        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        assertTrue(pool.isVerifiedInvestor(investor1));
    }

    function test_VerifyInvestorBatch() public {
        address[] memory investors = new address[](2);
        investors[0] = investor1;
        investors[1] = investor2;

        vm.prank(verifier);
        pool.verifyInvestorBatch(investors);

        assertTrue(pool.isVerifiedInvestor(investor1));
        assertTrue(pool.isVerifiedInvestor(investor2));
    }

    function test_RevokeInvestor() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);
        assertTrue(pool.isVerifiedInvestor(investor1));

        vm.prank(verifier);
        pool.revokeInvestor(investor1);
        assertFalse(pool.isVerifiedInvestor(investor1));
    }

    function test_RevertVerifyZeroAddress() public {
        vm.prank(verifier);
        vm.expectRevert(ProjectPool.ZeroAddress.selector);
        pool.verifyInvestor(address(0));
    }

    function test_RevertUnauthorizedVerify() public {
        vm.prank(investor1);
        vm.expectRevert();
        pool.verifyInvestor(investor2);
    }

    // ============ Pool Creation Tests ============

    function test_CreatePool() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest123", 1000, true);

        assertEq(poolId, 0);
        assertEq(pool.nextPoolId(), 1);

        (
            string memory metadataUri,
            uint256 maxSupply,
            uint256 currentSupply,
            bool transferable,
            bool active,
            uint256 createdAt
        ) = pool.getPoolInfo(poolId);

        assertEq(metadataUri, "ipfs://QmTest123");
        assertEq(maxSupply, 1000);
        assertEq(currentSupply, 0);
        assertTrue(transferable);
        assertTrue(active);
        assertGt(createdAt, 0);
    }

    function test_CreatePoolUnlimitedSupply() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 0, false);

        assertEq(pool.remainingSupply(poolId), type(uint256).max);
    }

    function test_UpdatePool() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        pool.updatePool(poolId, false, false);

        (, , , bool transferable, bool active, ) = pool.getPoolInfo(poolId);
        assertFalse(active);
        assertFalse(transferable);
    }

    function test_SetPoolUri() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmOld", 1000, true);

        vm.prank(admin);
        pool.setPoolUri(poolId, "ipfs://QmNew");

        assertEq(pool.uri(poolId), "ipfs://QmNew");
    }

    function test_RevertPoolDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(ProjectPool.PoolDoesNotExist.selector, 999));
        pool.uri(999);
    }

    // ============ Minting Tests ============

    function test_MintToVerifiedInvestor() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        assertEq(pool.balanceOf(investor1, poolId), 100);
        assertEq(pool.totalSupply(poolId), 100);
    }

    function test_RevertMintToUnverifiedInvestor() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(ProjectPool.NotVerifiedInvestor.selector, unverifiedUser)
        );
        pool.mint(unverifiedUser, poolId, 100);
    }

    function test_RevertMintExceedsMaxSupply() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 100, true);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(ProjectPool.MaxSupplyExceeded.selector, poolId, 150, 100)
        );
        pool.mint(investor1, poolId, 150);
    }

    function test_RevertMintToInactivePool() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        pool.updatePool(poolId, false, true);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(ProjectPool.PoolNotActive.selector, poolId));
        pool.mint(investor1, poolId, 100);
    }

    function test_MintBatch() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.startPrank(admin);
        uint256 poolId1 = pool.createPool("ipfs://QmTest1", 1000, true);
        uint256 poolId2 = pool.createPool("ipfs://QmTest2", 1000, true);
        vm.stopPrank();

        uint256[] memory poolIds = new uint256[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        pool.mintBatch(investor1, poolIds, amounts);

        assertEq(pool.balanceOf(investor1, poolId1), 100);
        assertEq(pool.balanceOf(investor1, poolId2), 200);
    }

    function test_MintToMultiple() public {
        vm.startPrank(verifier);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        vm.stopPrank();

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        address[] memory recipients = new address[](2);
        recipients[0] = investor1;
        recipients[1] = investor2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        pool.mintToMultiple(recipients, poolId, amounts);

        assertEq(pool.balanceOf(investor1, poolId), 100);
        assertEq(pool.balanceOf(investor2, poolId), 200);
    }

    // ============ Transfer Tests ============

    function test_TransferBetweenVerifiedInvestors() public {
        vm.startPrank(verifier);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        vm.stopPrank();

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        vm.prank(investor1);
        pool.safeTransferFrom(investor1, investor2, poolId, 50, "");

        assertEq(pool.balanceOf(investor1, poolId), 50);
        assertEq(pool.balanceOf(investor2, poolId), 50);
    }

    function test_RevertTransferToUnverifiedInvestor() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        vm.prank(investor1);
        vm.expectRevert(
            abi.encodeWithSelector(ProjectPool.NotVerifiedInvestor.selector, unverifiedUser)
        );
        pool.safeTransferFrom(investor1, unverifiedUser, poolId, 50, "");
    }

    function test_RevertTransferNonTransferablePool() public {
        vm.startPrank(verifier);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        vm.stopPrank();

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, false); // Not transferable

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(ProjectPool.PoolNotTransferable.selector, poolId));
        pool.safeTransferFrom(investor1, investor2, poolId, 50, "");
    }

    // ============ Burning Tests ============

    function test_Burn() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        vm.prank(admin);
        pool.burn(investor1, poolId, 50);

        assertEq(pool.balanceOf(investor1, poolId), 50);
        assertEq(pool.totalSupply(poolId), 50);
    }

    // ============ Pausable Tests ============

    function test_Pause() public {
        vm.startPrank(verifier);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        vm.stopPrank();

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        vm.prank(admin);
        pool.pause();

        vm.prank(investor1);
        vm.expectRevert();
        pool.safeTransferFrom(investor1, investor2, poolId, 50, "");
    }

    function test_Unpause() public {
        vm.startPrank(verifier);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        vm.stopPrank();

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(minter);
        pool.mint(investor1, poolId, 100);

        vm.prank(admin);
        pool.pause();

        vm.prank(admin);
        pool.unpause();

        vm.prank(investor1);
        pool.safeTransferFrom(investor1, investor2, poolId, 50, "");

        assertEq(pool.balanceOf(investor2, poolId), 50);
    }

    // ============ View Function Tests ============

    function test_PoolExists() public {
        assertFalse(pool.poolExists(0));

        vm.prank(admin);
        pool.createPool("ipfs://QmTest", 1000, true);

        assertTrue(pool.poolExists(0));
        assertFalse(pool.poolExists(1));
    }

    function test_RemainingSupply() public {
        vm.prank(verifier);
        pool.verifyInvestor(investor1);

        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        assertEq(pool.remainingSupply(poolId), 1000);

        vm.prank(minter);
        pool.mint(investor1, poolId, 300);

        assertEq(pool.remainingSupply(poolId), 700);
    }
}
