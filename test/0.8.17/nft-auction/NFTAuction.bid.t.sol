// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "../../../src/0.8.17/NFTAuction.sol";
import "../mocks/MockERC721.sol";
import "../Base.t.sol";

contract NFTAuctionBidTest is BaseTest {
    MockERC721 public mockNFTA;
    NFTAuction public nftAuction;
    uint256 public aliceTokenId;
    uint256 public aliceAuctionId;

    function setUp() public {
        payable(ALICE).transfer(100 ether);
        payable(BOB).transfer(100 ether);
        payable(CAROL).transfer(100 ether);
        payable(DAN).transfer(100 ether);

        mockNFTA = new MockERC721('NFT A', 'NFTA');
        nftAuction = new NFTAuction();
        aliceTokenId = mockNFTA.mintTo(ALICE);

        vm.startPrank(ALICE);
        mockNFTA.setApprovalForAll(address(nftAuction), true);
        aliceAuctionId = nftAuction.create(mockNFTA, aliceTokenId, 0.5 ether, 3600, 84600);
        vm.stopPrank();
    }

    function test_bid_BidAuction() public {
        skip(3601);

        vm.startPrank(BOB);
        nftAuction.bid{value: 0.6 ether}(aliceAuctionId);
        vm.stopPrank();

        // assert lastest bid
        (,,,,,,, uint256 bobBidded,, address bobAddress) = nftAuction.auctions(aliceAuctionId);
        assertEq(0.6 ether, bobBidded); // bid price
        assertEq(address(BOB), bobAddress); // bidder
    }

    function test_bid_MultiBidAuction() public {
        skip(3601);

        vm.startPrank(BOB);
        nftAuction.bid{value: 0.6 ether}(aliceAuctionId);
        vm.stopPrank();

        // assert lastest bid
        (,,,,,,, uint256 bobBidded,, address bobAddress) = nftAuction.auctions(aliceAuctionId);
        assertEq(0.6 ether, bobBidded); // bid price
        assertEq(address(BOB), bobAddress); // bidder

        vm.startPrank(CAROL);
        nftAuction.bid{value: 1.1 ether}(aliceAuctionId);
        vm.stopPrank();

        // assert Bob's balance is refuned
        // because contract someone hits the highest bid
        // then the contract will return ETH to previous highest bidder
        assertEq(BOB.balance, 100 ether);
        // assert lastest bid
        (,,,,,,, uint256 carolBidded,, address carolAddress) = nftAuction.auctions(aliceAuctionId);
        assertEq(1.1 ether, carolBidded); // bid price
        assertEq(address(CAROL), carolAddress); // bidder

        vm.startPrank(DAN);
        nftAuction.bid{value: 1.72 ether}(aliceAuctionId);
        vm.stopPrank();

        // assert Carol's balance is refuned
        assertEq(CAROL.balance, 100 ether);
        // assert lastest bid
        (,,,,,,, uint256 danlBidded,, address danlAddress) = nftAuction.auctions(aliceAuctionId);
        assertEq(1.72 ether, danlBidded); // bid price
        assertEq(address(DAN), danlAddress); // bidder

        vm.startPrank(BOB);
        nftAuction.bid{value: 3 ether}(aliceAuctionId);
        vm.stopPrank();

        // assert Dan's balance is refuned
        assertEq(DAN.balance, 100 ether);
        // assert lastest bid
        (,,,,,,, uint256 boblBidded2,, address boblAddress2) = nftAuction.auctions(aliceAuctionId);
        assertEq(3 ether, boblBidded2); // bid price
        assertEq(address(BOB), boblAddress2); // bidder
    }

    function test_RevertWhenBidBySeller() public {
        vm.startPrank(ALICE);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_BidBySeller()"));
        nftAuction.bid{value: 1 ether}(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenBidTooEarly() public {
        vm.startPrank(BOB);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_BidTooEarly()"));
        nftAuction.bid{value: 1 ether}(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenBidRepeatly() public {
        skip(3600);

        vm.startPrank(BOB);

        nftAuction.bid{value: 1 ether}(aliceAuctionId);

        vm.stopPrank();

        vm.startPrank(BOB);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_BidRepeatly()"));
        nftAuction.bid{value: 2 ether}(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenBidTooLate() public {
        skip(84600);

        vm.startPrank(BOB);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_BidTooLate()"));
        nftAuction.bid{value: 1 ether}(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenBidLowThanHighest() public {
        skip(3600);

        vm.startPrank(BOB);
        nftAuction.bid{value: 1 ether}(aliceAuctionId);
        vm.stopPrank();

        vm.startPrank(CAROL);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_BidLowThanHighest()"));
        nftAuction.bid{value: 0.9 ether}(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenBidTooLowThanMin() public {
        skip(3600);

        vm.startPrank(BOB);
        nftAuction.bid{value: 1 ether}(aliceAuctionId);
        vm.stopPrank();

        vm.startPrank(CAROL);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_BidTooLowThanMin()"));
        nftAuction.bid{value: 1.1 ether}(aliceAuctionId);

        vm.stopPrank();
    }
}
