// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interfaces/INFTAuction.sol";

contract NFTAuction is ERC721Holder, INFTAuction {
    // errors
    error NFTAuction_CreateBadParameters();

    // states
    uint256 private auctionIndex;

    struct Auction {
        address seller;
        address nftContract;
        uint256 nftTokenId;
        uint256 minBid;
        uint256 startAt; // timestamp
        uint256 endAt; // timestamp
        bool isClaimed;
        uint256 highestBid;
        uint256 highestBidAt; // timestamp
        address highestBidder;
    }

    mapping(uint256 => Auction) public auctions;

    // events
    event CreateAuction(
        address seller, address nftContract, uint256 nftTokenId, uint256 minBid, uint256 startAt, uint256 endAt
    );

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

        auctions[auctionId].seller = msg.sender;
        auctions[auctionId].nftContract = address(_nftContract);
        auctions[auctionId].nftTokenId = _nftTokenId;
        auctions[auctionId].minBid = _minBid;
        auctions[auctionId].startAt = _startAt;
        auctions[auctionId].endAt = _endAt;
        auctions[auctionId].isClaimed = false;

        emit CreateAuction(msg.sender, address(_nftContract), _nftTokenId, _minBid, _startAt, _endAt);

        return auctionId;
    }

    function bid(uint256 _auctionId) external payable {}

    function claim(uint256 _auctionId) external {}
}
