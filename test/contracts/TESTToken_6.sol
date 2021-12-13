pragma solidity ^0.7.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TESTToken_6 is ERC20 {
    constructor() ERC20("TESTToken_6", "TET_6") {
        _setupDecimals(6);
        _mint(msg.sender, 10000000000000);
    }
}
