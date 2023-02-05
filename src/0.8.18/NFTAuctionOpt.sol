// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {WordCodec} from "./helpers/WordCodec.sol";
import {INFTAuction} from "./interfaces/INFTAuction.sol";

contract NFTAuctionOpt is ERC721Holder, INFTAuction {
    using WordCodec for bytes32;

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
    uint256 private constant BIDDER_OFFSET = 96;
    uint256 private constant BID_AT_OFFSET = 65;
    uint256 private constant BID_AT_BIT_LENGTH = 31;
    uint256 private constant BID_OFFSET = 0;
    uint256 private constant BID_BIT_LENGTH = 65;

    struct Auction {
        address payable seller;
        address nftContract;
        uint256 nftTokenId;
        uint256 minBid;
        uint256 startAt; // timestamp
        uint256 endAt; // timestamp
        bool isClaimed;
        // [ bidder address | bid at |   bid   ]
        // [    160 bit     | 31 bit | 65 bits ]
        // [ MSB                           LSB ]
        // the limitation is bid can only less than equal 36.893488147419103231 ether
        // because the is maximum size for uint256 in 65 bits
        bytes32 highest;
    }

    mapping(uint256 => Auction) private auctions;

    // events
    event CreateAuction(
        address seller, address nftContract, uint256 nftTokenId, uint256 minBid, uint256 startAt, uint256 endAt
    );
    event BidAuction(uint256 auctionId, address bidder, uint256 bid, uint256 bidAt);
    event ClaimAuction(uint256 auctionId, address bidder, uint256 claimAt);

    constructor() {}

    function _getHighest(bytes32 _word) internal pure returns (address payable, uint256, uint256) {
        address bidder = _word.decodeAddress(BIDDER_OFFSET);
        uint256 bidAt = _word.decodeUint(BID_AT_OFFSET, BID_AT_BIT_LENGTH);
        uint256 bidPrice = _word.decodeUint(BID_OFFSET, BID_BIT_LENGTH);

        return (payable(bidder), bidAt, bidPrice);
    }

    function auctionInfo(uint256 _auctionId)
        public
        view
        returns (address payable, address, uint256, uint256, uint256, uint256, bool, address payable, uint256, uint256)
    {
        Auction memory auction = auctions[_auctionId];

        address bidder = auction.highest.decodeAddress(BIDDER_OFFSET);
        uint256 bidAt = auction.highest.decodeUint(BID_AT_OFFSET, BID_AT_BIT_LENGTH);
        uint256 bidPrice = auction.highest.decodeUint(BID_OFFSET, BID_BIT_LENGTH);

        return (
            payable(auction.seller),
            auction.nftContract,
            auction.nftTokenId,
            auction.minBid,
            auction.startAt,
            auction.endAt,
            auction.isClaimed,
            payable(bidder),
            bidAt,
            bidPrice
        );
    }

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

        (address highestBidder,, uint256 highestBid) = _getHighest(auction.highest);
        if (highestBidder == msg.sender) {
            revert NFTAuction_BidRepeatly();
        }

        if (auction.startAt > block.timestamp) {
            revert NFTAuction_BidTooEarly();
        }

        if (auction.endAt < block.timestamp) {
            revert NFTAuction_BidTooLate();
        }

        if (msg.value < highestBid) {
            revert NFTAuction_BidLowThanHighest();
        }

        if ((msg.value - highestBid) < auction.minBid) {
            revert NFTAuction_BidTooLowThanMin();
        }

        // transfer previous bid back
        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid);
        }

        // set new highest bidder
        auction.highest = auction.highest.insertAddress(msg.sender, BIDDER_OFFSET);
        auction.highest = auction.highest.insertUint(block.timestamp, BID_AT_OFFSET, BID_AT_BIT_LENGTH);
        auction.highest = auction.highest.insertUint(msg.value, BID_OFFSET, BID_BIT_LENGTH);

        emit BidAuction(_auctionId, msg.sender, msg.value, block.timestamp);
    }

    function claim(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp < auction.endAt) {
            revert NFTAuction_ClaimTooEarly();
        }

        (address highestBidder,, uint256 highestBid) = _getHighest(auction.highest);
        if (highestBidder != msg.sender) {
            revert NFTAuction_ClaimNotHighestBidder();
        }

        if (auction.isClaimed) {
            revert NFTAuction_ClaimDone();
        }

        // set claimed
        auction.isClaimed = true;

        // transfer bid to seller
        payable(auction.seller).transfer(highestBid);

        // transfer NFT to highest bidder
        IERC721(auction.nftContract).safeTransferFrom(address(this), msg.sender, auction.nftTokenId);

        emit ClaimAuction(_auctionId, msg.sender, block.timestamp);
    }
}
