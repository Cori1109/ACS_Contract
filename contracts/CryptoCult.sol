// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// @title:      Crypto Cult
// @twitter:    https://twitter.com/CryptoCult
// @url:        https://www.cryptocult.com/

/*
 * █▀▀ █▀█ █▄█ █▀█ ▀█▀ █▀█   █▀▀ █ █ █   ▀█▀
 * █▄▄ █▀▄ ░█░ █▀▀ ░█░ █▄█   █▄▄ █▄█ █▄▄ ░█░
 */

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract CryptoCult is ERC721A, Ownable, ReentrancyGuard {
    using Address for address;
    using MerkleProof for bytes32[];

    // ===== Variables =====
    string public baseTokenURI;
    uint256[] public mintPrice = [0.06 ether, 0.09 ether];
    uint256 public collectionSize = 10000;
    uint256 public additionalNumber = 500;
    uint256[] public maxItemsPerWallet = [1, 3];
    uint256 private additionalCnt = 0;

    bool public whitelistMintPaused = true;
    bool public publicMintPaused = true;
    bool public AdditionalMintPaused = true;

    bytes32 whitelistMerkleRoot;

    mapping(address => uint256) public whitelistMintedAmount;
    mapping(address => uint256) public publicMintedAmount;

    // ===== Constructor =====
    constructor() ERC721A("Crypto Cult", "CRC", 10) {}

    // ===== Modifier =====
    function _onlySender() private view {
        require(msg.sender == tx.origin);
    }

    modifier onlySender {
        _onlySender();
        _;
    }

    // ===== Whitelist mint =====
    function preMint(bytes32[] memory proof) external payable onlySender nonReentrant {
        require(!whitelistMintPaused, "Whitelist mint is paused");
        require(
            isAddressWhitelisted(proof, msg.sender),
            "You are not eligible for a whitelist mint"
        );

        uint256 amount = _getMintAmount(0, msg.value);

        require(
            whitelistMintedAmount[msg.sender] + amount <= maxItemsPerWallet[0],
            "Minting amount exceeds allowance per wallet"
        );

        whitelistMintedAmount[msg.sender] += amount;

        _mintWithoutValidation(msg.sender, amount);
    }

    // ===== Public mint =====
    function publicMint() external payable onlySender nonReentrant {
        require(!publicMintPaused, "Public mint is paused");

        uint256 amount = _getMintAmount(1, msg.value);

        require(
            publicMintedAmount[msg.sender] + amount <= maxItemsPerWallet[1],
            "Minting amount exceeds allowance per wallet"
        );

        publicMintedAmount[msg.sender] += amount;
        _mintWithoutValidation(msg.sender, amount);
    }

    // ===== Additional mint =====
    function additionalMint() external payable onlySender nonReentrant {
        require(!AdditionalMintPaused, "Additional mint is paused");
        uint256 remainder = msg.value % mintPrice[1];
        require(remainder == 0, "Send a divisible amount of eth");

        uint256 amount = msg.value / mintPrice[1];
        require(amount > 0, "Amount to mint is 0");
        require((additionalCnt + amount) <= additionalNumber, "Sold out!");
        additionalCnt += amount;
        _safeMint(msg.sender, amount);
    }

    // ===== Helper =====
    function _getMintAmount(uint256 _case, uint256 value) internal view returns (uint256) {
        uint256 remainder = value % mintPrice[_case];
        require(remainder == 0, "Send a divisible amount of eth");

        uint256 amount = value / mintPrice[_case];
        require(amount > 0, "Amount to mint is 0");
        require(
            (totalSupply() + amount - additionalCnt) <= collectionSize - additionalNumber,
            "Sold out!"
        );
        return amount;
    }

    function _mintWithoutValidation(address to, uint256 amount) internal {
        require((totalSupply() + amount - additionalCnt) <= collectionSize - additionalNumber, "Sold out!");
        _safeMint(to, amount);
    }

    function isAddressWhitelisted(
        bytes32[] memory proof,
        address _address
    ) public view returns (bool) {
        return proof.verify(whitelistMerkleRoot, keccak256(abi.encodePacked(_address)));
    }

    // ===== Setter (owner only) =====

    function setPublicMintPaused(bool _publicMintPaused) external onlyOwner {
        publicMintPaused = _publicMintPaused;
    }

    function setWhitelistMintPaused(bool _whitelistMintPaused)
        external
        onlyOwner
    {
        whitelistMintPaused = _whitelistMintPaused;
    }

    function setAdditionalMintPaused(bool _AdditionalMintPaused) external onlyOwner {
        AdditionalMintPaused = _AdditionalMintPaused;
    }

    function setAdditionalNumber(uint256 _additionalNumber)
        external
        onlyOwner
    {
        require(_additionalNumber > 0, "Must bigger than 0!");
        require(_additionalNumber < collectionSize, "At least Collection Size!");
        additionalNumber = _additionalNumber;
    }

    function setWhitelistMintMerkleRoot(bytes32 _whitelistMerkleRoot)
        external
        onlyOwner
    {
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }

    function setMintPrice(uint256[] memory _mintPrice) external onlyOwner {
        for (uint256 i = 0; i < 2; i++) {
          mintPrice[i] = _mintPrice[i];
        }
    }

    function setMaxItemsPerWallet(uint256[] memory _maxItemsPerWallet) external onlyOwner {
        for (uint256 i = 0; i < 2; i++) {
          maxItemsPerWallet[i] = _maxItemsPerWallet[i];
        }        
    }

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // ===== Withdraw to owner =====
    function withdrawAll() external onlyOwner onlySender nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to send ether");
    }

    // ===== View =====
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }

    function walletOfOwner(address address_) public virtual view returns (uint256[] memory) {
        uint256 _balance = balanceOf(address_);
        uint256[] memory _tokens = new uint256[] (_balance);
        uint256 _index;
        uint256 _loopThrough = totalSupply();
        for (uint256 i = 0; i < _loopThrough; i++) {
            bool _exists = _exists(i);
            if (_exists) {
                if (ownerOf(i) == address_) { _tokens[_index] = i; _index++; }
            }
            else if (!_exists && _tokens[_balance - 1] == 0) { _loopThrough++; }
        }
        return _tokens;
    }
}
