// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

interface INFTAuction {
    function create(IERC721 _nftContract, uint256 _nftTokenId, uint256 _minBid, uint256 _startAt, uint256 _endAt)
        external
        returns (uint256 auctionId);

    function bid(uint256 _auctionId) external payable;

    function claim(uint256 _auctionId) external;
}
