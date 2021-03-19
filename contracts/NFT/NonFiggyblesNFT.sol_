// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

/**
 * @title NonFiggybles NFT a.k.a. parent NFTs
 * @dev Issues ERC-721 tokens 
 */
contract NonFiggyblesNFT is ERC721("Non Figgybles NFT", "NFN") {

    // @notice event emitted upon construction of this contract, used to bootstrap external indexers
    event NonFiggyblesNFTContractDeployed();

    // @notice event emitted when token URI is updated
    event NonFiggyblesTokenUriUpdate(
        uint256 indexed _tokenId,
        string _tokenUri
    );

    // @notice event emitted when a tokens primary sale occurs
    event TokenPrimarySalePriceSet(
        uint256 indexed _tokenId,
        uint256 _salePrice
    );

    /// @dev current max tokenId
    uint256 public tokenIdPointer;

    /// @dev TokenID -> Post Creator address
    mapping(uint256 => address) public postCreators;

    /// @dev TokenID -> Primary Ether Sale Price in Wei
    mapping(uint256 => uint256) public primarySalePrice;

    /**
     @notice Constructor
     */
    constructor() public {
        emit NonFiggyblesNFTContractDeployed();
    }

    /**
     @notice Mints a NonFiggyblesNFT AND when minting to a contract checks if the beneficiary is a 721 compatible
     @dev Only senders with either the minter or smart contract role can invoke this method
     @param _beneficiary Recipient of the NFT
     @param _tokenUri URI for the token being minted
     @param _postCreator Instagram Post Creator - will be required for issuing royalties from secondary sales
     @return uint256 The token ID of the token that was minted
     */
    function mint(address _beneficiary, string calldata _tokenUri, address _postCreator) external returns (uint256) {
        // Valid args
        _assertMintingParamsValid(_tokenUri, _postCreator);

        tokenIdPointer = tokenIdPointer.add(1);
        uint256 tokenId = tokenIdPointer;

        // Mint token and set token URI
        _safeMint(_beneficiary, tokenId);
        _setTokenURI(tokenId, _tokenUri);

        postCreators[tokenId] = _postCreator;

        return tokenId;
    }

    /**
     @notice Burns a NonFiggyblesNFT
     @dev Only the owner or an approved sender can call this method
     @param _tokenId the token ID to burn
     */
    function burn(uint256 _tokenId) external {
        address operator = _msgSender();
        require(
            ownerOf(_tokenId) == operator || isApproved(_tokenId, operator),
            "NonFiggyblesNFT.burn: Only garment owner or approved"
        );
        // Destroy token mappings
        _burn(_tokenId);

        delete postCreators[_tokenId];
        delete primarySalePrice[_tokenId];
    }



    //////////
    // Admin /
    //////////

    /**
     @notice Updates the token URI of a given token
     @dev Only admin or smart contract
     @param _tokenId The ID of the token being updated
     @param _tokenUri The new URI
     */
    function setTokenURI(uint256 _tokenId, string calldata _tokenUri) external {
        _setTokenURI(_tokenId, _tokenUri);
        emit NonFiggyblesTokenUriUpdate(_tokenId, _tokenUri);
    }

    /**
     @notice Records the Ether price that a given token was sold for (in WEI)
     @dev Only admin or a smart contract can call this method
     @param _tokenId The ID of the token being updated
     @param _salePrice The primary Ether sale price in WEI
     */
    function setPrimarySalePrice(uint256 _tokenId, uint256 _salePrice) external {
        require(_exists(_tokenId), "NonFiggyblesNFT.setPrimarySalePrice: Token does not exist");
        require(_salePrice > 0, "NonFiggyblesNFT.setPrimarySalePrice: Invalid sale price");

        // Only set it once
        if (primarySalePrice[_tokenId] == 0) {
            primarySalePrice[_tokenId] = _salePrice;
            emit TokenPrimarySalePriceSet(_tokenId, _salePrice);
        }
    }

    /////////////////
    // View Methods /
    /////////////////

    /**
     @notice View method for checking whether a token has been minted
     @param _tokenId ID of the token being checked
     */
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    /**
     * @dev checks the given token ID is approved either for all or the single token ID
     */
    function isApproved(uint256 _tokenId, address _operator) public view returns (bool) {
        return isApprovedForAll(ownerOf(_tokenId), _operator) || getApproved(_tokenId) == _operator;
    }

    /////////////////////////
    // Internal and Private /
    /////////////////////////

    /**
     @notice Checks that the URI is not empty and the post creator is a real address
     @param _tokenUri URI supplied on minting
     @param _postCreator Address supplied on minting
     */
    function _assertMintingParamsValid(string calldata _tokenUri, address _postCreator) pure internal {
        require(bytes(_tokenUri).length > 0, "NonFiggyblesNFT._assertMintingParamsValid: Token URI is empty");
        require(_postCreator != address(0), "NonFiggyblesNFT._assertMintingParamsValid: Post createErrors is zero address");
    }
}
