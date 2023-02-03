// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import {NFTAuction} from "../../../src/0.8.18/NFTAuction.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {BaseTest} from "../Base.t.sol";

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

        skip(3601);

        vm.startPrank(BOB);
        nftAuction.bid{value: 0.6 ether}(aliceAuctionId);
        vm.stopPrank();
    }

    function test_bid_ClaimAuction() public {
        skip(84600);

        vm.startPrank(BOB);
        nftAuction.claim(aliceAuctionId);
        vm.stopPrank();

        // asset bid has been transfered
        assertEq(ALICE.balance, 100.6 ether);
        // asset NFT has been transfered
        assertEq(mockNFTA.ownerOf(aliceTokenId), address(BOB));
    }

    function test_RevertWhenClaimTooEarly() public {
        vm.startPrank(BOB);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_ClaimTooEarly()"));
        nftAuction.claim(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenClaimNotHighestBidder() public {
        skip(84600);

        vm.startPrank(CAROL);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_ClaimNotHighestBidder()"));
        nftAuction.claim(aliceAuctionId);

        vm.stopPrank();
    }

    function test_RevertWhenClaimDone() public {
        skip(84600);

        vm.startPrank(BOB);

        nftAuction.claim(aliceAuctionId);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_ClaimDone()"));
        nftAuction.claim(aliceAuctionId);

        vm.stopPrank();
    }
}
