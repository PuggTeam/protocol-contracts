pragma solidity ^0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@rarible/royalties/contracts/LibPart.sol";
import "./interface/IPuggNFTSale.sol";
import "./interface/IPuggPool.sol";
import "./interface/IPancakeRouter02.sol";
import "./PuggNFT.sol";

contract PuggNFTSale is IPuggNFTSale, OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;
    address internal constant           CALIT_TOKEN = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant           PANCAKE_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address public                      pugg_nft;
    address public                      pugg_pool;
    address public                      executor; //todo constant?
    address public                      project;
    address public                      base_token;
    address public                      points_token;
    uint public                         cur_token_Id;
    mapping(string => card) public      cards;      // cardtype => cardInfo
    mapping(string => uint) public      nodeBalanceMap;
    mapping(string => uint) public      nodePointsMap;
    uint public                         project_NFTBalance;
    uint public                         project_TokenBalance;
    uint public                         buyback_points;
    uint public                         percent_m; //m% stable coin commission gose to dex buy back
    uint public                         percent_n; //n% stable coin commission gose to project
    uint public                         percent_x; //x% stable coin commission gose to staking pool
    uint public                         percent_y; //y% stable coin commission gose to nodes
    uint public                         percent_s; //s% sales revenue gose to project and (100-s)% sales revenue gose to nodes
    uint8 public                        mode; //0 no list  1 list on dask
    uint256[50] private                 __gap;

    modifier onlyExecutor() {
        require(_msgSender() == executor, "caller is not executor");
        _;
    }

    modifier onlyProject() {
        require(_msgSender() == project, "caller is not project");
        _;
    }

    function __initialize(address _nft, address _base_erc20, address _points_erc20, address _pugg_pool, address _project) external initializer {
        __Ownable_init();
        __Pausable_init();
        pugg_nft = _nft;
        base_token = _base_erc20;
        points_token = _points_erc20;
        pugg_pool = _pugg_pool;
        project = _project;
        cur_token_Id = uint256(uint160(address(this))) << 96;
    }

    function setExecutor(address account) public override onlyOwner {
        executor = account;
        emit SetExecutor(_msgSender(), account);
    }

    function setMode(uint8 _mode) public override onlyOwner {
        mode = _mode;
        emit SetMode(_msgSender(), _mode);
    }

    function setPercent_m(uint m) public override onlyExecutor {
        require(m <= 10000, "percent must between 1 and 10000");
        percent_m = m;
        emit SetPercent_m(_msgSender(), m);
    }

    function setPercent_n(uint n) public override onlyExecutor {
        require(n <= 10000, "percent must between 1 and 10000");
        percent_n = n;
        emit SetPercent_n(_msgSender(), n);
    }

    function setPercent_x(uint x) public override onlyExecutor {
        require(x <= 10000, "percent must between 1 and 10000");
        percent_x = x;
        emit SetPercent_x(_msgSender(), x);
    }
    //todo  onlyExecutor => onlyGovernance
    function setPercent_y(uint y) public override onlyExecutor {
        require(y <= 10000, "percent must between 1 and 10000");
        percent_y = y;
        emit SetPercent_y(_msgSender(), y);
    }

    function setPercent_s(uint s) public override onlyExecutor {
        require(s <= 10000, "percent must between 1 and 10000");
        percent_s = s;
        emit SetPercent_s(_msgSender(), s);
    }

    function setBase_token(address _token) public override onlyOwner {
        base_token = _token;
        emit SetBase_token(_token);
    }

    function setPoints_token(address _token) public override onlyOwner {
        points_token = _token;
        emit SetPoints_token(_token);
    }

    function getCard(string memory _type) public view override returns(card memory){
        return cards[_type];
    }

    function createCard(string memory cardtype, uint price, uint points, uint rate, uint stake_rate) public override onlyOwner {
        require(!cards[cardtype].existed, "card type is already used");
        require(stake_rate >= 10000, "stake_rate must >= 10000");
        cards[cardtype] = card(price, points, rate, stake_rate, true, true);
        emit CreateCard(cardtype, price, points, rate, stake_rate);
    }

    function delCard(string memory _type, bool active) public override onlyOwner {
        require(cards[_type].existed, "card id does not exist");
        card storage info = cards[_type];
        info.active = active;
        emit DelCard(_type, active);
    }

    function setCard(string memory _type, uint price, uint points, uint rate, uint stake_rate) public override onlyOwner {
        require(cards[_type].existed, "card id does not exist");
        require(stake_rate >= 10000, "stake_rate must >= 10000");
        card storage info = cards[_type];
        info.price = price;
        info.points = points;
        info.rate = rate;
        info.stake_rate = stake_rate;
        emit SetCard(_type, price, points, rate, stake_rate);
    }

    function pause() public override onlyOwner {
        _pause();
    }

    function unpause() public override onlyOwner {
        _unpause();
    }

    function convertETHToCAL(uint amountIn) public payable returns(uint[] memory){
        uint deadline = block.timestamp + 15; // using 'now' for convenience, for mainnet pass deadline from frontend!
        return IPancakeRouter02(PANCAKE_ROUTER).swapExactETHForTokens{value:amountIn}(0, getPathForETHtoCAL(), address(this), deadline);
    }

    function getPathForETHtoCAL() private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = IPancakeRouter02(PANCAKE_ROUTER).WETH();
        path[1] = CALIT_TOKEN;
        return path;
    }

    function getPathForCALtoETH() private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = CALIT_TOKEN;
        path[1] = IPancakeRouter02(PANCAKE_ROUTER).WETH();
        return path;
    }

    function mintAndTransfer_721(string memory cardtype, string memory code, address to, string memory tokenURI) public override payable whenNotPaused {
        card memory cardinfo = cards[cardtype];
        require(cardinfo.existed && cardinfo.active, "card type does not exist or not actived");
        uint card_bnb = cardinfo.price;
        uint token_bnb = 0;
        if (mode == 0) { //no list use rate
            token_bnb = cardinfo.points.div(cardinfo.rate);
        }
        else { //list on dask use router
            token_bnb = IPancakeRouter02(PANCAKE_ROUTER).getAmountsOut(cardinfo.points, getPathForCALtoETH())[1];
        }
        uint amount_bnb = card_bnb.add(token_bnb);
        require(msg.value >= amount_bnb, "send bnb is not enought");

        LibERC721LazyMint.Mint721Data memory data = _create_Mint721Data(cur_token_Id, tokenURI, address(this));
        PuggNFT(pugg_nft).mintAndTransfer(data, to);
        PuggNFT(pugg_nft).setInfo(cur_token_Id, cardtype);
        cur_token_Id = cur_token_Id.add(1);

        //card sales s% gose to project, token sales n% gose to project
        uint project_commission = card_bnb.mul(percent_s).div(10000);
        project_NFTBalance = project_NFTBalance.add(project_commission);
        project_TokenBalance = project_TokenBalance.add(token_bnb.mul(percent_n).div(10000));
        //card sales (100-s)% gose to node, y% token commission gose to node
        uint rank = IPuggPool(pugg_pool).getNodesRank(code);
        if (rank > 0 && rank < 11) { // 1 ~ 10
            nodeBalanceMap[code] = nodeBalanceMap[code].add(card_bnb.sub(project_commission));
            nodePointsMap[code] = nodePointsMap[code].add(cardinfo.points.mul(percent_y).div(10000));
        }
        //todo transfer to pool
        //y% token commission gose to pool
        IPuggPool(pugg_pool).recharge(cardinfo.points.mul(percent_x).div(10000));
        //token sales m% gose to buy back token
        uint[] memory amounts_back = convertETHToCAL(token_bnb.mul(percent_m).div(10000));
        buyback_points = buyback_points.add(amounts_back[1]);

        // refund leftover ETH to user
        if (msg.value > amount_bnb) {
            (bool success,) = msg.sender.call{ value: amount_bnb.sub(msg.value) }("");
            require(success, "refund failed");
        }
        emit MintAndTransfer_721(cardtype, code, data.tokenId, to, cardinfo.price, card_bnb, token_bnb);
    }

    function withdraw_p() public override onlyProject {
        uint amount = project_NFTBalance.add(project_TokenBalance);
        project_NFTBalance = 0;
        project_TokenBalance = 0;
        (bool success,) = msg.sender.call{ value: amount }("");
        require(success, "withdraw_p failed");
        emit Withdraw_p(_msgSender(), amount);
    }

    function _create_Mint721Data (uint _tokenId, string memory _tokenURI, address creator) internal pure returns(LibERC721LazyMint.Mint721Data memory) {
        LibPart.Part[] memory creators = new LibPart.Part[](1);
        creators[0] = LibPart.Part(payable(address(creator)), 10000);
        LibPart.Part[] memory royalties = new LibPart.Part[](0);
        bytes[] memory _signatures = new bytes[](1);
        _signatures[0] = "0x0000000000000000000000000000000000000000000000000000000000000000";
        return LibERC721LazyMint.Mint721Data(_tokenId, _tokenURI, creators, royalties, _signatures);
    }
}
