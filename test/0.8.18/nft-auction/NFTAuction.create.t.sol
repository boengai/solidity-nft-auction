// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import {INFTAuction} from "../../../src/0.8.18/interfaces/INFTAuction.sol";
import {NFTAuction} from "../../../src/0.8.18/NFTAuction.sol";
import {NFTAuctionOpt} from "../../../src/0.8.18/NFTAuctionOpt.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {BaseTest} from "../Base.t.sol";

abstract contract BaseNFTAuctionCreateTest is BaseTest {
    MockERC721 public mockNFTA;
    INFTAuction public nftAuction;

    function _baseSetUp() internal {
        mockNFTA = new MockERC721('NFT A', 'NFTA');
    }

    function test_create_CreateAuction() public {
        uint256 aliceTokenId = mockNFTA.mintTo(ALICE);
        uint256 bobTokenId = mockNFTA.mintTo(BOB);
        uint256 auctionId;

        vm.startPrank(ALICE);
        mockNFTA.setApprovalForAll(address(nftAuction), true);
        auctionId = nftAuction.create(mockNFTA, aliceTokenId, 0.5 ether, 1, 165789);
        vm.stopPrank();
        assertEq(mockNFTA.ownerOf(aliceTokenId), address(nftAuction));
        assertEq(auctionId, 1);

        vm.startPrank(BOB);
        mockNFTA.setApprovalForAll(address(nftAuction), true);
        auctionId = nftAuction.create(mockNFTA, bobTokenId, 0.5 ether, 1, 165789);
        vm.stopPrank();
        assertEq(mockNFTA.ownerOf(bobTokenId), address(nftAuction));
        assertEq(auctionId, 2);
    }

    function test_RevertWhenSendingBadDate() public {
        uint256 tokenId = mockNFTA.mintTo(ALICE);

        vm.startPrank(ALICE);
        mockNFTA.setApprovalForAll(address(nftAuction), true);

        vm.expectRevert(abi.encodeWithSignature("NFTAuction_CreateBadParameters()"));
        nftAuction.create(mockNFTA, tokenId, 0.5 ether, 665789, 165789);

        vm.stopPrank();
    }

    function test_RevertWhenUserHasntApproveNFTYet() public {
        uint256 tokenId = mockNFTA.mintTo(ALICE);

        vm.startPrank(ALICE);

        vm.expectRevert(bytes("ERC721: caller is not token owner or approved"));
        nftAuction.create(mockNFTA, tokenId, 0.5 ether, 1, 165789);

        vm.stopPrank();
    }

    function test_RevertWhenUserNotOwner() public {
        uint256 tokenId = mockNFTA.mintTo(ALICE);

        vm.startPrank(ALICE);

        vm.expectRevert(bytes("ERC721: caller is not token owner or approved"));
        nftAuction.create(mockNFTA, tokenId, 0.5 ether, 1, 165789);

        vm.stopPrank();
    }
}

contract NFTAuctionCreateTest is BaseNFTAuctionCreateTest {
    function setUp() public {
        nftAuction = new NFTAuction();
        _baseSetUp();
    }
}

contract NFTAuctionOptCreateTest is BaseNFTAuctionCreateTest {
    function setUp() public {
        nftAuction = new NFTAuctionOpt();
        _baseSetUp();
    }
}
