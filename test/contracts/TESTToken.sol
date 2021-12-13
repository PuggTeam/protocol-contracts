pragma solidity ^0.7.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TESTToken is ERC20 {
    constructor() ERC20("TEST Token", "TET") {
        _mint(msg.sender, 100000000000000000000000000);
    }
}
