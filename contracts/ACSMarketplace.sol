// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ACSMarketplace is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using ERC165Checker for address;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address payable public immutable feeAccount; // the account that recieves fees
    uint public feePercent; // the fee percentage on sales 1: 100, 50: 5000, 100: 10000

    constructor(uint _feePercent) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }
     
    struct MarketItem {
        ListingStatus status;
        uint itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }
    
    mapping(uint256 => MarketItem) private idToMarketItem;
    
    event MarketItemCreated (
        uint indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );
    
    event MarketItemSold (
        uint indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price
    );    
    
    
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
        ) public nonReentrant {
            require(price > 0, "Price must be greater than 0");
            
            _itemIds.increment();
            uint256 itemId = _itemIds.current();
  
            idToMarketItem[itemId] =  MarketItem(
                ListingStatus.Active,
                itemId,
                nftContract,
                tokenId,
                payable(msg.sender),
                payable(address(0)),
                price,
                false
            );
            
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
                
            emit MarketItemCreated(
                itemId,
                nftContract,
                tokenId,
                msg.sender,
                address(0),
                price,
                false
            );
        }
        
    function createMarketSale(address nftContract, uint256 itemId) public payable nonReentrant {
        uint price = idToMarketItem[itemId].price;
        uint tokenId = idToMarketItem[itemId].tokenId;
        MarketItem storage item = idToMarketItem[itemId];
        address seller = idToMarketItem[itemId].seller;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        require(!item.sold, "This Sale has alredy finnished");
        require(item.status == ListingStatus.Active, "Listing is not active");
        emit MarketItemSold(
            itemId,
            tokenId,
            seller,
            msg.sender,
            price
            );
        uint256 feeAmount = feePercent * price / 10000;
        // transfer the (item price - royalty amount - fee amount) to the seller
        item.seller.transfer(price - feeAmount);

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        _itemsSold.increment();

        item.status = ListingStatus.Sold;
        item.owner = payable(msg.sender);
        item.sold = true;
    }
        
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _itemIds.current();
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Cancel Sale
    function cancelSale(uint _itemId) public {
        MarketItem storage item = idToMarketItem[_itemId];

        require(msg.sender == item.seller, "Only seller can cancel listing");
        require(item.status == ListingStatus.Active, "Listing is not active");
       
        item.status = ListingStatus.Cancelled;

        IERC721(item.nftContract).transferFrom(address(this), msg.sender, item.tokenId);
    }

    //only owner
    function setFeePercent(uint _feePercent) public onlyOwner {
        feePercent = _feePercent;
    }
  
    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call {
            value: address(this).balance
        }("");
        require(success, "not owner you can't withdraw");
    }      
}
