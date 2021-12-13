pragma solidity ^0.7.6;
pragma abicoder v2;

interface IPuggPool {

    event Recharge(address indexed operator, uint amount);
    event Start(address indexed operator, uint time);
    event CreateNode(address indexed operator, uint tokenID, string code);
    event StakeToken(address indexed operator, uint tokenID, string code, uint amount);

    struct StakeInfo {
        uint        amount;
        uint        balance;
        uint        lastupdate;
        bool        created;
    }

    struct NodeInfo {
        address     account;
        uint[3]     params; //0 - staking_amount, 1 - staking_accounts, 2 - weight
    }

    function getNextday() external view returns(uint);

    function getPledgeDaysLength() external view returns(uint);

    function getPledgeDays() external view returns(uint[] memory);

    function getRelease(uint _daytime) external view returns(uint);

    function sortNodes() external view returns (string[] memory);

    function getNodesRank(string memory code) external returns (uint);

    function recharge(uint amount) external;

    function isStart() external view returns (bool);

    function start(uint time) external;

    function isCodeExist (string memory code) external view returns(bool);

    function createNode(uint tokenID, string memory code) external;

    function stakeToken(uint tokenID, string memory code, uint amount) external;

    function withdraw_pledgeToken(uint amount) external;

    function withdraw_releaseToken(uint amount) external;
}