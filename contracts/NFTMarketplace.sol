// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AccessControl/NonFiggyblesAccessControls.sol";
import "./NFT/INonFiggyblesNFT.sol";
/**
 * @notice Marketplace contract for Non Figgybles NFTs
 */
contract NFTMarketplace is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address payable;
    /// @notice Event emitted only on construction. To be used by indexers
    event NFTMarketplaceContractDeployed();
    event PauseToggled(
        bool isPaused
    );
    event OfferCreated(
        uint256 indexed tokenId
    );
    event UpdateAccessControls(
        address indexed accessControls
    );
    event UpdateMarketplacePlatformFee(
        uint256 platformFee
    );
    event UpdateMarketplaceCreatorFee(
        uint256 creatorFee
    );
    event UpdateOfferPrimarySalePrice(
        uint256 indexed tokenId,
        uint256 primarySalePrice
    );
    event UpdatePlatformFeeRecipient(
        address payable platformFeeRecipient
    );
    event OfferPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 primarySalePrice
    );
    event OfferCancelled(
        uint256 indexed tokenId
    );
    /// @notice Parameters of a marketplace offer
    struct Offer {
        uint256 primarySalePrice;
        uint256 startTime;
        uint256 endTime;
    }
    /// @notice Intagram NFT Token ID -> Offer Parameters
    mapping(uint256 => Offer) public offers;
    /// @notice NonFiggybles NFT - the only NFT that can be offered in this contract
    INonFiggyblesNFT public NonFiggyblesNFT;
    /// @notice responsible for enforcing admin access
    NonFiggyblesAccessControls public accessControls;
    /// @notice platform fee that will be sent to the platformFeeRecipient, assumed to always be to 1 decimal place i.e. 20 = 2.0%
    uint256 public platformFee = 20;
    /// @notice creator fee that will be sent to the creator of NFT
    uint256 public creatorFee = 100;
    /// @notice where to send platform fee funds to
    address payable public platformFeeRecipient;
    /// @notice for pausing marketplace functionalities
    bool public isPaused;

    modifier whenNotPaused() {
        require(!isPaused, "Function is currently paused");
        _;
    }
    receive() external payable {
    }   
    constructor(
        NonFiggyblesAccessControls _accessControls,
        INonFiggyblesNFT _NonFiggyblesNFT,
        address payable _platformFeeRecipient
    ) public {
        require(address(_accessControls) != address(0), "NFTMarketplace: Invalid Access Controls");
        require(address(_NonFiggyblesNFT) != address(0), "NFTMarketplace: Invalid NFT");
        require(_platformFeeRecipient != address(0), "NFTMarketplace: Invalid Platform Fee Recipient");
        accessControls = _accessControls;
        NonFiggyblesNFT = _NonFiggyblesNFT;
        platformFeeRecipient = _platformFeeRecipient;

        emit NFTMarketplaceContractDeployed();
    }
    /**
     @notice Creates a new offer for a given NonFiggybles NFT
     @dev Only the owner of a NFT can create an offer and must have ALREADY approved the contract
     @dev In addition to owning the NFT, the sender also has to have the MINTER or ADMIN role.
     @dev End time for the offer will be in the future, at a time from now till expiry duration
     @dev There cannot be a duplicate offer created
     @param _tokenId token ID of the NFT being offered to marketplace
     @param _primarySalePrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function createOffer(
        uint256 _tokenId,
        uint256 _primarySalePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) external whenNotPaused {
        // Ensure caller has privileges
        require(
            accessControls.hasMinterRole(_msgSender()) || accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace.createOffer: Sender must have the minter or admin role"
        );
        // Ensure the token ID does exists
        require(NonFiggyblesNFT.exists(_tokenId), "NFTMarketplace.createOffer: TokenID does not exist");
        // Check owner of the token ID is the owner and approved
        require(
            NonFiggyblesNFT.ownerOf(_tokenId) == _msgSender() && NonFiggyblesNFT.isApproved(_tokenId, address(this)),
            "NonFiggyblesNFTAuction.createOffer: Not owner and or contract not approved"
        );
        _createOffer(
            _tokenId,
            _primarySalePrice,
            _startTimestamp,
            _endTimestamp
        );
    }
    /**
     @notice Buys an open offer with eth
     @dev Only callable when the offer is open
     @dev Bids from smart contracts are prohibited - a user must buy directly from their address
     @dev Contract must have been approved on the buy offer previously
     @dev The sale must have started (start time) to make a successful buy
     @dev The sale must be before end time
     @param _tokenId token ID of the NFT being offered
     */
    function confirmOffer(uint256 _tokenId) external payable nonReentrant whenNotPaused {
        // Check the offers to see if this is a valid
        require(_msgSender().isContract() == false, "NFTMarketplace.confirmOffer: No contracts permitted");

        Offer storage offer = offers[_tokenId];
        uint256 maxShare = 1000;
        // Eth amount that user deposit
        uint256 bidValue = msg.value;
        // Ensure this contract is still approved to move the token
        require(NonFiggyblesNFT.isApproved(_tokenId, address(this)), "NFTMarketplace.confirmOffer: offer not approved");
        require(_getNow() >= offer.startTime && _getNow() <= offer.endTime, "NFTMarketplace.confirmOffer: Purchase outside of the offer window");
        require(bidValue >= offer.primarySalePrice, "NFTMarketplace.confirmOffer: Failed to supply funds");

        // Send platform fee in ETH to the platform fee recipient
        uint256 platformFeeInETH = bidValue.mul(platformFee).div(maxShare);
        (bool platformTransferSuccess,) = platformFeeRecipient.call{value : platformFeeInETH}("");
        require(platformTransferSuccess, "NFTMarketplace.confirmOffer: Failed to send platform fee");

        uint256 creatorFeeInETH = 0;
        // Send creator fee in ETH if seller is not creator of NFT.
        if(NonFiggyblesNFT.postCreators(_tokenId) != NonFiggyblesNFT.ownerOf(_tokenId))
        {
            creatorFeeInETH = bidValue.mul(creatorFee).div(maxShare);
            (bool creatorTransferSuccess,) = NonFiggyblesNFT.postCreators(_tokenId).call{value : creatorFeeInETH}("");
            require(creatorTransferSuccess, "NFTMarketplace.confirmOffer: Failed to send creator fee");
        }
        // Send remaining to seller in ETH
        (bool sellerTransferSuccess,) = NonFiggyblesNFT.ownerOf(_tokenId).call{value : bidValue.sub(platformFeeInETH).sub(creatorFeeInETH)}("");
        require(sellerTransferSuccess, "NFTMarketplace.confirmOffer: Failed to send the seller their royalties");

        // update the primary sale price for the NFT with new eth amount.
        NonFiggyblesNFT.setPrimarySalePrice(_tokenId, bidValue);

        // Transfer the token to the purchaser
        NonFiggyblesNFT.safeTransferFrom(NonFiggyblesNFT.ownerOf(_tokenId), msg.sender, _tokenId);
        
        //Remove offer
        delete offers[_tokenId];
        emit OfferPurchased(_tokenId, _msgSender(), bidValue);
    }
    /**
     @notice Cancels an inflight and un-resulted offer
     @dev Only admin
     @param _tokenId Token ID of the NFT being offered
     */
    function cancelOffer(uint256 _tokenId) external nonReentrant {
        // Admin only resulting function
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "NFTMarketplace.cancelOffer: Sender must be admin or minter contract"
        );
        // Check valid and not resulted
        Offer storage offer = offers[_tokenId];
        require(offer.primarySalePrice != 0, "NFTMarketplace.cancelOffer: Offer does not exist");
        require(_getNow() <= offer.endTime, "NFTMarketplace.cancelOffer: Offer already closed");
        // Remove offer
        delete offers[_tokenId];
        emit OfferCancelled(_tokenId);
    }

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace.toggleIsPaused: Sender must be admin");
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice Update the marketplace fee
     @dev Only admin
     @param _platformFee New marketplace fee
     */
    function updateMarketplacePlatformFee(uint256 _platformFee) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace.updateMarketplacePlatformFee: Sender must be admin");
        platformFee = _platformFee;
        emit UpdateMarketplacePlatformFee(_platformFee);
    }

    /**
     @notice Update the creator fee
     @dev Only admin
     @param _creatorFee New creator fee
     */
    function updateMarketplaceCreatorFee(uint256 _creatorFee) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace.updateMarketplaceCreatorFee: Sender must be admin");
        creatorFee = _creatorFee;
        emit UpdateMarketplaceCreatorFee(_creatorFee);
    }

    /**
     @notice Update the offer primary sale price
     @dev Only admin
     @param _tokenId Token ID of the NFT being offered
     @param _primarySalePrice New price
     */
    function updateOfferPrimarySalePrice(uint256 _tokenId, uint256 _primarySalePrice) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace.updateOfferPrimarySalePrice: Sender must be admin");
        
        offers[_tokenId].primarySalePrice = _primarySalePrice;
        emit UpdateOfferPrimarySalePrice(_tokenId, _primarySalePrice);
    }

    /**
     @notice Method for updating the access controls contract used by the NFT
     @dev Only admin
     @param _accessControls Address of the new access controls contract (Cannot be zero address)
     */
    function updateAccessControls(NonFiggyblesAccessControls _accessControls) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace.updateAccessControls: Sender must be admin"
        );
        require(address(_accessControls) != address(0), "NFTMarketplace.updateAccessControls: Zero Address");
        accessControls = _accessControls;
        emit UpdateAccessControls(address(_accessControls));
    }

    /**
     @notice Method for updating platform fee address
     @dev Only admin
     @param _platformFeeRecipient payable address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace.updatePlatformFeeRecipient: Sender must be admin"
        );
        require(_platformFeeRecipient != address(0), "NFTMarketplace.updatePlatformFeeRecipient: Zero address");
        platformFeeRecipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    ///////////////
    // Accessors //
    ///////////////
    /**
     @notice Method for getting all info about the offer
     @param _tokenId Token ID of the NFT being offered
     */
    function getOffer(uint256 _tokenId)
    external
    view
    returns (uint256 _primarySalePrice, uint256 _startTime, uint256 _endTime) {
        Offer storage offer = offers[_tokenId];
        return (
            offer.primarySalePrice,
            offer.startTime,
            offer.endTime
        );
    }


    /////////////////////////
    // Internal and Private /
    /////////////////////////
    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    /**
     @notice Private method doing the heavy lifting of creating an offer
     @param _tokenId token ID of the NFT being offered to marketplace
     @param _primarySalePrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function _createOffer(
        uint256 _tokenId,
        uint256 _primarySalePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) private {
        // Ensure a token cannot be re-listed if previously successfully sold
        require(offers[_tokenId].startTime == 0, "NFTMarketplace.createOffer: Cannot duplicate current offer");
        // Setup the new offer
        offers[_tokenId] = Offer({
            primarySalePrice : _primarySalePrice,
            startTime : _startTimestamp,
            endTime : _endTimestamp
        });
        emit OfferCreated(_tokenId);
    }

    /**
     * @notice Reclaims ETH, drains all ETH sitting on the smart contract
     * @dev The instant buy feature means technically, ETH should never sit on contract.
     * @dev Only access controls admin can access
     */
    function reclaimETH() external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace.reclaimETH: Sender must be admin"
        );
        msg.sender.transfer(address(this).balance);
    }
}