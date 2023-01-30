// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 public currentTokenId;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function mintTo(address _recipient) public payable returns (uint256) {
        uint256 newItemId = ++currentTokenId;
        _safeMint(_recipient, newItemId);
        return newItemId;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return Strings.toString(id);
    }
}
