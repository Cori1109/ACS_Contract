// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// @title:      Zen Zebra
// @twitter:    https://twitter.com/ZebZebra
// @url:        https://www.zenzebra.io/

/*
 * ▀▀█ ███ █▀█   ▀▀█ ███ █▄▄ █▀█ █▀█
 * █▄▄ █▄▄ █ █   █▄▄ █▄▄ █▄█ █▀▄ █▀█
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// deploy on the Polygon Network
contract ZenZebra is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // constants
    uint256 private MAX_ELEMENTS = 9999;
    uint256 public maxItemsPerWallet = 10;
    uint256[5][3] private UNITS_BATCH;
    uint256[5] private LEVEL_POINT = [0, 1, 2, 4, 15];
    uint256[6] private LEVEL_PERCENT = [0, 75, 80, 85, 90, 100];
    // uint256[5] public LEVEL_PRICE = [150 ether, 400 ether, 800 ether, 1600 ether, 5000 ether]; // 1 ether means 1 MATIC
    uint256[5] private LEVEL_PRICE = [0.015 ether, 0.04 ether, 0.08 ether, 0.16 ether, 0.5 ether];
    uint256[5][3] private _tokenIdTracker;
    address public teamWallet;
    address public donationWallet;
    uint256 private reward_bal = 0;

    // state variable
    uint256 public CURRENT_STAGE = 0;
    bool public MINTING_PAUSED = true;
    bool public REWARDING_PAUSED = true;
    string public baseTokenURI;

    Counters.Counter private _holderCnt;
    struct RewardData {
        uint256 point;
        uint256 rewards;
    }
    
    mapping(uint256 => address) private claimedList;
    mapping(uint256 => address) private holderList;
    mapping(address => RewardData) private rewardPoint;

    constructor(address _teamWallet, address _donationWallet) ERC721("Zen Zebra", "Zen"){
        teamWallet = _teamWallet;
        donationWallet = _donationWallet;
        UNITS_BATCH[0] = [2923, 3173, 3273, 3323, 3333];
        UNITS_BATCH[1] = [5966, 6266, 6416, 6616, 6666];
        UNITS_BATCH[2] = [8666, 9066, 9366, 9766, 9999];
        _tokenIdTracker[0] = [0, 2923, 3173, 3273, 3323];
        _tokenIdTracker[1] = [3333, 5966, 6266, 6416, 6616];
        _tokenIdTracker[2] = [6666, 8666, 9066, 9366, 9766];
    }

    // ===== Modifier =====
    function _onlySender() private view {
        require(msg.sender == tx.origin);
    }

    modifier onlySender {
        _onlySender();
        _;
    }

    event SetAttribute(uint256 _tokenId, uint256 _attribute);
    event Mint(address _address, uint256 _tokenId);
    event ClaimRewards(address _address, uint256 _amount);

    // ===== Deposit =====
    function deposit() external payable onlySender nonReentrant {
        require(msg.value > 0, "Payment amount is not sufficient");
        require(totalSupply() > 0, "No NFTs have been minted");
        uint256 _rewards = msg.value;
        payable(teamWallet).transfer(_rewards / 2);
        payable(donationWallet).transfer(_rewards / 4);
        reward_bal += _rewards / 4;
        uint256 _totalPoint = getTotalPoint();
        for (uint256 i = 0; i < _holderCnt.current(); i++) {
            rewardPoint[holderList[i]].rewards += _rewards * rewardPoint[holderList[i]].point / (_totalPoint * 4);
        }
    }

    // ===== Mint =====
    function mint(uint256 _attribute) external payable onlySender nonReentrant {
        require(!MINTING_PAUSED, "Minting is not active");
        require(totalSupply() < MAX_ELEMENTS, "All tokens have been minted");
        uint256 _level = 5;

        for (uint256 i = 0; i < 5; i++) {
            if (msg.value == LEVEL_PRICE[i]) {
                _level = i;
            }
        }
        require(_level < 5, "Please send the exact NFT price!");
        require(_tokenIdTracker[CURRENT_STAGE][_level] < UNITS_BATCH[CURRENT_STAGE][_level], "All tokens of the current level have been minted");
        require(balanceOf(msg.sender) < maxItemsPerWallet, "Purchase exceeds max allowed");
        if (_level > 0) {
            require(_attribute < 50, "Input the correct attribute");
            emit SetAttribute(_tokenIdTracker[CURRENT_STAGE][_level], _attribute);
        }

        if (balanceOf(msg.sender) == 0) {
            holderList[_holderCnt.current()] = msg.sender;
            _holderCnt.increment();
        }
        
        rewardPoint[msg.sender].point += LEVEL_POINT[_level] * LEVEL_PERCENT[_level];
        _tokenIdTracker[CURRENT_STAGE][_level]++;
        claimedList[_tokenIdTracker[CURRENT_STAGE][_level]] = msg.sender; // should be checked
        _safeMint(msg.sender, _tokenIdTracker[CURRENT_STAGE][_level]);
        emit Mint(msg.sender, _tokenIdTracker[CURRENT_STAGE][_level]);
    }

    // ===== GetTotalRewardPoint (Internal) =====

    function getTotalPoint() internal view returns (uint256) {
        uint256 _totalPoint = 0;
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 1; j < 5; j++) {
                _totalPoint += LEVEL_POINT[j] * LEVEL_PERCENT[5] * (_tokenIdTracker[i][j] - UNITS_BATCH[i][j-1]);
            }
        }
        return _totalPoint;
    }

    // ===== Setter (owner only) =====

    function setStage(uint256 _stage) external onlyOwner {
        require(_stage < 3, "Must be 0 to 2");
        CURRENT_STAGE = _stage;
    }

    function setMintPaused(bool _MintPaused) external onlyOwner{
        MINTING_PAUSED = _MintPaused;
    }

    function setRewardingPaused(bool _Paused) external onlyOwner{
        REWARDING_PAUSED = _Paused;
    }

    function setMaxItemsPerWallet(uint256 _maxItemsPerWallet) external onlyOwner{
        maxItemsPerWallet = _maxItemsPerWallet;
    }

    function setTeamWalletAddress(address _address) external onlyOwner {
        teamWallet = _address;
    } 

    function setDonationWalletAddress(address _address) external onlyOwner {
        donationWallet = _address;
    } 

    function setMintPrice(uint256[] memory _mintPrice) external onlyOwner {
        for (uint256 i =0; i < 5; i++) {
            LEVEL_PRICE[i] = _mintPrice[i];
        }
    }

    function setLevelPercent(uint256[] memory _percent) external onlyOwner {
        for (uint256 i =0; i < 5; i++) {
            LEVEL_PERCENT[i] = _percent[i];
        }
    }

    function setBaseTokenURI(string calldata _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // ===== Withdraw to owner =====
    function withdrawAll() external onlyOwner onlySender nonReentrant {
        require(address(this).balance > 0, "Insufficient funds");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to send MATIC");
    }

    function purchase() external onlyOwner onlySender nonReentrant {
        require(address(this).balance > reward_bal, "Insufficient funds");
        uint256 _bal = address(this).balance - reward_bal;
        payable(teamWallet).transfer(_bal / 2);
        (bool success, ) = msg.sender.call{value: _bal / 2}("");
        require(success, "Failed to send MATIC");
    }

    // ===== Distribute by owner =====
    function claimRewards() external onlySender nonReentrant {
        require(!REWARDING_PAUSED, "Claiming is not active");
        uint256 _rewards = rewardPoint[msg.sender].rewards;
        require(_rewards > 0, "You haven't rewards to claim");
        require(address(this).balance >= reward_bal, "Insufficient funds");
        payable(msg.sender).transfer(_rewards);
        emit ClaimRewards(msg.sender, _rewards);
        rewardPoint[msg.sender].rewards = 0;
    }

    // ===== View =====
    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function mintedCnt(uint256 _stage) public view returns (uint256[] memory) {
        uint256[] memory _mintedcnt = new uint256[] (5);
        for (uint256 i = 0; i < 5; i++) {
            uint256 _bottom = 0;
            if (i > 0) {
                _bottom = UNITS_BATCH[_stage][i-1];
            }
            else if (i == 0 && _stage > 0) {
                _bottom = UNITS_BATCH[_stage-1][4];
            }
            _mintedcnt[i] = _tokenIdTracker[_stage][i] - _bottom;
        }
        return _mintedcnt;
    }

    function getHolderList() public view returns (address[] memory) {
        address[] memory _holder = new address[] (_holderCnt.current());
        for (uint256 i = 0; i < _holderCnt.current(); i++) {
            _holder[i] = holderList[i];
        }
        return _holder;
    }

    function getRewards(address _address) public view returns (uint256) {
        return rewardPoint[_address].rewards;
    }

    function mintPrice() public view returns (uint256[] memory) {
        uint256[] memory _price = new uint256[] (5);
        for (uint256 i = 0; i < 5; i++) {
            _price[i] = LEVEL_PRICE[i];
        }
        return _price;
    }
}
