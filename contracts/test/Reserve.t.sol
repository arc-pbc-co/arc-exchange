// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Reserve} from "../src/Reserve.sol";
import {ProjectPool} from "../src/ProjectPool.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract ReserveTest is Test {
    Reserve public reserve;
    ProjectPool public pool;
    ERC20Mock public usdc;

    address public admin;
    address public distributor;
    address public investor1;
    address public investor2;

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 10 ** 6; // 1M USDC

    function setUp() public {
        admin = makeAddr("admin");
        distributor = makeAddr("distributor");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");

        // Deploy mock USDC
        usdc = new ERC20Mock("USD Coin", "USDC", 6);

        // Deploy ProjectPool
        vm.prank(admin);
        pool = new ProjectPool(admin, "https://api.arcexchange.io/metadata/");

        // Deploy Reserve
        vm.prank(admin);
        reserve = new Reserve(address(pool), address(usdc), admin);

        // Grant distributor role
        bytes32 distributorRole = reserve.DISTRIBUTOR_ROLE();
        vm.prank(admin);
        reserve.grantRole(distributorRole, distributor);

        // Verify investors and mint pool tokens
        vm.startPrank(admin);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);

        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);
        pool.mint(investor1, poolId, 100); // 100 tokens
        pool.mint(investor2, poolId, 200); // 200 tokens
        vm.stopPrank();

        // Fund accounts with USDC
        usdc.mint(admin, INITIAL_BALANCE);
        usdc.mint(distributor, INITIAL_BALANCE);
        usdc.mint(investor1, INITIAL_BALANCE);

        // Approve reserve to spend USDC
        vm.prank(admin);
        usdc.approve(address(reserve), type(uint256).max);
        vm.prank(distributor);
        usdc.approve(address(reserve), type(uint256).max);
        vm.prank(investor1);
        usdc.approve(address(reserve), type(uint256).max);
    }

    // ============ Deposit Tests ============

    function test_Deposit() public {
        uint256 poolId = 0;
        uint256 amount = 10_000 * 10 ** 6; // 10k USDC

        vm.prank(investor1);
        reserve.deposit(poolId, amount);

        assertEq(reserve.poolBalances(poolId), amount);
        assertEq(reserve.totalReserves(), amount);
        assertEq(usdc.balanceOf(address(reserve)), amount);
    }

    function test_RevertDepositZeroAmount() public {
        vm.prank(investor1);
        vm.expectRevert(Reserve.InvalidAmount.selector);
        reserve.deposit(0, 0);
    }

    // ============ Withdraw Tests ============

    function test_Withdraw() public {
        uint256 poolId = 0;
        uint256 depositAmount = 10_000 * 10 ** 6;
        uint256 withdrawAmount = 5_000 * 10 ** 6;

        vm.prank(investor1);
        reserve.deposit(poolId, depositAmount);

        address recipient = makeAddr("recipient");
        vm.prank(admin);
        reserve.withdraw(poolId, withdrawAmount, recipient);

        assertEq(reserve.poolBalances(poolId), depositAmount - withdrawAmount);
        assertEq(usdc.balanceOf(recipient), withdrawAmount);
    }

    function test_RevertWithdrawInsufficientBalance() public {
        uint256 poolId = 0;

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(Reserve.InsufficientBalance.selector, poolId, 1000, 0)
        );
        reserve.withdraw(poolId, 1000, admin);
    }

    function test_RevertWithdrawUnauthorized() public {
        vm.prank(investor1);
        vm.expectRevert();
        reserve.withdraw(0, 1000, investor1);
    }

    // ============ Distribution Tests ============

    function test_CreateDistribution() public {
        uint256 poolId = 0;
        uint256 amount = 30_000 * 10 ** 6; // 30k USDC for 300 tokens

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, amount, 0);

        (
            uint256 retPoolId,
            uint256 totalAmount,
            uint256 totalSupplyAtSnapshot,
            uint256 amountPerToken,
            uint256 claimedAmount,
            uint256 remainingAmount,
            ,
            ,
            bool active
        ) = reserve.getDistribution(distributionId);

        assertEq(retPoolId, poolId);
        assertEq(totalAmount, amount);
        assertEq(totalSupplyAtSnapshot, 300); // 100 + 200 tokens
        assertEq(amountPerToken, (amount * 1e18) / 300);
        assertEq(claimedAmount, 0);
        assertEq(remainingAmount, amount);
        assertTrue(active);
    }

    function test_ClaimDistribution() public {
        uint256 poolId = 0;
        uint256 amount = 30_000 * 10 ** 6;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, amount, 0);

        // investor1 has 100 tokens out of 300 total = 1/3 of distribution
        uint256 expectedClaim = (100 * (amount * 1e18 / 300)) / 1e18;

        uint256 balanceBefore = usdc.balanceOf(investor1);

        vm.prank(investor1);
        reserve.claim(distributionId);

        assertEq(usdc.balanceOf(investor1) - balanceBefore, expectedClaim);
        assertTrue(reserve.hasClaimed(distributionId, investor1));
    }

    function test_ClaimBatch() public {
        uint256 poolId = 0;

        // Create two distributions
        vm.startPrank(distributor);
        uint256 dist1 = reserve.createDistribution(poolId, 30_000 * 10 ** 6, 0);
        uint256 dist2 = reserve.createDistribution(poolId, 15_000 * 10 ** 6, 0);
        vm.stopPrank();

        uint256[] memory distributionIds = new uint256[](2);
        distributionIds[0] = dist1;
        distributionIds[1] = dist2;

        uint256 balanceBefore = usdc.balanceOf(investor1);

        vm.prank(investor1);
        reserve.claimBatch(distributionIds);

        // investor1 should receive 1/3 of both distributions
        uint256 expectedFromDist1 = (100 * (30_000 * 10 ** 6 * 1e18 / 300)) / 1e18;
        uint256 expectedFromDist2 = (100 * (15_000 * 10 ** 6 * 1e18 / 300)) / 1e18;

        assertEq(usdc.balanceOf(investor1) - balanceBefore, expectedFromDist1 + expectedFromDist2);
    }

    function test_RevertClaimAlreadyClaimed() public {
        uint256 poolId = 0;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, 30_000 * 10 ** 6, 0);

        vm.prank(investor1);
        reserve.claim(distributionId);

        vm.prank(investor1);
        vm.expectRevert(
            abi.encodeWithSelector(Reserve.AlreadyClaimed.selector, distributionId, investor1)
        );
        reserve.claim(distributionId);
    }

    function test_RevertClaimNoBalance() public {
        uint256 poolId = 0;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, 30_000 * 10 ** 6, 0);

        address noTokenUser = makeAddr("noTokenUser");

        vm.prank(noTokenUser);
        vm.expectRevert(
            abi.encodeWithSelector(Reserve.NothingToClaim.selector, distributionId, noTokenUser)
        );
        reserve.claim(distributionId);
    }

    function test_RevertClaimExpiredDistribution() public {
        uint256 poolId = 0;
        uint256 expiresAt = block.timestamp + 1 hours;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, 30_000 * 10 ** 6, expiresAt);

        // Fast forward past expiration
        vm.warp(expiresAt + 1);

        vm.prank(investor1);
        vm.expectRevert(
            abi.encodeWithSelector(Reserve.DistributionExpired.selector, distributionId)
        );
        reserve.claim(distributionId);
    }

    // ============ Distribution from Balance Tests ============

    function test_CreateDistributionFromBalance() public {
        uint256 poolId = 0;
        uint256 depositAmount = 50_000 * 10 ** 6;
        uint256 distributionAmount = 30_000 * 10 ** 6;

        // First deposit funds to pool balance
        vm.prank(investor1);
        reserve.deposit(poolId, depositAmount);

        // Create distribution from that balance
        vm.prank(distributor);
        uint256 distributionId = reserve.createDistributionFromBalance(
            poolId,
            distributionAmount,
            0
        );

        // Check pool balance was reduced
        assertEq(reserve.poolBalances(poolId), depositAmount - distributionAmount);

        // Check distribution was created
        (, uint256 totalAmount, , , , , , , bool active) = reserve.getDistribution(distributionId);
        assertEq(totalAmount, distributionAmount);
        assertTrue(active);
    }

    // ============ Cancel Distribution Tests ============

    function test_CancelDistribution() public {
        uint256 poolId = 0;
        uint256 amount = 30_000 * 10 ** 6;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, amount, 0);

        // investor1 claims their portion first
        vm.prank(investor1);
        reserve.claim(distributionId);

        uint256 adminBalanceBefore = usdc.balanceOf(admin);

        // Admin cancels, getting remaining funds back
        vm.prank(admin);
        reserve.cancelDistribution(distributionId);

        // Admin should receive remaining funds (2/3 of total)
        uint256 investor1Claimed = (100 * (amount * 1e18 / 300)) / 1e18;
        uint256 expectedRemaining = amount - investor1Claimed;

        assertEq(usdc.balanceOf(admin) - adminBalanceBefore, expectedRemaining);

        // Distribution should now be inactive
        (, , , , , , , , bool active) = reserve.getDistribution(distributionId);
        assertFalse(active);
    }

    // ============ Reclaim Expired Tests ============

    function test_ReclaimExpired() public {
        uint256 poolId = 0;
        uint256 amount = 30_000 * 10 ** 6;
        uint256 expiresAt = block.timestamp + 1 hours;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, amount, expiresAt);

        // investor1 claims before expiry
        vm.prank(investor1);
        reserve.claim(distributionId);

        // Fast forward past expiration
        vm.warp(expiresAt + 1);

        uint256 adminBalanceBefore = usdc.balanceOf(admin);

        vm.prank(admin);
        reserve.reclaimExpired(distributionId);

        // Admin should receive remaining unclaimed funds
        uint256 investor1Claimed = (100 * (amount * 1e18 / 300)) / 1e18;
        uint256 expectedRemaining = amount - investor1Claimed;

        assertEq(usdc.balanceOf(admin) - adminBalanceBefore, expectedRemaining);
    }

    function test_RevertReclaimNotExpired() public {
        uint256 poolId = 0;
        uint256 expiresAt = block.timestamp + 1 hours;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, 30_000 * 10 ** 6, expiresAt);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Reserve.NotExpired.selector, distributionId));
        reserve.reclaimExpired(distributionId);
    }

    // ============ View Function Tests ============

    function test_GetClaimableAmount() public {
        uint256 poolId = 0;
        uint256 amount = 30_000 * 10 ** 6;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, amount, 0);

        uint256 claimable = reserve.getClaimableAmount(distributionId, investor1);
        uint256 expected = (100 * (amount * 1e18 / 300)) / 1e18;

        assertEq(claimable, expected);
    }

    function test_GetClaimableDistributions() public {
        uint256 poolId = 0;

        vm.startPrank(distributor);
        reserve.createDistribution(poolId, 30_000 * 10 ** 6, 0);
        reserve.createDistribution(poolId, 15_000 * 10 ** 6, 0);
        vm.stopPrank();

        (uint256[] memory ids, uint256[] memory amounts) = reserve.getClaimableDistributions(
            investor1,
            poolId
        );

        assertEq(ids.length, 2);
        assertEq(amounts.length, 2);
        assertEq(ids[0], 0);
        assertEq(ids[1], 1);
    }

    function test_HasUserClaimed() public {
        uint256 poolId = 0;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, 30_000 * 10 ** 6, 0);

        assertFalse(reserve.hasUserClaimed(distributionId, investor1));

        vm.prank(investor1);
        reserve.claim(distributionId);

        assertTrue(reserve.hasUserClaimed(distributionId, investor1));
    }

    // ============ Pause Tests ============

    function test_PauseDeposit() public {
        vm.prank(admin);
        reserve.pause();

        vm.prank(investor1);
        vm.expectRevert();
        reserve.deposit(0, 1000);
    }

    function test_PauseClaim() public {
        uint256 poolId = 0;

        vm.prank(distributor);
        uint256 distributionId = reserve.createDistribution(poolId, 30_000 * 10 ** 6, 0);

        vm.prank(admin);
        reserve.pause();

        vm.prank(investor1);
        vm.expectRevert();
        reserve.claim(distributionId);
    }

    // ============ Emergency Withdraw Tests ============

    function test_EmergencyWithdraw() public {
        // Send some USDC directly to reserve (simulating stuck funds)
        usdc.mint(address(reserve), 1000 * 10 ** 6);

        address recipient = makeAddr("recipient");
        uint256 amount = 500 * 10 ** 6;

        vm.prank(admin);
        reserve.emergencyWithdraw(address(usdc), recipient, amount);

        assertEq(usdc.balanceOf(recipient), amount);
    }
}
