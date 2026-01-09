// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "../src/Marketplace.sol";
import {ProjectPool} from "../src/ProjectPool.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    ProjectPool public pool;
    ERC20Mock public usdc;

    address public admin;
    address public treasury;
    address public investor1;
    address public investor2;
    address public unverifiedUser;

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 10 ** 6; // 1M USDC

    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        unverifiedUser = makeAddr("unverified");

        // Deploy mock USDC
        usdc = new ERC20Mock("USD Coin", "USDC", 6);

        // Deploy ProjectPool
        vm.prank(admin);
        pool = new ProjectPool(admin, "https://api.arcexchange.io/metadata/");

        // Deploy Marketplace with 2% fee
        vm.prank(admin);
        marketplace = new Marketplace(
            address(pool),
            address(usdc),
            treasury,
            admin,
            200 // 2% fee
        );

        // Grant marketplace minter role on pool
        bytes32 minterRole = pool.MINTER_ROLE();
        vm.prank(admin);
        pool.grantRole(minterRole, address(marketplace));

        // Verify investors
        vm.startPrank(admin);
        pool.verifyInvestor(investor1);
        pool.verifyInvestor(investor2);
        vm.stopPrank();

        // Fund investors with USDC
        usdc.mint(investor1, INITIAL_BALANCE);
        usdc.mint(investor2, INITIAL_BALANCE);

        // Approve marketplace to spend USDC
        vm.prank(investor1);
        usdc.approve(address(marketplace), type(uint256).max);
        vm.prank(investor2);
        usdc.approve(address(marketplace), type(uint256).max);
    }

    // ============ Listing Tests ============

    function test_ListPool() public {
        // Create pool first
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        // List on marketplace
        vm.prank(admin);
        marketplace.listPool(
            poolId,
            100 * 10 ** 6, // $100 per token
            1000, // max supply
            1, // min purchase
            100, // max purchase
            0, // start immediately
            0 // no end time
        );

        (
            uint256 pricePerToken,
            uint256 maxSupply,
            uint256 sold,
            uint256 available,
            uint256 minPurchase,
            uint256 maxPurchase,
            ,
            ,
            bool active,

        ) = marketplace.getListing(poolId);

        assertEq(pricePerToken, 100 * 10 ** 6);
        assertEq(maxSupply, 1000);
        assertEq(sold, 0);
        assertEq(available, 1000);
        assertEq(minPurchase, 1);
        assertEq(maxPurchase, 100);
        assertTrue(active);
    }

    function test_UpdateListing() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        vm.prank(admin);
        marketplace.updateListing(poolId, 150 * 10 ** 6, true);

        (uint256 pricePerToken, , , , , , , , , ) = marketplace.getListing(poolId);
        assertEq(pricePerToken, 150 * 10 ** 6);
    }

    function test_RevertListPoolInvalidPrice() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        vm.expectRevert(Marketplace.InvalidPrice.selector);
        marketplace.listPool(poolId, 0, 1000, 1, 100, 0, 0);
    }

    // ============ Purchase Tests ============

    function test_Purchase() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.prank(investor1);
        marketplace.purchase(poolId, 10);

        // Check investor received tokens
        assertEq(pool.balanceOf(investor1, poolId), 10);

        // Check payment (100 USDC per token + 2% fee = 102 * 10 = 1020 USDC)
        uint256 expectedPayment = (100 * 10 ** 6 * 10) + ((100 * 10 ** 6 * 10 * 200) / 10000);
        assertEq(usdc.balanceOf(treasury) - treasuryBalanceBefore, expectedPayment);
    }

    function test_CalculatePrice() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        (uint256 subtotal, uint256 fee, uint256 total) = marketplace.calculatePrice(poolId, 10);

        assertEq(subtotal, 1000 * 10 ** 6); // 10 * $100 = $1000
        assertEq(fee, 20 * 10 ** 6); // 2% of $1000 = $20
        assertEq(total, 1020 * 10 ** 6); // $1000 + $20 = $1020
    }

    function test_RevertPurchaseUnverifiedBuyer() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        usdc.mint(unverifiedUser, INITIAL_BALANCE);
        vm.prank(unverifiedUser);
        usdc.approve(address(marketplace), type(uint256).max);

        vm.prank(unverifiedUser);
        vm.expectRevert(
            abi.encodeWithSelector(Marketplace.BuyerNotVerified.selector, unverifiedUser)
        );
        marketplace.purchase(poolId, 10);
    }

    function test_RevertPurchaseBelowMinimum() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 5, 100, 0, 0); // min 5 tokens

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.BelowMinPurchase.selector, poolId, 5));
        marketplace.purchase(poolId, 3);
    }

    function test_RevertPurchaseAboveMaximum() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 50, 0, 0); // max 50 tokens

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.ExceedsMaxPurchase.selector, poolId, 50));
        marketplace.purchase(poolId, 100);
    }

    function test_RevertPurchaseExceedsSupply() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 100, 1, 0, 0, 0); // max supply 100

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.ExceedsMaxSupply.selector, poolId, 100));
        marketplace.purchase(poolId, 150);
    }

    function test_RevertPurchaseNotListed() public {
        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.PoolNotListed.selector, 999));
        marketplace.purchase(999, 10);
    }

    function test_RevertPurchaseSaleNotStarted() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        uint256 futureTime = block.timestamp + 1 days;
        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, futureTime, 0);

        vm.prank(investor1);
        vm.expectRevert(
            abi.encodeWithSelector(Marketplace.SaleNotStarted.selector, poolId, futureTime)
        );
        marketplace.purchase(poolId, 10);
    }

    function test_RevertPurchaseSaleEnded() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        uint256 endTime = block.timestamp + 1 hours;
        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, endTime);

        // Fast forward past end time
        vm.warp(endTime + 1);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.SaleEnded.selector, poolId, endTime));
        marketplace.purchase(poolId, 10);
    }

    // ============ Batch Purchase Tests ============

    function test_PurchaseBatch() public {
        vm.startPrank(admin);
        uint256 poolId1 = pool.createPool("ipfs://QmTest1", 1000, true);
        uint256 poolId2 = pool.createPool("ipfs://QmTest2", 1000, true);
        marketplace.listPool(poolId1, 100 * 10 ** 6, 1000, 1, 100, 0, 0);
        marketplace.listPool(poolId2, 50 * 10 ** 6, 1000, 1, 100, 0, 0);
        vm.stopPrank();

        uint256[] memory poolIds = new uint256[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        vm.prank(investor1);
        marketplace.purchaseBatch(poolIds, amounts);

        assertEq(pool.balanceOf(investor1, poolId1), 10);
        assertEq(pool.balanceOf(investor1, poolId2), 20);
    }

    // ============ Admin Tests ============

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(admin);
        marketplace.setTreasury(newTreasury);

        assertEq(marketplace.treasury(), newTreasury);
    }

    function test_SetPlatformFee() public {
        vm.prank(admin);
        marketplace.setPlatformFee(300); // 3%

        assertEq(marketplace.platformFeeBps(), 300);
    }

    function test_RevertSetPlatformFeeTooHigh() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(Marketplace.FeeTooHigh.selector, 1500, 1000)
        );
        marketplace.setPlatformFee(1500); // 15% > 10% max
    }

    function test_Pause() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        vm.prank(admin);
        marketplace.pause();

        vm.prank(investor1);
        vm.expectRevert();
        marketplace.purchase(poolId, 10);
    }

    function test_CanPurchase() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        (bool canBuy, string memory reason) = marketplace.canPurchase(poolId, investor1, 10);
        assertTrue(canBuy);
        assertEq(reason, "");

        (bool canBuyUnverified, string memory reasonUnverified) = marketplace.canPurchase(
            poolId,
            unverifiedUser,
            10
        );
        assertFalse(canBuyUnverified);
        assertEq(reasonUnverified, "User not verified");
    }

    function test_GetUserPurchases() public {
        vm.prank(admin);
        uint256 poolId = pool.createPool("ipfs://QmTest", 1000, true);

        vm.prank(admin);
        marketplace.listPool(poolId, 100 * 10 ** 6, 1000, 1, 100, 0, 0);

        vm.prank(investor1);
        marketplace.purchase(poolId, 10);

        assertEq(marketplace.getUserPurchases(poolId, investor1), 10);
    }
}
