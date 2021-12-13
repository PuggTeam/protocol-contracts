pragma solidity ^0.7.6;
pragma abicoder v2;

interface IPuggNFTSale {

    event SetBase_token(address _erc20);
    event SetPoints_token(address _erc20);
    event CreateCard(string cardtype, uint price, uint points, uint rate, uint stake_rate);
    event DelCard(string cardtype, bool active);
    event SetCard(string cardtype, uint fee, uint points, uint rate, uint stake_rate);
    event MintAndTransfer_721(string cardtype, string code, uint tokenId, address to, uint fee, uint card_bnb, uint token_bnb);
    event Withdraw_n(address indexed operator, string code, uint8 _type, uint256 amount);
    event Withdraw_p(address indexed operator, uint256 amount);
    event DefaultApproval(address indexed operator, bool hasApproval);
    event SetPercent_m(address indexed operator, uint m);
    event SetPercent_n(address indexed operator, uint n);
    event SetPercent_x(address indexed operator, uint x);
    event SetPercent_y(address indexed operator, uint y);
    event SetPercent_s(address indexed operator, uint s);
    event SetExecutor(address indexed operator, address account);
    event SetRouter(address indexed operator, address router);
    event SetMode(address indexed operator, uint8 mode);

    struct card {
        uint        price;  //unit is bnb
        uint        points; //calit 1 000 /2
        uint        rate;   // 1 bub : rate calite
        uint        stake_rate;   //stake rate
        bool        active;
        bool        existed;
    }

    function setExecutor(address account) external;

    function setMode(uint8 mode) external;

    function setPercent_m(uint m) external;

    function setPercent_n(uint n) external;

    function setPercent_x(uint x) external;

    function setPercent_y(uint y) external;

    function setPercent_s(uint s) external;

    function setBase_token(address _token) external;

    function setPoints_token(address _token) external;

    function getCard(string memory cardtype) external returns(card memory);

    function createCard(string memory cardtype, uint price, uint points, uint rate, uint stake_rate) external;

    function delCard(string memory cardtype, bool active) external;

    function setCard(string memory _type, uint price, uint points, uint rate, uint stake_rate) external;

    function pause() external;

    function unpause() external;

    function mintAndTransfer_721(string memory cardtype, string memory code, address to, string memory tokenURI) external payable;

    function withdraw_p() external;
}
