// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {INFTAuction} from "./interfaces/INFTAuction.sol";

contract NFTAuction is ERC721Holder, INFTAuction {
    // errors
    error NFTAuction_CreateBadParameters();
    error NFTAuction_BidBySeller();
    error NFTAuction_BidRepeatly();
    error NFTAuction_BidTooEarly();
    error NFTAuction_BidTooLate();
    error NFTAuction_BidTooLowThanMin();
    error NFTAuction_BidLowThanHighest();
    error NFTAuction_ClaimTooEarly();
    error NFTAuction_ClaimDone();
    error NFTAuction_ClaimNotHighestBidder();

    // states
    uint256 private auctionIndex;

    struct Auction {
        address payable seller;
        address nftContract;
        uint256 nftTokenId;
        uint256 minBid;
        uint256 startAt; // timestamp
        uint256 endAt; // timestamp
        bool isClaimed;
        uint256 highestBid;
        uint256 highestBidAt; // timestamp
        address payable highestBidder;
    }

    mapping(uint256 => Auction) public auctions;

    // events
    event CreateAuction(
        address seller, address nftContract, uint256 nftTokenId, uint256 minBid, uint256 startAt, uint256 endAt
    );
    event BidAuction(uint256 auctionId, address bidder, uint256 bid, uint256 bidAt);

    constructor() {}

    function create(IERC721 _nftContract, uint256 _nftTokenId, uint256 _minBid, uint256 _startAt, uint256 _endAt)
        external
        returns (uint256)
    {
        _nftContract.safeTransferFrom(msg.sender, address(this), _nftTokenId);

        if (_startAt >= _endAt) {
            revert NFTAuction_CreateBadParameters();
        }

        uint256 auctionId = ++auctionIndex;

        auctions[auctionId].seller = payable(msg.sender);
        auctions[auctionId].nftContract = address(_nftContract);
        auctions[auctionId].nftTokenId = _nftTokenId;
        auctions[auctionId].minBid = _minBid;
        auctions[auctionId].startAt = _startAt;
        auctions[auctionId].endAt = _endAt;
        auctions[auctionId].isClaimed = false;

        emit CreateAuction(msg.sender, address(_nftContract), _nftTokenId, _minBid, _startAt, _endAt);

        return auctionId;
    }

    function bid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];

        if (auction.seller == msg.sender) {
            revert NFTAuction_BidBySeller();
        }

        if (auction.highestBidder == msg.sender) {
            revert NFTAuction_BidRepeatly();
        }

        if (auction.startAt > block.timestamp) {
            revert NFTAuction_BidTooEarly();
        }

        if (auction.endAt < block.timestamp) {
            revert NFTAuction_BidTooLate();
        }

        if (msg.value < auction.highestBid) {
            revert NFTAuction_BidLowThanHighest();
        }

        if ((msg.value - auction.highestBid) < auction.minBid) {
            revert NFTAuction_BidTooLowThanMin();
        }

        // transfer previous bid back
        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        // set new highest bidder
        auction.highestBid = msg.value;
        auction.highestBidAt = block.timestamp;
        auction.highestBidder = payable(msg.sender);

        emit BidAuction(_auctionId, msg.sender, msg.value, block.timestamp);
    }

    function claim(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp < auction.endAt) {
            revert NFTAuction_ClaimTooEarly();
        }

        if (auction.highestBidder != msg.sender) {
            revert NFTAuction_ClaimNotHighestBidder();
        }

        if (auction.isClaimed) {
            revert NFTAuction_ClaimDone();
        }

        // set claimed
        auction.isClaimed = true;

        // transfer bid to seller
        payable(auction.seller).transfer(auction.highestBid);

        // transfer NFT to highest bidder
        IERC721(auction.nftContract).safeTransferFrom(address(this), msg.sender, auction.nftTokenId);
    }
}
