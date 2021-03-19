// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../NFTMarketplace.sol";
contract MarketplaceBuyingContractMock {
    NFTMarketplace public marketplaceContract;
    constructor(NFTMarketplace _marketplaceContract) public {
        marketplaceContract = _marketplaceContract;
    }
    function confirmOffer(uint256 _tokenId) external payable {
        marketplaceContract.confirmOffer{value: msg.value}(_tokenId);
    }
}
