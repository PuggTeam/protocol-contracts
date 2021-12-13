pragma solidity ^0.7.6;
pragma abicoder v2;

interface IPuggNFTSale {

    event SetBase_token(address _erc20);
    event SetPoints_token(address _erc20);
    //event CreateNode(string[] codes, address[] accounts);
    event CreateCard(string _type, uint price, uint points, uint rate);
    event DelCard(string _type, bool active);
    event SetCard(string _type, uint fee, uint points, uint rate);
    event MintAndTransfer_721(uint card_Id, string code, uint tokenId, address to, uint fee, uint points);
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

    // struct NodeInfo {
    //     address     account;
    //     uint        balance;
    //     uint        points;
    //     uint8       state; //1 active
    // }

    struct card {
        uint        price;  //unit is bnb
        uint        points; //calit 1 000 /2
        uint        rate;   //pledg rate
        bool        active;
        bool        existed;
    }

    function setExecutor(address account) external;

    function setMode(uint8 mode) external;

    function setRouter(address router) external;

    function setPercent_m(uint m) external;

    function setPercent_n(uint n) external;

    function setPercent_x(uint x) external;

    function setPercent_y(uint y) external;

    function setPercent_s(uint s) external;

    function setDefaultApproval(address operator, bool hasApproval) external;

    function setBase_token(address _token) external;

    function setPoints_token(address _token) external;

    function getCardCount() external returns(uint);

    function getCardIds() external returns(uint[] memory);

    function getCard(uint id) external returns(card memory);

    function createCard(uint id, uint price, uint points, uint rate) external;

    function addCard(uint id, uint fee, uint points, string memory tokenURI) external;

    function delCard(uint id, bool active) external;

    function setCard(uint id, uint fee, uint points, string memory tokenURI) external;

    function isApprovedForAll(address operator) external view returns (bool);

    //function getNodeInfo(string memory code) external view returns(NodeInfo memory);

    function getNodeCodes() external view returns(string[] memory);

    function isCodeExist (string memory code) external view returns(bool);

    function createNode(string[] memory code, address[] memory accounts) external;

    function pause() external;

    function unpause() external;

    function mintAndTransfer_721(uint cardId, string memory code, address to) external;

    function withdraw_n(string memory code, uint8 _type) external;

    function withdraw_p() external;
}
