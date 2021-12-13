pragma solidity ^0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interface/IPuggPool.sol";
import "./interface/IPuggNFTSale.sol";
import "./PuggNFT.sol";

contract PuggPool is IPuggPool, OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint;
    uint public constant DURATION = 1 days; // 1 days

    uint public                                             startTime;
    uint public                                             firstDay;                   // first day for a1
    uint public                                             totalSupply;
    uint public                                             totalRelease;
    uint public                                             totalPledge;
    mapping(uint => uint)public                             totalPledgeMap;                 //time => totalpledge;
    mapping(uint => uint)public                             totalReleaseMap;                //time => totalRelease
    mapping(address => mapping(uint => mapping(string => StakeInfo))) public userPledgesMap;  //user Pledges  address => timestamp => cardtype => StakeInfo
    mapping(address => uint[]) public                       userPledgeDaysMap;              //user Pledges days[]
    mapping(address => string[]) public                     userPledgeCardsMap;           //user Pledges cardtyps[]
    mapping(address => uint) public                         userUpdateTimeMap;
    mapping(address => mapping(string => bool)) public      hasCardTypesMap;
    mapping(address => mapping(string => bool)) public      hasPledgedMap;
    mapping(string => NodeInfo) public                      userNodeMap;
    string[] public                                         userNodeCodes;
    uint private                                            lastUpdateTime;
    uint public                                             q;
    uint public                                             weight_a;
    uint public                                             weight_b;
    uint public                                             withdrawFineRate;
    address public                                          baseToken;
    address public                                          pugg_nft;
    address public                                          nft_sale;
    uint public                                             node_creating_fee; //create node fee

    modifier checkStart(){
        require(startTime > 0 && block.timestamp >= startTime,"not start");
        _;
    }

    function __initialize(address _ntf, address _base_erc20, address sale, uint _totalSupply, uint _q, uint _node_creating_fee) external initializer {
        require(_q <= 10000, "q must <= 10000");
        __Ownable_init();
        __Pausable_init();
        pugg_nft = _ntf;
        baseToken = _base_erc20;
        nft_sale = sale;
        totalSupply = _totalSupply;
        firstDay = 0;
        totalRelease = 0;
        totalPledge = 0;
        q = _q;
        weight_a = 1;
        weight_b = 1;
        node_creating_fee = _node_creating_fee;
    }

    function setWithdrawFineRate(uint rate) public onlyOwner{
        require(rate <= 10000, "withdrawFineRate value must <= 10000");
        withdrawFineRate = rate;
    }

    function _updateReward(uint next_day) internal checkStart {
        if (totalPledgeMap[next_day] != totalPledge) {
            totalPledgeMap[next_day] = totalPledge;
        }
        //update last day
        if (lastUpdateTime <  next_day.sub(DURATION)) {
            uint _day = next_day.sub(DURATION);
            while (_day >= firstDay && _day >= lastUpdateTime) {
                totalPledgeMap[_day] = totalPledgeMap[lastUpdateTime];
                uint _release = getRelease(_day);
                totalReleaseMap[_day] = _release;
                totalRelease = totalRelease.add(_release);
                _day = _day.sub(DURATION);
            }
            lastUpdateTime = next_day.sub(DURATION);
        }
    }
    //todo safemath
    function _quickSort(string[] memory arr, int left, int right, uint8 index) internal view {
        int i = left;
        int j = right;
        if (i == j) return;
        NodeInfo memory pivot = userNodeMap[arr[uint(left + (right - left) / 2)]];
        while (i <= j) {
            while (userNodeMap[arr[uint(i)]].params[index] > pivot.params[index]) i++;
            while (pivot.params[index] > userNodeMap[arr[uint(j)]].params[index]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            _quickSort(arr, left, j, index);
        if (i < right)
            _quickSort(arr, i, right, index);
    }

    function _max_param(uint8 index) internal view returns(uint) {
        string[] memory codes = new string[](userNodeCodes.length);
        for (uint i = 0; i < userNodeCodes.length; i++) codes[i] = userNodeCodes[i];
        _quickSort(codes, int(0), int(userNodeCodes.length - 1), index);
        return userNodeMap[codes[0]].params[index];
    }

    function _min_param(uint8 index) internal view returns(uint) {
        string[] memory codes = new string[](userNodeCodes.length);
        for (uint i = 0; i < userNodeCodes.length; i++) codes[i] = userNodeCodes[i];
        _quickSort(codes, int(0), int(userNodeCodes.length - 1), index);
        return userNodeMap[codes[userNodeCodes.length - 1]].params[index];
    }

    function _get_Normalized(NodeInfo memory info, uint8 index) internal view returns(uint) {
        uint _max = _max_param(index);
        uint _min = _min_param(index);
        if (_max > _min) {
            return info.params[index].sub(_min).mul(10 ** 18).div(_max.sub(_min));
        }
        return 0;
    }

    function _addPledgeInfo(uint tokenID, uint day, uint amount) internal {
        mapping(uint => mapping(string => StakeInfo)) storage record = userPledgesMap[_msgSender()];
        string memory cardtype = PuggNFT(pugg_nft).tokenIdTypeMap(tokenID);
        uint rate = IPuggNFTSale(nft_sale).getCard(cardtype).stake_rate;
        if (!record[day][cardtype].created) {
            userPledgeDaysMap[_msgSender()].push(day);
            record[day][cardtype].created = true;
        }

        if (!hasCardTypesMap[_msgSender()][cardtype]) {
            userPledgeCardsMap[_msgSender()].push(cardtype);
            hasCardTypesMap[_msgSender()][cardtype] = true;
        }
        
        record[day][cardtype].amount = record[day][cardtype].amount.add(amount);

        //update total pledge
        totalPledge = totalPledge.add(amount.mul(rate).div(10000));
    }

    //todo safemath
    function getNextday() public view override returns(uint) {
        return startTime + ((block.timestamp - startTime) / DURATION + 1) * DURATION;
    }

    function getPledgeDaysLength() public view override returns(uint) {
        return userPledgeDaysMap[_msgSender()].length;
    }

    function getPledgeDays() public view override returns(uint[] memory) {
        return userPledgeDaysMap[_msgSender()];
    }

    function getRelease(uint _daytime) public view override returns(uint) {
        uint a1 = totalSupply.sub(totalSupply.mul(q).div(10000));
        if (_daytime >= firstDay) { //first day n = 1
            uint n_1 = _daytime.sub(firstDay).div(DURATION); // n - 1
            return a1.mul(q ** n_1).div(10000 ** n_1);
        }
        return 0;
    }

    function sortNodes() public view override returns (string[] memory) {
        string[] memory codes = new string[](userNodeCodes.length);
        for (uint i = 0; i < userNodeCodes.length; i++) codes[i] = userNodeCodes[i];
        _quickSort(codes, int(0), int(userNodeCodes.length - 1), 2);
        return codes;
    }

    function getNodesRank(string memory code) public view override returns(uint) {
        string[] memory codes = sortNodes();
        bytes32 _hash = keccak256(bytes(code));
        for (uint i = 0; i < codes.length; i++) {
            if (keccak256(bytes(codes[i])) == _hash) {
                return i+1;
            }
        }
        return 0;
    }

    function isCodeExist (string memory code) public view override returns(bool) {
        return userNodeMap[code].account != address(0);
    }

    function recharge(uint amount) public override {
        if (isStart()) {
            uint next_day = getNextday(); //next day
            _updateReward(next_day);
            totalSupply = totalSupply.sub(totalRelease).add(amount);
            totalRelease = 0;
            firstDay = next_day;
        }
        else {
            totalSupply = totalSupply.sub(totalRelease).add(amount);
        }
        emit Recharge(_msgSender(), amount);
    }

    function isStart() public view override returns(bool) {
        return startTime > 0 && block.timestamp >= startTime;
    } 

    function start(uint time)public override onlyOwner {
        startTime = time;
        firstDay = startTime + DURATION;
        emit Start(_msgSender(), time);
    }

    function createNode(uint tokenID, string memory code) public override{
        require(PuggNFT(pugg_nft).ownerOf(tokenID) == _msgSender(), "tokenID does not belong to sender");
        require(!isCodeExist(code), "code is already exists");
        if (node_creating_fee > 0) {
            IERC20(baseToken).transferFrom(_msgSender(), address(this), node_creating_fee);
        }
        NodeInfo storage info = userNodeMap[code];
        info.account = _msgSender();
        userNodeCodes.push(code);
        emit CreateNode(_msgSender(), tokenID, code);
    }

    function _isneedFine(uint _day) internal returns(bool) {
        return block.timestamp < _day.add(30 days);
    }

    function _updateStakeInfo(uint timestamp, string memory cardtype) internal {
        StakeInfo storage Info = userPledgesMap[_msgSender()][timestamp][cardtype];
        uint nextday = getNextday();
        uint lastupdate = Info.lastupdate;
        uint rate = IPuggNFTSale(nft_sale).getCard(cardtype).stake_rate;
        uint amount = Info.amount.mul(rate).div(10000);
        if (lastupdate < nextday.sub(DURATION)) {
            uint _time = nextday.sub(DURATION);
            while (_time > lastupdate && _time >= timestamp) {
                Info.balance = Info.balance.add(totalReleaseMap[_time].mul(amount).div(totalPledgeMap[_time]));
                _time = _time.sub(DURATION);
            }
            Info.lastupdate = nextday.sub(DURATION);
        }
    }

    function withdraw_pledgeToken(uint timestamp, string memory cardtype) public override checkStart {
        require(userPledgesMap[_msgSender()][timestamp][cardtype].created, "not found StakeInfo");
        _updateStakeInfo(timestamp, cardtype);  //calculate balance
        require(userPledgesMap[_msgSender()][timestamp][cardtype].amount > 0, "pledge amount is empty");
        mapping(uint => mapping(string => StakeInfo)) storage record = userPledgesMap[_msgSender()];
        uint rate = IPuggNFTSale(nft_sale).getCard(cardtype).stake_rate;
        uint real_amount = 0;
        if (_isneedFine(timestamp)) {
            real_amount = record[timestamp][cardtype].amount.sub(record[timestamp][cardtype].amount.mul(withdrawFineRate).div(10000));
        }
        else {
            real_amount = record[timestamp][cardtype].amount;
        }

        // update totalPledge
        totalPledge = totalPledge.sub(record[timestamp][cardtype].amount.mul(rate).div(10000));
        record[timestamp][cardtype].amount = 0;
        uint nextday = getNextday();
        totalPledgeMap[nextday] = totalPledge;
        IERC20(baseToken).transfer(_msgSender(), real_amount);
    }

    function withdraw_releaseToken(uint timestamp, string memory cardtype) public override checkStart {
        require(userPledgesMap[_msgSender()][timestamp][cardtype].created, "not found StakeInfo");
        _updateStakeInfo(timestamp, cardtype);  //calculate balance
        require(userPledgesMap[_msgSender()][timestamp][cardtype].balance > 0, "release amount is empty");
        mapping(uint => mapping(string => StakeInfo)) storage record = userPledgesMap[_msgSender()];
        uint amount = record[timestamp][cardtype].balance;
        record[timestamp][cardtype].balance = 0;
        IERC20(baseToken).transfer(_msgSender(), amount);
    }

    function restakeToken(uint timestamp, string memory cardtype) public override checkStart {
        require(userPledgesMap[_msgSender()][timestamp][cardtype].created, "not found StakeInfo");
        _updateStakeInfo(timestamp, cardtype);
        require(userPledgesMap[_msgSender()][timestamp][cardtype].balance > 0, "release amount is empty");
        uint rate = IPuggNFTSale(nft_sale).getCard(cardtype).stake_rate;
        mapping(uint => mapping(string => StakeInfo)) storage record = userPledgesMap[_msgSender()];

        uint re_amount = record[timestamp][cardtype].balance;
        record[timestamp][cardtype].balance = 0;

        uint nextday = getNextday(); //next day
        if (!record[nextday][cardtype].created) {
            userPledgeDaysMap[_msgSender()].push(nextday);
            record[nextday][cardtype].created = true;
        }
        
        record[nextday][cardtype].amount = record[nextday][cardtype].amount.add(re_amount);
        //update total pledge
        totalPledge = totalPledge.add(re_amount.mul(rate).div(10000));
        totalPledgeMap[nextday] = totalPledge;
    }

    function stakeToken(uint tokenID, string memory code, uint amount) public override checkStart {
        require(PuggNFT(pugg_nft).ownerOf(tokenID) == _msgSender(), "tokenID does not belong to sender");
        require(isCodeExist(code), "code is not exists");
        uint next_day = getNextday(); //next day
        //update user pledge
        _addPledgeInfo(tokenID, next_day, amount);
        //update node
        userNodeMap[code].params[0] = userNodeMap[code].params[0].add(amount);   //todo change to one address counted for multiple nodes
        if (!hasPledgedMap[_msgSender()][code]) { //new account
            hasPledgedMap[_msgSender()][code] = true;
            userNodeMap[code].params[1]  = userNodeMap[code].params[1].add(1);
        }
        // set weight
        userNodeMap[code].params[2] = weight_a * _get_Normalized(userNodeMap[code], 0) + weight_b * _get_Normalized(userNodeMap[code], 1);
        _updateReward(next_day);
        IERC20(baseToken).transferFrom(_msgSender(), address(this), amount);
        emit StakeToken(_msgSender(), tokenID, code, amount);
    }
}
