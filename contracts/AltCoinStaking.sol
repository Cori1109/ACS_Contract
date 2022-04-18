// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// @title:      AltCoinStaking
// @twitter:    https://twitter.com/Altcoinstaking
// @url:        https://altcoinstaking.io/

/*
 *  ▄▀▀▄ █    ▀▀█▀▀   ▄▀▀▄ ▄▀▀▄ ▀█▀ █▄  █   ▄▀▀▀ ▀▀█▀▀ ▄▀▀▄ █  ▄▀ ▀█▀ █▄  █ ▄▀▀▄
 *  █▄▄█ █      █     █    █  █  █  █ █ █   ▀▄▄    █   █▄▄█ █▄▀    █  █ █ █ █ ▄▄
 *  █  █ █      █     █  ▄ █  █  █  █ ▀▄█      █   █   █  █ █ ▀▄   █  █ ▀▄█ █  █
 *  ▀  ▀ ▀▀▀▀   ▀      ▀▀   ▀▀  ▀▀▀ ▀   ▀   ▀▀▀    ▀   ▀  ▀ ▀   ▀ ▀▀▀ ▀   ▀  ▀▀
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// deploy on the Polygon Network
contract AltCoinStaking is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // constants
    uint256 private MAX_ELEMENTS = 10000;
    uint256 public maxItemsPerWallet = 10;
    uint256[] private LEVEL_MAX = [0, 3800, 6300, 8200, 9200, 10000];
    uint256[] private LEVEL_POINT = [100, 400, 800, 1600, 3200];
    uint256[] private LEVEL_EARNED = [82, 336, 688, 1408, 2880];
    // uint256[] public LEVEL_PRICE = [1000 ether, 4000 ether, 8000 ether, 16000 ether, 32000 ether]; // 1 ether means 1 MATIC
    uint256[] private LEVEL_PRICE = [0.01 ether, 0.04 ether, 0.08 ether, 0.16 ether, 0.32 ether];
    uint256[] private _tokenIdTracker = [0, 3800, 6300, 8200, 9200];
    address public teamWallet;

    // state variable
    bool public MINTING_PAUSED = true;
    bool public REWARDING_PAUSED = true;
    string public baseTokenURI;

    Counters.Counter private _holderCnt;
    struct RewardData {
        uint256 point;
        uint256 reward;
    }
    
    mapping(uint256 => address) private claimedList;
    mapping(uint256 => address) private holderList;
    mapping(address => RewardData) private rewardPoint;

    constructor(address _teamWallet) ERC721("Alt Coin Staking", "ACS"){
        teamWallet = _teamWallet;
    }

    // ===== Modifier =====
    function _onlySender() private view {
        require(msg.sender == tx.origin);
    }

    modifier onlySender {
        _onlySender();
        _;
    }

    // ===== Mint =====
    function mint(uint256[] memory numberOfTokens) external payable onlySender nonReentrant {
        require(!MINTING_PAUSED, "Minting is not active");
        require(totalSupply() < MAX_ELEMENTS, "All tokens have been minted");

        uint256 numOt = 0;
        uint256 price = 0;
        uint256 point = 0;
        for (uint256 i = 0; i < 5; i++) {
            require(_tokenIdTracker[i] < LEVEL_MAX[i + 1], "Please fix the mint amount per level");
            numOt += numberOfTokens[i];
            price += numberOfTokens[i] * LEVEL_PRICE[i];
            point += LEVEL_EARNED[i] * numberOfTokens[i];
        }

        require(totalSupply() + numOt < MAX_ELEMENTS, "Purchase would exceed max supply");
        require(balanceOf(msg.sender) + numOt <= maxItemsPerWallet, "Purchase exceeds max allowed");
        require(price <= msg.value, "Payment amount is not sufficient");

        rewardPoint[msg.sender].point += point;
        if (balanceOf(msg.sender) == 0) {
            holderList[_holderCnt.current()] = msg.sender;
            _holderCnt.increment();
        }
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < numberOfTokens[i]; j++) {
                _tokenIdTracker[i]++;
                claimedList[_tokenIdTracker[i]] = msg.sender; // should be checked
                _safeMint(msg.sender, _tokenIdTracker[i]);
            }
        }
    }

    // ===== GetTotalRewardPoint (Internal) =====

    function getTotalPoint() internal view returns (uint256) {
        uint256 _totalPoint = 0;
        for (uint256 i = 0; i < 5; i++) {
            _totalPoint += LEVEL_POINT[i] * (_tokenIdTracker[i] - LEVEL_MAX[i]);
        }
        return _totalPoint;
    }

    // ===== Deposit =====

    function deposit() external payable onlySender nonReentrant {
        require(msg.value > 0, "Payment amount is not sufficient");
        require(totalSupply() > 0, "No NFTs have been minted");
    }

    // ===== Setter (owner only) =====

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

    function setMintPrice(uint256[] memory _mintPrice) external onlyOwner {
        for (uint256 i =0; i < 5; i++) {
            LEVEL_PRICE[i] = _mintPrice[i];
        }
    }

    function setLevelPoint(uint256[] memory _point) external onlyOwner {
        for (uint256 i =0; i < 5; i++) {
            LEVEL_POINT[i] = _point[i];
        }
    }

    function setLevelPercent(uint256[] memory _percent) external onlyOwner {
        for (uint256 i =0; i < 5; i++) {
            LEVEL_EARNED[i] = _percent[i];
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

    // ===== Distribute by owner =====
    function distributeAll() external onlyOwner onlySender nonReentrant {
        require(!REWARDING_PAUSED, "Distributing is not active");
        require(_holderCnt.current() > 0, "No NFT holder exist");
        require(address(this).balance > 0, "Insufficient funds");
        uint256 _totalPoint = getTotalPoint();
        for (uint256 i = 0; i < _holderCnt.current(); i++) {
            rewardPoint[holderList[i]].reward = address(this).balance * rewardPoint[holderList[i]].point / _totalPoint;
            payable(holderList[i]).transfer(rewardPoint[holderList[i]].reward);
        }
        payable(teamWallet).transfer(address(this).balance);
    }

    // ===== View =====
    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function mintedCnt() public view returns (uint256[] memory) {
        uint256[] memory _mintedcnt = new uint256[] (5);
        for (uint256 i = 0; i < 5; i++) {
            _mintedcnt[i] = _tokenIdTracker[i] - LEVEL_MAX[i];
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

    function monthlyReward(address _address) public view returns (uint256) {
        return rewardPoint[_address].reward;
    }

    function mintPrice() public view returns (uint256[] memory) {
        uint256[] memory _price = new uint256[] (5);
        for (uint256 i = 0; i < 5; i++) {
            _price[i] = LEVEL_PRICE[i];
        }
        return _price;
    }

    function walletOfOwner(address address_) public virtual view returns (uint256[] memory) {
        uint256 _balance = balanceOf(address_);
        uint256[] memory _tokens = new uint256[] (_balance);
        uint256 _index;
        for (uint256 j = 0; j < 5; j++) {
            for (uint256 i = LEVEL_MAX[j] + 1; i <= _tokenIdTracker[j]; i++) {
                if (claimedList[i] == address_) { _tokens[_index] = i; _index++; }
            }
        }
        return _tokens;
    }
}
