// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../NFTMarketplace.sol";

contract NFTMarketplaceMock is NFTMarketplace {
    uint256 public nowOverride;

    constructor(
        NonFiggyblesAccessControls _accessControls,
        INonFiggyblesNFT _NonFiggyblesNft,
        address payable _platformReserveAddress
    )
    NFTMarketplace(_accessControls, _NonFiggyblesNft, _platformReserveAddress)
    public {}

    function setNowOverride(uint256 _now) external {
        nowOverride = _now;
    }

    function _getNow() internal override view returns (uint256) {
        return nowOverride;
    }
}
