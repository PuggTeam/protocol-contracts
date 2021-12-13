pragma solidity ^0.7.6;
pragma abicoder v2;

import "../tokens/contracts/erc-721/ERC721Base.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract PuggNFT is ERC721Base {
    using SafeMath for uint256;

    event CreatePuggNFT(address owner, string name, string symbol);
    //event SetInfo(address indexed operator, uint tokenID, uint cardId, uint rate);

    function __PuggNFT_init(string memory _name, string memory _symbol, string memory baseURI, string memory contractURI) external initializer {
        _setBaseURI(baseURI);
        __ERC721Lazy_init_unchained();
        __RoyaltiesV2Upgradeable_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Ownable_init_unchained();
        __ERC721Burnable_init_unchained();
        __Mint721Validator_init_unchained();
        __HasContractURI_init_unchained(contractURI);
        __ERC721_init_unchained(_name, _symbol);
        emit CreatePuggNFT(_msgSender(), _name, _symbol);
    }
    uint256[50] private __gap;

    mapping(uint => string) public        tokenIdTypeMap;    //tokenId => cardType
    // struct CardInfo {
    //     uint cardId;
    //     uint rate;
    // }

    // mapping(uint => uint) public    allCardInfo;    //tokenId => cardUI

    // function getCardRate(uint tokenID) public view returns(uint, uint) {
    //     return (allCardInfo[tokenID].cardId, allCardInfo[tokenID].rate);
    // }

    function setInfo(uint tokenID, string cardtype) public {
        require(isApprovedForAll(owner(), _msgSender()), "sender is not Approved for all");
        tokenIdTypeMap[tokenID] = cardtype;
        emit SetInfo(_msgSender(), tokenID, cardId, rate);
    }
}