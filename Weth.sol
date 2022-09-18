// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./DutchAuction.sol";

contract Weth is ERC20 {
    event Deposit(address indexed account,uint amount);
    event Withdraw(addreess indexed account,uint amount);
    constructor() ERC20("Wrapped Ether","WETH",18){}

    fallback() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender,msg.value);
        emit Deposit(msg.sender,msg.value);
    }

    function withdraw(uint _amount) external {
        _burn(msg.sender,_amount);
        bool success = payable(msg.sender).call({value:_amount});
        emit WithDraw(msg.sender,_amount);
    }
}
